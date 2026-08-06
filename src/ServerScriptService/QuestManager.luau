-- QuestManager (server): hourly random quests with fixed coin rewards.
--
-- WHAT IT DOES
--   * Each player has a set of QuestConfig.QUEST_COUNT (3) quests and an hourly DEADLINE.
--   * When the deadline passes (or a brand-new player joins), a fresh random set is generated and the
--     deadline is pushed an hour out. The cycle is tracked by an absolute UNIX timestamp so it survives
--     rejoins: a player who returns mid-cycle keeps their in-progress quests until the hour is up.
--   * Gameplay events (round played, win, kill, survival, minutes, coins) advance matching quests.
--   * Completing a quest pays its fixed coin reward ONCE (via CoinManager.credit -- no Double-Coins
--     multiplier, works in private servers, and is NOT pack-gated since it's a free-to-play earning).
--   * Everything persists per-player via DataStore (quests, progress, claimed flags, deadline).
--
-- AUTHORITY: the server owns all quest state + progress. The client (QuestClient) only renders what the
-- server sends and toggles the slide UI; it can never advance a quest or claim a reward.
--
-- INTEGRATION: MatchManager calls the QuestManager.notify* hooks at the right gameplay moments
-- (round start per participant, per kill, and at resolution per player). See MatchManager bootstrap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))

local QuestManager = {}

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local _DataService, _CoinService
local function dataSvc()
	if not _DataService then
		local ok, s = pcall(function() return Knit.GetService("DataService") end)
		if ok then _DataService = s end
	end
	return _DataService
end
local function coinSvc()
	if not _CoinService then
		local ok, s = pcall(function() return Knit.GetService("CoinService") end)
		if ok then _CoinService = s end
	end
	return _CoinService
end

-- ===== remotes =====
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local function ensureRemote(name, className)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new(className); r.Name = name; r.Parent = Remotes end
	return r
end
-- server -> client: full quest state for this player { deadline = unix, quests = { {id, typeId, target,
--   progress, reward, done}, ... } }. Sent on load, on refresh, and after every progress change.
local QuestState = ensureRemote("QuestState", "RemoteEvent")
-- server -> client: fired when a quest just completed { typeId, reward } so the client can play a
-- celebration (sound / flash). Progress is also reflected in the next QuestState push.
local QuestCompleted = ensureRemote("QuestCompleted", "RemoteEvent")
-- client -> server: "send me my current quest state" (on join / UI (re)open). Server replies with QuestState.
local QuestRequest = ensureRemote("QuestRequest", "RemoteEvent")

-- in-memory: [userId] = { deadline = unix, quests = { {id, typeId, target, progress, done}, ... } }
local data = {}

-- ===== generation =====
local function weightedPickType(excludeIds)
	-- build the candidate list excluding already-picked ids (so a set has 3 DISTINCT quest types)
	local pool, totalW = {}, 0
	for _, t in ipairs(QuestConfig.TYPES) do
		if not excludeIds[t.id] then
			local w = t.weight or 1
			table.insert(pool, { t = t, w = w })
			totalW += w
		end
	end
	if #pool == 0 then return nil end
	local roll = math.random() * totalW
	local acc = 0
	for _, entry in ipairs(pool) do
		acc += entry.w
		if roll <= acc then return entry.t end
	end
	return pool[#pool].t
end

local nextQuestSerial = 0
local function makeQuest(questType)
	nextQuestSerial += 1
	local target = questType.targets[math.random(1, #questType.targets)]
	return {
		id = "q" .. nextQuestSerial,    -- per-slot unique id (used by the client to diff/animate)
		typeId = questType.id,
		target = target,
		progress = 0,
		done = false,
	}
end

local function generateSet()
	local quests = {}
	local used = {}
	for _ = 1, QuestConfig.QUEST_COUNT do
		local qt = weightedPickType(used)
		if not qt then break end
		used[qt.id] = true
		table.insert(quests, makeQuest(qt))
	end
	return quests
end

-- ===== client payload =====
-- Shape sent to the client: includes the resolved reward + description-ready fields. We send typeId +
-- target so the client computes text/icon from QuestConfig (single source of truth for wording).
local function buildPayload(userId)
	local record = data[userId]
	if not record then return nil end
	local quests = {}
	for _, q in ipairs(record.quests) do
		table.insert(quests, {
			id = q.id,
			typeId = q.typeId,
			target = q.target,
			progress = math.min(q.progress, q.target),
			reward = QuestConfig.rewardFor(q.typeId, q.target),
			done = q.done,
		})
	end
	return { deadline = record.deadline, quests = quests }
end

local function push(player)
	local payload = buildPayload(player.UserId)
	if payload then QuestState:FireClient(player, payload) end
end

-- ===== cycle / refresh =====
-- Ensure the player's set is current: if there's no set, or the hourly deadline has passed, roll a
-- fresh set and set the next deadline. Returns true if a refresh happened.
local function ensureCurrent(record)
	local now = os.time()
	if not record.quests or #record.quests == 0 or not record.deadline or now >= record.deadline then
		record.quests = generateSet()
		-- anchor the new deadline to "now + cycle". (We don't chain off the old deadline; a player who was
		-- away for 3 hours gets ONE fresh hour from when they return, which is the intuitive behavior.)
		record.deadline = now + QuestConfig.CYCLE_SECONDS
		return true
	end
	return false
end

-- ===== persistence =====
local function serialize(record)
	-- store only what we need to reconstruct; rewards/text are derived from QuestConfig at runtime.
	local quests = {}
	for _, q in ipairs(record.quests) do
		table.insert(quests, { id = q.id, typeId = q.typeId, target = q.target, progress = q.progress, done = q.done })
	end
	return { deadline = record.deadline, quests = quests }
end

local function deserialize(raw)
	if type(raw) ~= "table" or type(raw.quests) ~= "table" then return nil end
	local quests = {}
	for _, q in ipairs(raw.quests) do
		-- drop any quest whose type no longer exists (config changed since it was saved)
		if type(q) == "table" and q.typeId and QuestConfig.TYPES_BY_ID[q.typeId] then
			table.insert(quests, {
				id = q.id or ("q" .. tostring(math.random(1, 1e6))),
				typeId = q.typeId,
				target = q.target,
				progress = q.progress or 0,
				done = q.done and true or false,
			})
		end
	end
	return { deadline = raw.deadline, quests = quests }
end

local function flushQuests(player, record)
	local s = serialize(record)
	dataSvc():SetQuests(player, s.deadline, s.quests)
end

local function loadPlayer(player)
	local d = dataSvc()
	d:WaitForData(player)
	if not player.Parent then return end
	local deadline, quests = d:GetQuests(player)
	local record = deserialize({ deadline = deadline, quests = quests }) or { deadline = 0, quests = {} }
	record.loaded = d:IsReady(player)
	ensureCurrent(record)
	data[player.UserId] = record
	if record.loaded then flushQuests(player, record) end
	push(player)
end

local function savePlayer(player)
	local record = data[player.UserId]
	if not record then return end
	-- NEVER save a record whose load failed (loaded=false): writing it would overwrite the player's
	-- real quest progress with the fresh fallback set. Skip them; their real data stays intact.
	if record.loaded == false then
		warn("[QuestManager] skipping save for " .. player.Name .. " (load had failed; protecting real data)")
		return
	end
	flushQuests(player, record)
end
QuestManager.save = savePlayer

-- ===== progress engine =====
-- Advance every quest of the player that matches `event` (and `role`, when the type specifies one) by
-- `amount`. Completing a quest pays its reward exactly once. Pushes fresh state if anything changed.
local function advance(player, event, amount, role)
	if not player then return end
	local record = data[player.UserId]
	if not record then return end
	-- a queued event could arrive right as the hour rolls over; refresh first so we never credit an
	-- expired quest. (If this refreshes, the just-rolled set starts at 0 and this event won't apply to
	-- the old quests -- intended: the cycle ended.)
	if ensureCurrent(record) then push(player) flushQuests(player, record) return end

	amount = amount or 1
	if amount <= 0 then return end

	local changed = false
	for _, q in ipairs(record.quests) do
		if not q.done then
			local t = QuestConfig.TYPES_BY_ID[q.typeId]
			if t and t.event == event and (t.role == nil or t.role == role) then
				q.progress = math.min(q.target, q.progress + amount)
				changed = true
				if q.progress >= q.target then
					q.done = true
					local reward = QuestConfig.rewardFor(q.typeId, q.target)
					if reward > 0 then
						coinSvc():Credit(player, reward, "quest: " .. q.typeId)
					end
					QuestCompleted:FireClient(player, { typeId = q.typeId, reward = reward })
				end
			end
		end
	end
	if changed then push(player) flushQuests(player, record) end
end

-- ===== public gameplay hooks (called by MatchManager) =====
-- A player participated in a round with the given role ("Hider"/"Seeker"). Call at round start.
function QuestManager.notifyRoundPlayed(player, role)
	advance(player, "roundPlayed", 1)
	if role then advance(player, "roundPlayedAs", 1, role) end
end
-- A seeker found/eliminated a hider. Call per kill.
function QuestManager.notifyKill(player)
	advance(player, "kill", 1)
end
-- A round resolved for this player: role, whether they won, and whether they survived to the end.
-- Call once per player at resolution. Handles win / winAs / surviveRound / coinsEarned.
-- (The play-minutes quest is NOT handled here -- it accrues continuously for any player in the game,
-- lobby included, via the minute ticker in init().)
function QuestManager.notifyRoundResolved(player, role, won, survivedToEnd, coinsEarned)
	if won then
		advance(player, "win", 1)
		if role then advance(player, "winAs", 1, role) end
	end
	if role == "Hider" and survivedToEnd then
		advance(player, "surviveRound", 1)
	end
	if coinsEarned and coinsEarned > 0 then
		advance(player, "coinsEarned", coinsEarned)
	end
end

-- Kept for backwards-compatibility with any existing callers; play-minutes is now handled by the
-- continuous minute ticker in init() (counts lobby time too), so this is intentionally a no-op.
function QuestManager.notifyRoundTime(_player, _seconds)
end

-- ===== request handling =====
QuestRequest.OnServerEvent:Connect(function(player)
	local record = data[player.UserId]
	if not record then return end  -- not loaded yet; loadPlayer will push when ready
	if ensureCurrent(record) then
		flushQuests(player, record)
	end
	push(player)
end)

-- ===== lifecycle =====
function QuestManager.init()
	for _, plr in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, plr) end
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		savePlayer(plr)
		data[plr.UserId] = nil
	end)
	game:BindToClose(function()
		for _, plr in ipairs(Players:GetPlayers()) do savePlayer(plr) end
	end)
	-- periodic autosave (matches CoinManager/StatsManager cadence)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, plr in ipairs(Players:GetPlayers()) do savePlayer(plr) end
		end
	end)
	-- PLAY-MINUTES: accrue 1 minute toward the play-minutes quest for EVERY player currently in the
	-- game, every real minute -- regardless of round/lobby state. This is wall-clock "time in game", so
	-- sitting in the lobby counts just like being in a round. We tick every 5s and credit a whole
	-- minute once a player's accumulated in-game time passes 60s, carrying the remainder. Using a
	-- per-player accumulator (keyed off the data record) keeps it correct across the autosave/rejoin.
	task.spawn(function()
		local lastTick = os.clock()
		while true do
			task.wait(5)
			local nowC = os.clock()
			local elapsed = nowC - lastTick
			lastTick = nowC
			if elapsed > 0 then
				for _, plr in ipairs(Players:GetPlayers()) do
					local record = data[plr.UserId]
					if record then
						-- hourly rollover: refresh the set on time even for an idle lobby player, then push.
						if ensureCurrent(record) then
							push(plr)
							flushQuests(plr, record)
						else
							-- accrue in-game time toward the play-minutes quest (lobby time counts too)
							record._minuteCarry = (record._minuteCarry or 0) + elapsed
							local whole = math.floor(record._minuteCarry / 60)
							if whole > 0 then
								record._minuteCarry -= whole * 60
								advance(plr, "playMinutes", whole)
							end
						end
					end
				end
			end
		end
	end)
end

return QuestManager
