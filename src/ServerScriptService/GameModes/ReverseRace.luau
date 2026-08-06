local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReverseRaceConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ReverseRaceConfig"))
local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local GetEnv = require(ReplicatedStorage:WaitForChild("GetEnv"))
local MatchState = require(ServerScriptService:WaitForChild("Match"):WaitForChild("MatchState"))
local MatchRemotes = require(ServerScriptService:WaitForChild("Match"):WaitForChild("MatchRemotes"))
local HidePhase = require(ServerScriptService:WaitForChild("Match"):WaitForChild("HidePhase"))
local MatchmakingPublisher = require(ServerScriptService:WaitForChild("Match"):WaitForChild("MatchmakingPublisher"))
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))
local VotingManager = require(ServerScriptService:WaitForChild("VotingManager"))
local ReverseRacePreview = require(ServerScriptService:WaitForChild("Match"):WaitForChild("ReverseRacePreview"))
local RevealHighlights = require(ServerScriptService:WaitForChild("Match"):WaitForChild("RevealHighlights"))
local BackKnife = require(ServerScriptService:WaitForChild("BackKnife"))
local KnifeRemotes = ReplicatedStorage:WaitForChild("Knife"):WaitForChild("Remotes")
local GetPlayerFromPart = require(ReplicatedStorage:WaitForChild("Knife"):WaitForChild("Util"):WaitForChild("Hooks"):WaitForChild("GetPlayerFromPart"))
local KnifeSwingRemote = KnifeRemotes:FindFirstChild("KnifeSwing")
if not KnifeSwingRemote then
	KnifeSwingRemote = Instance.new("RemoteEvent")
	KnifeSwingRemote.Name = "KnifeSwing"
	KnifeSwingRemote.Parent = KnifeRemotes
end

local Knit = require(ReplicatedStorage.Packages.Knit)
local function knitSvc(name)
	local ok, s = pcall(function()
		return Knit.GetService(name)
	end)
	return ok and s or nil
end
-- Awards Reverse Race rewards: "pts" go to LevelService (XP), coins to CoinService.
local function awardReward(player, pts, coins, reason)
	if not player or not player.Parent then
		return
	end
	if pts and pts > 0 then
		local lvl = knitSvc("LevelService")
		if lvl then
			pcall(function()
				lvl:Award(player, pts, reason)
			end)
		end
	end
	if coins and coins > 0 then
		local coin = knitSvc("CoinService")
		if coin then
			pcall(function()
				coin:Award(player, coins, reason)
			end)
		end
	end
end

-- Speed-bonus XP for the finder, by how early in the hunt the target was found:
-- first 30% -> big, middle 40% -> medium, final 30% -> small.
local function huntSpeedBonusXP(elapsedSecs, huntSecs)
	local XP = ReverseRaceConfig.XP
	if huntSecs <= 0 then
		return XP.SPEED_MID
	end
	local frac = elapsedSecs / huntSecs
	if frac <= XP.SPEED_EARLY_FRAC then
		return XP.SPEED_EARLY
	elseif frac <= XP.SPEED_MID_FRAC then
		return XP.SPEED_MID
	end
	return XP.SPEED_LATE
end

local function snapshotLevel(player)
	local lvl = knitSvc("LevelService")
	if not lvl then
		return nil
	end
	local ok, snap = pcall(function()
		return lvl:Snapshot(player)
	end)
	return ok and snap or nil
end

local StateChanged = MatchRemotes.StateChanged
local ScreenFade = MatchRemotes.ScreenFade
local SpectateRemote = MatchRemotes.Spectate
local RoleMapRemote = MatchRemotes.RoleMap
local RoundSummary = MatchRemotes.RoundSummary

local InRoundRemote
local function setInRound(player, active)
	if not InRoundRemote or not InRoundRemote.Parent then
		local gr = ReplicatedStorage:FindFirstChild("GameRemotes")
		InRoundRemote = gr and gr:FindFirstChild("InRound")
	end
	if InRoundRemote then
		InRoundRemote:FireClient(player, active)
	end
end

local function getPlacement()
	return require(ServerScriptService:WaitForChild("MatchManager"):WaitForChild("MatchPlacement"))
end

local function getKnife()
	return require(ServerScriptService:WaitForChild("MatchManager"):WaitForChild("MatchKnife"))
end

local TEXT = ReverseRaceConfig.TEXT

local function getHUDRemote()
	local gr = ReplicatedStorage:WaitForChild("GameRemotes")
	local r = gr:FindFirstChild("ReverseRaceHUD")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "ReverseRaceHUD"
		r.Parent = gr
	end
	return r
end
local hudRemote = getHUDRemote()
local function sendHUD(player, data)
	if not hudRemote or not hudRemote.Parent then
		hudRemote = getHUDRemote()
	end
	hudRemote:FireClient(player, data)
end

-- Route Reverse Race's phase message + countdown through the SHARED TimerClient (same UI + style as
-- HideAndSeek) by firing StateChanged with rr=true. Per-player so the announce can be role-specific.
local function rrTimer(player, phase, timeLeft, announce, timerTitle)
	StateChanged:FireClient(player, { rr = true, state = phase, timeLeft = timeLeft, announce = announce, timerTitle = timerTitle })
end
local function rrClearTimer(player)
	StateChanged:FireClient(player, { rr = true, hide = true })
end
local function notifyOnboard(player, title, sub)
	local notif = knitSvc("NotificationService")
	if notif then
		pcall(function()
			notif:Preset(player, "INFO", title .. "  " .. sub, { Duration = 8 })
		end)
	end
end

local function getRollRemote()
	local gr = ReplicatedStorage:WaitForChild("GameRemotes")
	local r = gr:FindFirstChild("ReverseRaceRoll")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "ReverseRaceRoll"
		r.Parent = gr
	end
	return r
end
local rollRemote = getRollRemote()

local function getLeaderboardRemote()
	local gr = ReplicatedStorage:WaitForChild("GameRemotes")
	local r = gr:FindFirstChild("ReverseRaceLeaderboard")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "ReverseRaceLeaderboard"
		r.Parent = gr
	end
	return r
end
local leaderboardRemote = getLeaderboardRemote()

local function getReverseRaceJoinRemotes()
	local gr = ReplicatedStorage:WaitForChild("GameRemotes")
	local offer = gr:FindFirstChild("OfferJoinReverseRace")
	if not offer then
		offer = Instance.new("RemoteEvent")
		offer.Name = "OfferJoinReverseRace"
		offer.Parent = gr
	end
	local resp = gr:FindFirstChild("JoinReverseRaceResponse")
	if not resp then
		resp = Instance.new("RemoteEvent")
		resp.Name = "JoinReverseRaceResponse"
		resp.Parent = gr
	end
	return offer, resp
end
local offerJoinRemote, joinResponseRemote = getReverseRaceJoinRemotes()

local function getReverseRaceViewportRemote()
	local gr = ReplicatedStorage:WaitForChild("GameRemotes")
	local r = gr:FindFirstChild("ReverseRaceViewport")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "ReverseRaceViewport"
		r.Parent = gr
	end
	return r
end
local viewportRemote = getReverseRaceViewportRemote()

local function isAfk(plr)
	local svc = knitSvc("AfkService")
	return svc and svc:IsAfk(plr) or false
end

-- First-time-ever onboarding, persisted per player (a tutorial, not per-session).
local HIDER_FLAG = "ReverseRaceHiderOnboarded"
local HUNTER_FLAG = "ReverseRaceHunterOnboarded"
local function getDataService()
	return require(ServerScriptService:WaitForChild("Services"):WaitForChild("DataService"))
end
local function hasOnboarded(player, flag)
	local DataService = getDataService()
	local data = DataService:WaitForData(player)
	return data ~= nil and DataService:GetFlag(player, flag) == true
end
local function markOnboarded(player, flag)
	local DataService = getDataService()
	if DataService:WaitForData(player) then
		DataService:SetFlag(player, flag, true)
		pcall(function()
			DataService:Save(player)
		end)
	end
end

-- Resets a player to a fresh default body, waiting for the FULL avatar to load before
-- returning -- otherwise the studs-conversion (convert=true placement) only catches the
-- parts that have streamed in so far, leaving them only partly studded/bricky.
local function loadDefaultCharacter(player)
	player:LoadCharacter()
	local loaded = false
	local conn = player.CharacterAppearanceLoaded:Connect(function()
		loaded = true
	end)
	local deadline = os.clock() + 4
	while not loaded and os.clock() < deadline and player.Parent do
		task.wait(0.1)
	end
	conn:Disconnect()
	task.wait(0.1)
end

-- Fully locks the current target with no hider editing UI. They can still be
-- knifed (found), but cannot move, repaint, change pose, or unlock themselves.
local function freezeTarget(player)
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.Anchored = true
	end
	setInRound(player, false)
	print("[ReverseRace][freecam] target " .. player.Name .. " frozen as an immutable disguise")
end

-- Makes an out-of-lives hunter's body invisible + non-collidable while they spectate, so no one
-- sees a "dead" hunter. (Moving it server-side doesn't stick -- the body is client-owned and the
-- client replicates its position back; transparency is a property and replicates regardless.) It's
-- replaced by the next turn's reset / the round-end respawn, so nothing needs to be restored.
local function hideCharacter(player)
	local char = player.Character
	if not char then
		return
	end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

-- Hunter lives shown as a billboard above the head (server-side so everyone sees it). Built from
-- ReverseRaceConfig.LIVES_BILLBOARD, or cloned from ReplicatedStorage.Assets.UI.ReverseRaceLives if
-- that template exists (for full visual customization). Hearts must be named Heart1..HeartN.
local function getLivesTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local ui = assets and assets:FindFirstChild("UI")
	local t = ui and ui:FindFirstChild("ReverseRaceLives")
	return (t and t:IsA("BillboardGui")) and t or nil
end
local function livesHead(player)
	local char = player.Character
	return char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
end
local function buildLivesBillboard(maxLives)
	local cfg = ReverseRaceConfig.LIVES_BILLBOARD
	local bb = Instance.new("BillboardGui")
	bb.Size = cfg.Size
	bb.StudsOffset = cfg.StudsOffset
	bb.MaxDistance = cfg.MaxDistance
	bb.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(cfg.Padding, 0)
	layout.Parent = bb
	for i = 1, maxLives do
		local h = Instance.new("ImageLabel")
		h.Name = "Heart" .. i
		h.Size = UDim2.fromScale(cfg.HeartScale, 1)
		h.SizeConstraint = Enum.SizeConstraint.RelativeYY
		h.BackgroundTransparency = 1
		h.LayoutOrder = i
		h.Image = cfg.HeartIcon
		h.Parent = bb
	end
	return bb
end
local function setLivesBillboard(player, lives, maxLives)
	local head = livesHead(player)
	if not head then
		return
	end
	local cfg = ReverseRaceConfig.LIVES_BILLBOARD
	local bb = head:FindFirstChild("ReverseRaceLives")
	if not bb then
		local template = getLivesTemplate()
		bb = (template and template:Clone()) or buildLivesBillboard(maxLives)
		bb.Name = "ReverseRaceLives"
		bb.Parent = head
	end
	for i = 1, maxLives do
		local h = bb:FindFirstChild("Heart" .. i, true)
		if h and h:IsA("ImageLabel") then
			h.Image = (i <= lives) and cfg.HeartIcon or cfg.BrokenIcon
		end
	end
end
local function removeLivesBillboard(player)
	local head = livesHead(player)
	local bb = head and head:FindFirstChild("ReverseRaceLives")
	if bb then
		bb:Destroy()
	end
end

local function broadcastState(state, timeLeft, note)
	MatchState.current = state
	MatchmakingPublisher.publish(state, timeLeft)
	-- StateChanged intentionally NOT fired for Reverse Race: the ReverseRaceHUD drives the
	-- client banners + phase timer (counted locally, consistently), so TimerClient doesn't
	-- show a stale/duplicate "Round left" that only some clients receive.
end

-- Interruptible phase wait that also honors the shared SkipPhase command (MatchState.skipPhase), so
-- "SkipPhase" ends the current Reverse Race phase early exactly like it does in the regular mode. The
-- optional stillValid() lets a phase bail on its own condition too (e.g. the target leaving). Returns
-- true only if it was ended by the SkipPhase command.
local function phaseWait(seconds, stillValid)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if MatchState.preemptRound then
			return true
		end
		if MatchState.skipPhase then
			MatchState.skipPhase = false
			return true
		end
		if stillValid and not stillValid() then
			return false
		end
		task.wait(0.2)
	end
	return false
end

local function clearDiedConns()
	for _, c in ipairs(MatchState.diedConns) do
		if c then
			c:Disconnect()
		end
	end
	table.clear(MatchState.diedConns)
end

local function resetRoundState()
	table.clear(MatchState.roles)
	table.clear(MatchState.found)
	table.clear(MatchState.hiders)
	table.clear(MatchState.seekers)
	table.clear(MatchState.seekerOut)
	table.clear(MatchState.foundTime)
	table.clear(MatchState.foundOrder)
	table.clear(MatchState.hiderPlacedAt)
	clearDiedConns()
end

local ReverseRace = {
	id = "reverserace",
}

local function activePlayers()
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		table.insert(out, plr)
	end
	return out
end

local function selectTargets(players)
	local pool = table.clone(players)
	for i = #pool, 2, -1 do
		local j = math.random(i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local limit = math.min(#pool, ReverseRaceConfig.MAX_TARGETS)
	local targets = {}
	for i = 1, limit do
		targets[i] = pool[i]
	end
	return targets
end

function ReverseRace.init(ctx)
end

function ReverseRace.run(ctx)
	if ReverseRace._roundConns then
		for _, c in ipairs(ReverseRace._roundConns) do
			pcall(function()
				c:Disconnect()
			end)
		end
	end
	ReverseRace._roundConns = {}
	-- Clear any stale SkipPhase request (e.g. one left set by a prior regular-mode round) so it
	-- doesn't immediately skip this round's first phase.
	MatchState.skipPhase = false
	local GameModeService = Knit.GetService("GameModeService")
	MatchState.preemptRound = GameModeService:GetRoundPreemptTarget() == "hideandseek"
	table.insert(
		ReverseRace._roundConns,
		GameModeService.RoundPreemptRequestedSignal:Connect(function(targetModeId, reason)
			if targetModeId == "hideandseek" then
				print(`[ReverseRace] round preempt requested; reason={reason or "unspecified"}`)
				MatchState.preemptRound = true
				MatchState.skipPhase = true
			end
		end)
	)
	-- Wait for the roster to settle before locking it in: in Studio the round can start the
	-- instant the server is up, before all test clients have connected/loaded.
	do
		local startTime = os.clock()
		local stableSince = os.clock()
		local lastCount = #Players:GetPlayers()
		while
			(os.clock() - stableSince) < 2
			and (os.clock() - startTime) < 10
			and not MatchState.preemptRound
		do
			task.wait(0.3)
			local c = #Players:GetPlayers()
			if c ~= lastCount then
				lastCount = c
				stableSince = os.clock()
			end
		end
	end
	if MatchState.preemptRound then
		print("[ReverseRace] preempted during roster setup")
		return
	end

	local players = activePlayers()
	-- Only bypass the player minimum when the round was explicitly ForcePlay'd (solo testing).
	-- Otherwise rounds only start with a natural roster -- they don't auto-start under-filled.
	local forced = false
	pcall(function()
		forced = require(ServerScriptService:WaitForChild("Services"):WaitForChild("GameModeService")).forcedActive == true
	end)
	local minPlayers = forced and 1 or ReverseRaceConfig.MIN_PLAYERS
	if #players < minPlayers then
		print("[ReverseRace] not enough players (" .. #players .. "/" .. minPlayers .. "); skipping round")
		task.wait(3)
		return
	end

	print("[ReverseRace] === ROUND START ===")

	local rosterSet = {}
	for _, plr in ipairs(players) do
		rosterSet[plr] = true
	end
	local lateHunters = {}
	local lateSet = {}
	local offeredSet = {}
	local roundActive = true
	local liveHunt = nil
	local myStats = {}
	local levelSnapshot = {}
	-- Team-find bonus points, accrued per player during the round and paid out as coins (10 per point)
	-- at the END of the round (see the payout below), not as immediate mid-round coin awards.
	local teamFindPoints = {}
	local currentViewportModel = nil
	local currentViewportTitle = nil

	local function clearViewportTarget()
		viewportRemote:FireAllClients({ show = false })
		if currentViewportModel then
			currentViewportModel:Destroy()
		end
		currentViewportModel = nil
		currentViewportTitle = nil
	end

	local function getViewportModelsFolder()
		local folder = ReplicatedStorage:FindFirstChild("ReverseRaceViewportModels")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "ReverseRaceViewportModels"
			folder.Parent = ReplicatedStorage
		end
		return folder
	end

	local function makeViewportTargetModel(target)
		clearViewportTarget()
		local character = target and target.Character
		if not character then
			return nil
		end

		local wasArchivable = character.Archivable
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = wasArchivable
		if not clone then
			return nil
		end

		clone.Name = "CurrentTarget"
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Highlight") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end

		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			end)
		end

		clone.Parent = getViewportModelsFolder()
		currentViewportModel = clone
		currentViewportTitle = target.DisplayName
		return clone
	end

	local function showViewportTo(plr)
		if currentViewportModel and currentViewportModel.Parent then
			viewportRemote:FireClient(plr, {
				show = true,
				model = currentViewportModel,
				title = currentViewportTitle,
				duration = 12,
			})
		end
	end

	local function ensureStats(plr)
		local e = myStats[plr.UserId]
		if not e then
			e = { fastestFind = nil, longestSurvival = nil, kills = 0, coins = 0 }
			myStats[plr.UserId] = e
		end
		return e
	end

	local function buildHunters(currentTarget)
		local out = {}
		local seen = {}
		for _, plr in ipairs(players) do
			if plr ~= currentTarget and plr.Parent and not seen[plr] then
				seen[plr] = true
				table.insert(out, plr)
			end
		end
		for _, plr in ipairs(lateHunters) do
			if plr ~= currentTarget and plr.Parent and not seen[plr] then
				seen[plr] = true
				table.insert(out, plr)
			end
		end
		return out
	end

	local function registerLateHunter(plr)
		if lateSet[plr] then
			return false
		end
		lateSet[plr] = true
		table.insert(lateHunters, plr)
		plr:SetAttribute("InMatch", true)
		ensureStats(plr)
		levelSnapshot[plr.UserId] = levelSnapshot[plr.UserId] or snapshotLevel(plr)
		return true
	end

	local function offerLateJoin(plr)
		if not roundActive then
			return
		end
		if not plr or not plr.Parent then
			return
		end
		if rosterSet[plr] or lateSet[plr] or offeredSet[plr] then
			return
		end
		if isAfk(plr) then
			return
		end
		offeredSet[plr] = true
		offerJoinRemote:FireClient(plr)
	end

	local function tryOfferSoon(plr)
		task.spawn(function()
			local deadline = os.clock() + 10
			while not plr.Character and os.clock() < deadline and plr.Parent do
				task.wait(0.2)
			end
			offerLateJoin(plr)
		end)
	end

	local addedConn = Players.PlayerAdded:Connect(tryOfferSoon)
	local joinConn = joinResponseRemote.OnServerEvent:Connect(function(plr, accepted)
		if not roundActive then
			return
		end
		if accepted ~= true then
			return
		end
		if rosterSet[plr] or lateSet[plr] then
			return
		end
		if not offeredSet[plr] then
			return
		end
		if not registerLateHunter(plr) then
			return
		end
		if liveHunt then
			-- arm() shows the target viewport itself (mid-hunt joiners skip the preview room),
			-- so no separate showViewportTo call is needed here.
			liveHunt.arm(plr)
		end
	end)
	table.insert(ReverseRace._roundConns, addedConn)
	table.insert(ReverseRace._roundConns, joinConn)
	for _, plr in ipairs(Players:GetPlayers()) do
		if not rosterSet[plr] then
			tryOfferSoon(plr)
		end
	end

	-- Continuously tell lobby players (non-participants) that a round is ongoing, so their top-bar shows
	-- "Round active" instead of a stale intermission banner. Runs for the whole round; stops at its end.
	task.spawn(function()
		while roundActive do
			for _, plr in ipairs(Players:GetPlayers()) do
				if not (rosterSet[plr] or lateSet[plr]) then
					StateChanged:FireClient(plr, { spectateActive = true })
				end
			end
			task.wait(2)
		end
	end)

	-- ===== HIDE PHASE =====
	local Placement = getPlacement()
	-- Map selection: a ForcePlay-forced map wins, otherwise the current map vote (players can swap
	-- their vote right up until this resolve), otherwise a random map.
	local chosenMap
	local usingForced = false
	local forced = MapManager.peekForcedMap()
	if forced then
		chosenMap = forced
		usingForced = true
	end
	if not chosenMap and VotingManager.canVote() and VotingManager.isOpen() then
		chosenMap = VotingManager.resolveVote()
	end
	if not chosenMap then
		chosenMap = MapManager.chooseRandomMap()
	end
	MapManager.loadMap(chosenMap)
	if usingForced and forced and MapManager.getActiveMapName() == forced.Name then
		MapManager.consumeForcedMap()
	end

	resetRoundState()
	local Knife = getKnife()
	for _, plr in ipairs(players) do
		MatchState.roles[plr] = "Hider"
		table.insert(MatchState.hiders, plr)
		plr:SetAttribute("InMatch", true)
		-- InRound/RoleAnnounce are also used to hide shared hider controls.
		-- Preserve the painted, locked, posed disguise across those temporary
		-- role changes until leaveDecoy/loadDefaultCharacter complete the handoff.
		plr:SetAttribute("ReverseRacePreserveDisguise", true)
		pcall(function()
			Knife.clearKnife(plr)
		end)
		BackKnife.setSuppressed(plr, true)
		print("[ReverseRace] hider setup: " .. plr.Name)
	end

	-- Round scoring + live leaderboard (defined here so it can show from the moment the round begins,
	-- then update after every target's turn).
	local results = {
		fastestFind = nil,
		longestSurvival = nil,
		points = {},
	}
	for _, plr in ipairs(players) do
		results.points[plr.UserId] = { userId = plr.UserId, name = plr.DisplayName, points = 0 }
		ensureStats(plr)
		levelSnapshot[plr.UserId] = snapshotLevel(plr)
	end
	local function addPoints(plr, pts)
		if not plr or not pts or pts <= 0 then
			return
		end
		local e = results.points[plr.UserId]
		if not e then
			e = { userId = plr.UserId, name = plr.DisplayName, points = 0 }
			results.points[plr.UserId] = e
		end
		e.points += pts
	end
	-- Fire a remote to the round's participants only (roster + late-join hunters) -- never lobby players,
	-- who shouldn't see match-only UI like the target roll or the leaderboard.
	local function fireParticipants(remote, payload)
		for _, plr in ipairs(players) do
			if plr.Parent then
				remote:FireClient(plr, payload)
			end
		end
		for _, plr in ipairs(lateHunters) do
			if plr.Parent then
				remote:FireClient(plr, payload)
			end
		end
	end
	local function broadcastLeaderboard()
		local board = {}
		for _, e in pairs(results.points) do
			table.insert(board, e)
		end
		table.sort(board, function(a, b)
			return a.points > b.points
		end)
		fireParticipants(leaderboardRemote, { rows = board })
	end

	-- ===== XP (per-round, capped; VIP earns a higher cap) =====
	-- Every XP award routes through awardXP: it clamps to the player's remaining cap, records the
	-- amount for the leaderboard/summary, and hands the clamped amount to LevelService (which applies
	-- its own private-server + friend-bonus rules). Coins are awarded separately and are NOT capped.
	local xpEarned = {}
	local xpCapByUser = {}
	local function xpCapFor(plr)
		local cap = xpCapByUser[plr.UserId]
		if cap == nil then
			cap = (plr:GetAttribute("IsVIP") == true) and ReverseRaceConfig.XP.CAP_VIP or ReverseRaceConfig.XP.CAP_NORMAL
			xpCapByUser[plr.UserId] = cap
		end
		return cap
	end
	local function awardXP(plr, amount, reason)
		if not plr or not plr.Parent or not amount or amount <= 0 then
			return 0
		end
		local uid = plr.UserId
		local cap = xpCapFor(plr)
		local already = xpEarned[uid] or 0
		local allowed = math.min(amount, math.max(0, cap - already))
		if allowed <= 0 then
			return 0
		end
		xpEarned[uid] = already + allowed
		addPoints(plr, allowed)
		local lvl = knitSvc("LevelService")
		if lvl then
			pcall(function()
				lvl:Award(plr, allowed, reason)
			end)
		end
		return allowed
	end

	broadcastState("HIDE", ReverseRaceConfig.HIDE_SECONDS, "Blend in and hide!")
	broadcastLeaderboard() -- show the leaderboard (all 0) right as the round begins

	-- Reverse Race starts with everyone hidden. Clear any stale seeker role map from a
	-- previous classic/turn state so clients remove seeker highlights during the hide phase.
	RoleMapRemote:FireAllClients({})
	RevealHighlights.clearAll()

	-- Make sure every avatar is fully loaded before the studs-conversion runs, or a player
	-- can come out only partly studded/bricky (the conversion catches only the loaded parts).
	for _, plr in ipairs(players) do
		local t0 = os.clock()
		while not plr:HasAppearanceLoaded() and os.clock() - t0 < 4 and plr.Parent do
			task.wait(0.1)
		end
	end

	HidePhase.placeHiders(MatchState.hiders, {
		placement = Placement,
		roleAnnounce = MatchRemotes.RoleAnnounce,
		screenFade = MatchRemotes.ScreenFade,
		mapTarget = Placement.mapTarget,
		walkspeed = MatchConfig.CONFIG.HIDER_SPEED,
		gracePeriod = 2,
		isActivePhase = function()
			return MatchState.current == "HIDE"
		end,
		onDeath = nil,
	})

	local function reverseRaceLobbyDistance(pos)
		local best = math.huge
		local fixtures = Workspace:FindFirstChild("LobbyFixtures")
		local searchRoot = fixtures or Workspace
		for _, d in ipairs(searchRoot:GetDescendants()) do
			if (d:IsA("SpawnLocation") or d.Name == "LobbySpawn") and d:IsA("BasePart") then
				local dx, dz = pos.X - d.Position.X, pos.Z - d.Position.Z
				best = math.min(best, math.sqrt(dx * dx + dz * dz))
			end
		end
		return best
	end

	local function reissueReverseRaceHiderPlacement(hider, tag)
		if not hider or not hider.Parent or MatchState.current ~= "HIDE" or MatchState.roles[hider] ~= "Hider" or MatchState.found[hider] then
			return
		end
		warn("[ReverseRace] HIDE placement sweep (" .. tostring(tag) .. "): " .. hider.Name .. " not confirmed on map; forcing re-placement")
		Placement.setDesiredPlacement(hider, Placement.mapTarget(math.random(1, math.max(1, #MatchState.hiders))), {
			convert = true,
			valid = function(p)
				return MatchState.current == "HIDE" and MatchState.roles[p] == "Hider" and not MatchState.found[p]
			end,
			onPlaced = function(p)
				local c = p.Character
				local hum = c and c:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = MatchConfig.CONFIG.HIDER_SPEED
				end
				MatchState.hiderPlacedAt[p] = os.clock()
			end,
		})
		MatchRemotes.RoleAnnounce:FireClient(hider, "Hider")
	end

	local function sweepReverseRaceHiderPlacements(tag, forceIfStillInLobby)
		for _, h in ipairs(MatchState.hiders) do
			if h.Parent and MatchState.roles[h] == "Hider" and not MatchState.found[h] then
				local intent = Placement.desired[h]
				local char = h.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local inLobby = root and reverseRaceLobbyDistance(root.Position) < 60
				local needsPlacement = intent == nil or (intent and not intent.placed and not intent.running) or (forceIfStillInLobby and inLobby)
				if needsPlacement then
					reissueReverseRaceHiderPlacement(h, tag)
				end
			end
		end
	end

	-- Reverse Race starts everyone as hiders too, so use the same kind of stuck-hider recovery as
	-- regular mode: if conversion happened but map placement did not confirm, re-roll a fresh map spawn.
	task.spawn(function()
		local checks = {
			{ delay = 2, forceLobby = false },
			{ delay = 4, forceLobby = false },
			{ delay = 8, forceLobby = true },
			{ delay = 12, forceLobby = true },
		}
		local elapsed = 0
		for _, check in ipairs(checks) do
			task.wait(math.max(0, check.delay - elapsed))
			elapsed = check.delay
			if MatchState.current ~= "HIDE" then
				break
			end
			sweepReverseRaceHiderPlacements("initial @" .. elapsed .. "s", check.forceLobby)
		end
		while MatchState.current == "HIDE" do
			task.wait(10)
			if MatchState.current == "HIDE" then
				sweepReverseRaceHiderPlacements("periodic", true)
			end
		end
	end)

	-- Reverse Race shows reveal highlights ONLY during the per-target reveal stage. Clear any stray
	-- "RoundEndReveal" highlight left on a player (e.g. one that didn't get cleared on a prior round on a
	-- laggy live server) so no hider is highlighted during the hide phase.
	RevealHighlights.clearAll()

	-- Enable the hider HUD (paint/pose/lock needs InRound + RoleAnnounce), clear the
	-- placement fade, and KEEP re-asserting it -- async placement respawns can clear the
	-- client's in-round state right after we set it.
	local function assertHider(h)
		setInRound(h, true)
		MatchRemotes.RoleAnnounce:FireClient(h, "Hider")
	end
	local hideConns = {}
	for _, h in ipairs(MatchState.hiders) do
		assertHider(h)
		rrTimer(h, "HIDE", ReverseRaceConfig.HIDE_SECONDS, TEXT.HIDE_TITLE, "Hide")
		if not hasOnboarded(h, HIDER_FLAG) then
			markOnboarded(h, HIDER_FLAG)
			notifyOnboard(h, TEXT.HIDER_ONBOARD_TITLE, TEXT.HIDER_ONBOARD_SUB)
		end
		local hp = h
		table.insert(
			hideConns,
			h.CharacterAdded:Connect(function()
				task.wait(0.25)
				if MatchState.current == "HIDE" then
					assertHider(hp)
				end
			end)
		)
	end

	local placementRevealDeadline = os.clock() + 8
	local lastPlacementSweep = 0
	while MatchState.current == "HIDE" and os.clock() < placementRevealDeadline do
		local allPlaced = true
		for _, h in ipairs(MatchState.hiders) do
			if h.Parent and MatchState.roles[h] == "Hider" and not MatchState.found[h] then
				local intent = Placement.desired[h]
				if not (intent and intent.placed) then
					allPlaced = false
					break
				end
			end
		end
		if allPlaced then
			break
		end
		if os.clock() - lastPlacementSweep >= 2 then
			lastPlacementSweep = os.clock()
			sweepReverseRaceHiderPlacements("pre-fade", os.clock() > placementRevealDeadline - 2)
		end
		task.wait(0.2)
	end

	task.wait(0.35)
	for _, h in ipairs(MatchState.hiders) do
		ScreenFade:FireClient(h, "out", { fadeTime = 0.3 })
	end
	task.spawn(function()
		for _ = 1, 6 do
			task.wait(0.5)
			if MatchState.current ~= "HIDE" then
				break
			end
			for _, h in ipairs(MatchState.hiders) do
				if h.Parent then
					assertHider(h)
				end
			end
		end
	end)

	-- The round has begun: roll the vote boards over to the next round's options (players keep voting).
	if VotingManager.canVote() then
		VotingManager.openNextVote()
	end

	-- Hide countdown: play the clock tick for every hider at 3 / 2 / 1 seconds remaining.
	task.spawn(function()
		task.wait(math.max(0, ReverseRaceConfig.HIDE_SECONDS - 3))
		for _ = 1, 3 do
			if MatchState.current ~= "HIDE" then
				return
			end
			for _, h in ipairs(MatchState.hiders) do
				if h.Parent then
					sendHUD(h, { sound = "HideCountdownTick" })
				end
			end
			task.wait(1)
		end
	end)

	phaseWait(ReverseRaceConfig.HIDE_SECONDS)

	-- Hide phase over: stop re-asserting and turn the paint HUD off for the hunt portion.
	for _, c in ipairs(hideConns) do
		c:Disconnect()
	end
	for _, plr in ipairs(players) do
		setInRound(plr, false)
	end

	-- ===== TARGET SELECTION =====
	local targets = selectTargets(players)
	print("[ReverseRace] selected " .. #targets .. " target(s)")

	-- Hunters leave their painted/posed disguise behind as a static decoy and reset to a
	-- default body to hunt. The map fills with look-alike statues; only the current
	-- target is a real player.
	local old = Workspace:FindFirstChild("ReverseRaceDecoys")
	if old then
		old:Destroy()
	end
	local decoysFolder = Instance.new("Folder")
	decoysFolder.Name = "ReverseRaceDecoys"
	decoysFolder.Parent = Workspace
	-- A disguise is transferable state, not just a character clone. Keeping the model,
	-- pose, lock/frozen state, controller, role, and UI contract together lets a later
	-- player take control without losing the hider state attached to that character.
	local poseService = knitSvc("PoseService")
	local paintService = knitSvc("PaintService")
	local disguiseStateByUser = {}

	local function poseNameFor(player, character)
		local poseName
		if poseService and poseService.GetPoseName then
			pcall(function()
				poseName = poseService:GetPoseName(player)
			end)
		end
		return poseName or character:GetAttribute("ReverseRacePose")
	end

	local function lockedFor(player, character)
		local isLocked = character:GetAttribute("ReverseRaceLocked") == true
		if paintService and paintService.IsLocked then
			pcall(function()
				isLocked = paintService:IsLocked(player) or isLocked
			end)
		end
		return isLocked
	end

	local function tagDisguiseCharacter(state, character)
		character:SetAttribute("ReverseRaceDisguiseOwnerUserId", state.ownerUserId)
		character:SetAttribute("ReverseRacePose", state.pose.name)
		character:SetAttribute("ReverseRaceLocked", state.lock.enabled)
	end

	local function captureActiveDisguise(player)
		local character = player.Character
		if not character then
			return nil
		end
		local state = disguiseStateByUser[player.UserId] or {
			ownerUserId = player.UserId,
			owner = player,
			pose = {},
			lock = {},
			ui = {
				role = "Hider",
				inRound = false,
				taunt = false,
				paint = false,
				freeze = false,
				pose = false,
			},
		}
		state.character = character
		state.controller = player
		state.role = "Hider"
		state.pose.name = poseNameFor(player, character)
		state.lock.enabled = lockedFor(player, character)
		state.frozen = state.lock.enabled
		tagDisguiseCharacter(state, character)
		disguiseStateByUser[player.UserId] = state
		return state
	end

	local function parkDisguise(player)
		local state = disguiseStateByUser[player.UserId]
		if state and state.character ~= player.Character and state.character.Parent == decoysFolder then
			return state
		end

		state = captureActiveDisguise(player)
		local character = state and state.character
		if not character then
			return state
		end
		local wasArchivable = character.Archivable
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = wasArchivable
		if not clone then
			return state
		end

		clone.Name = "Decoy_" .. player.Name
		tagDisguiseCharacter(state, clone)
		local animate = clone:FindFirstChild("Animate")
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			elseif descendant:IsA("Highlight") then
				-- never copy a reveal highlight onto a parked disguise/decoy
				descendant:Destroy()
			elseif descendant:IsA("BaseScript") then
				if descendant == animate then
					descendant.Disabled = true
				else
					descendant:Destroy()
				end
			end
		end
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
		clone.Parent = decoysFolder
		state.character = clone
		state.controller = nil
		return state
	end

	local function activateDisguise(state, controller)
		if not state then
			state = captureActiveDisguise(controller)
		end
		local character = state and state.character
		if not character then
			return nil
		end
		state.lock.enabled = true
		state.frozen = true
		tagDisguiseCharacter(state, character)

		local oldCharacter = controller.Character
		if not character:FindFirstChild("Animate") and oldCharacter then
			local oldAnimate = oldCharacter:FindFirstChild("Animate")
			if oldAnimate and oldAnimate:IsA("LocalScript") then
				local restoredAnimate = oldAnimate:Clone()
				restoredAnimate.Disabled = true
				restoredAnimate.Parent = character
			end
		end

		if oldCharacter ~= character then
			character.Name = controller.Name
			character.Parent = Workspace
			controller.Character = character
			if oldCharacter then
				task.defer(function()
					oldCharacter:Destroy()
				end)
			end
			task.wait(0.1)
		end

		state.controller = controller
		state.role = "Hider"
		MatchState.roles[controller] = state.ui.role
		controller:SetAttribute("InMatch", true)
		freezeTarget(controller)
		return state
	end

	-- ===== PER-TARGET HUNT LOOP =====
	for i, target in ipairs(targets) do
		if MatchState.preemptRound then
			break
		end
		if not target.Parent then
			continue
		end
		print("[ReverseRace] --- Target " .. i .. "/" .. #targets .. ": " .. target.Name .. " ---")

		-- ROLL: reveal the next target with a crate-style roll of player headshots + names.
		do
			local rollList = {}
			for _, plr in ipairs(players) do
				if plr.Parent then
					table.insert(rollList, { userId = plr.UserId, name = plr.DisplayName })
				end
			end
			-- Only participants see the target roll -- lobby players shouldn't get the roll GUI.
			fireParticipants(rollRemote, {
				players = rollList,
				winnerUserId = target.UserId,
				winnerName = target.DisplayName,
				duration = ReverseRaceConfig.ROLL_SECONDS,
			})
			phaseWait(ReverseRaceConfig.ROLL_SECONDS + 1.8)
		end
		if MatchState.preemptRound then
			break
		end

		-- If the target left during their reveal, skip their turn cleanly and move on (no hunters have
		-- been armed yet). The for-loop ends the round if this was the last target.
		if not target.Parent then
			print(("[ReverseRace] target %d left before their turn -> skipping"):format(i))
			continue
		end

		local hunters = buildHunters(target)

		-- Lock the target in their disguise, then reset everyone else into armed default
		-- hunters (leaving their disguise behind as a decoy) BEFORE the preview, behind a
		-- fade so the LoadCharacter lobby respawn isn't visible. They enter the preview room
		-- already reset and holding a knife.
		-- Knives are only ever on active hunters: clear any leftover knife (and re-suppress the
		-- back-knife) BEFORE swapping in the disguise, while they're still in the armed hunter body.
		pcall(function()
			Knife.clearKnife(target)
		end)
		pcall(function()
			BackKnife.setSuppressed(target, true)
		end)

		-- Rebind the complete disguise record as the immutable target snapshot. The
		-- controller gets Free Cam separately, but no paint/pose/lock/taunt controls.
		local targetDisguise = disguiseStateByUser[target.UserId]
		targetDisguise = activateDisguise(targetDisguise, target)
		makeViewportTargetModel(target)
		SpectateRemote:FireClient(target, false)
		target:SetAttribute("ReverseRaceFreeCam", true)
		pcall(function()
			Knife.clearKnife(target)
		end)

		-- fade every hunter to black FIRST so the reset respawn is fully hidden, THEN reset
		-- them. LoadCharacter restores their real avatar (no studs-conversion -- hunters look
		-- like themselves, not blocky).
		for _, h in ipairs(hunters) do
			ScreenFade:FireClient(h, "in", { fadeTime = 0.2 })
			parkDisguise(h)
			MatchState.roles[h] = "Seeker"
			MatchState.seekerOut[h] = nil
			setInRound(h, true)
			MatchRemotes.RoleAnnounce:FireClient(h, "Seeker")
		end
		task.wait(0.35)
		local resetDone = 0
		for _, h in ipairs(hunters) do
			local hunter = h
			task.spawn(function()
				loadDefaultCharacter(hunter)
				SpectateRemote:FireClient(hunter, false)
				pcall(function()
					Knife.giveKnife(hunter)
				end)
				pcall(function()
					BackKnife.setSuppressed(hunter, false)
				end)
				resetDone += 1
			end)
		end
		local resetDeadline = os.clock() + 6
		while resetDone < #hunters and os.clock() < resetDeadline and not MatchState.preemptRound do
			task.wait(0.1)
		end

		-- PREVIEW: teleport the armed hunters into the preview room to examine the target
		print("[ReverseRace] PREVIEW -- EXAMINE THE HIDER!")
		broadcastState("PREVIEW", ReverseRaceConfig.PREVIEW_SECONDS, "EXAMINE THE HIDER!")
		local previewPlaced = {}
		local cleanupPreview = ReverseRacePreview.showTarget(target, hunters, previewPlaced)
		for _, h in ipairs(hunters) do
			ScreenFade:FireClient(h, "out", { fadeTime = 0.35 })
			rrTimer(h, "PREVIEW", ReverseRaceConfig.PREVIEW_SECONDS, TEXT.PREVIEW_TITLE, "Preview")
			if not hasOnboarded(h, HUNTER_FLAG) then
				markOnboarded(h, HUNTER_FLAG)
				notifyOnboard(h, TEXT.HUNTER_ONBOARD_TITLE, TEXT.HUNTER_ONBOARD_SUB)
			end
		end
		rrTimer(target, "PREVIEW", ReverseRaceConfig.PREVIEW_SECONDS, TEXT.PREVIEW_TARGET_TITLE, "Preview")
		phaseWait(ReverseRaceConfig.PREVIEW_SECONDS, function()
			return target.Parent ~= nil
		end)
		cleanupPreview()
		if MatchState.preemptRound then
			break
		end

		-- HUNT: send the (already armed) hunters from the preview room into the map
		print("[ReverseRace] HUNT -- FIND WHERE THEY ARE HIDING!")
		broadcastState("HUNT", ReverseRaceConfig.HUNT_SECONDS, "FIND WHERE THEY ARE HIDING!")
		local mapPlaced = {}
		local mapPlacedCount = 0
		for hi, h in ipairs(hunters) do
			local hunter, spot = h, Placement.mapTarget(hi)
			task.spawn(function()
				pcall(function()
					Placement.setDesiredPlacement(hunter, spot, {
						convert = false,
						valid = function(p)
							return MatchState.current == "HUNT" and MatchState.roles[p] == "Seeker"
						end,
						onPlaced = function(p)
							if not mapPlaced[p] then
								mapPlaced[p] = true
								mapPlacedCount += 1
							end
						end,
					})
				end)
			end)
		end
		local placementDeadline = os.clock() + 8
		while mapPlacedCount < #hunters and os.clock() < placementDeadline and not MatchState.preemptRound and MatchState.current == "HUNT" do
			task.wait(0.1)
		end
		for _, h in ipairs(hunters) do
			if h.Parent and not mapPlaced[h] then
				warn("[ReverseRace] HUNT map placement still pending for " .. h.Name .. "; opening hunt while placement worker continues")
			end
		end
		for _, h in ipairs(hunters) do
			rrTimer(h, "HUNT", ReverseRaceConfig.HUNT_SECONDS, TEXT.HUNT_TITLE, "Hunt")
		end
		rrTimer(target, "HUNT", ReverseRaceConfig.HUNT_SECONDS, TEXT.HUNTED_TITLE, "Hunted")

		-- Any hunter who did NOT actually stand in the preview room for this target (late joiners
		-- who joined after the room, or whose placement was skipped) gets the target viewport preview
		-- instead -- shown for 12s or until this turn ends -- so they know who they're hunting.
		for _, h in ipairs(hunters) do
			if not previewPlaced[h] then
				showViewportTo(h)
			end
		end

		-- Broadcast the hunters as seekers so the frozen target's Free Cam (spectate) has
		-- someone to watch -- spectate only allows watching seekers.
		do
			local roleMap = {}
			for _, h in ipairs(hunters) do
				roleMap[h.UserId] = "Seeker"
			end
			RoleMapRemote:FireAllClients(roleMap)
		end

		-- ===== HUNTER LIVES =====
		-- Each hunter has 3 lives this turn. Any swing that doesn't hit the target costs a life:
		-- 3s cooldown if they hit another hidden player (decoy), 1.5s otherwise (prop/other). At
		-- 0 lives they become a spectator until the next target turn. The cooldown is enforced by
		-- pulling the knife and giving it back after the delay.
		local lives = {}
		local lastLoss = {}
		-- Swings only count once the hunters are actually in the map. The map teleport is async, so
		-- for a moment after HUNT begins the hunters are still in the preview room -- swinging there
		-- must not cost a life.
		local countingLives = false
		for _, h in ipairs(hunters) do
			lives[h] = ReverseRaceConfig.HUNTER_LIVES
			setLivesBillboard(h, ReverseRaceConfig.HUNTER_LIVES, ReverseRaceConfig.HUNTER_LIVES)
		end
		print(("[ReverseRace][lives] hunt start: %d hunter(s), %d lives each"):format(#hunters, ReverseRaceConfig.HUNTER_LIVES))
		-- Track whether this hunt ever had an active hunter, so we can detect "all hunters eliminated"
		-- (all out of lives, or all left) and end the turn early as a HIDER WIN.
		local everHadActiveHunter = #hunters > 0
		local function activeHunterCount()
			local n = 0
			for _, h in ipairs(hunters) do
				if h.Parent and (lives[h] or 0) > 0 then
					n += 1
				end
			end
			return n
		end
		task.delay(1.2, function()
			countingLives = true
		end)

		local function armLateIntoHunt(plr)
			if not plr or not plr.Parent then
				return
			end
			for _, h in ipairs(hunters) do
				if h == plr then
					return
				end
			end
			table.insert(hunters, plr)
			lives[plr] = ReverseRaceConfig.HUNTER_LIVES
			everHadActiveHunter = true
			MatchState.roles[plr] = "Seeker"
			MatchState.seekerOut[plr] = nil
			setInRound(plr, true)
			MatchRemotes.RoleAnnounce:FireClient(plr, "Seeker")
			SpectateRemote:FireClient(plr, false)
			local slot = #hunters
			task.spawn(function()
				loadDefaultCharacter(plr)
				SpectateRemote:FireClient(plr, false)
				pcall(function()
					Knife.giveKnife(plr)
				end)
				pcall(function()
					BackKnife.setSuppressed(plr, false)
				end)
				setLivesBillboard(plr, ReverseRaceConfig.HUNTER_LIVES, ReverseRaceConfig.HUNTER_LIVES)
				pcall(function()
					Placement.setDesiredPlacement(plr, Placement.mapTarget(slot), { convert = false })
				end)
			end)
			-- Mid-hunt joiners never pass through the preview room, so show them the target viewport.
			showViewportTo(plr)
		end
		liveHunt = { arm = armLateIntoHunt }

		local function loseLife(hunter, cd, reason)
			lastLoss[hunter] = os.clock()
			lives[hunter] = (lives[hunter] or 0) - 1
			print(("[ReverseRace][lives] %s wrong swing (%s): %d left, %.1fs cd"):format(hunter.Name, reason, math.max(0, lives[hunter]), cd))
			setLivesBillboard(hunter, math.max(0, lives[hunter]), ReverseRaceConfig.HUNTER_LIVES)
			do
				local reasonText = ({
					decoy = "Wrong hider -- that wasn't the target!",
					prop = "That's just a prop!",
					air = "You missed!",
				})[reason] or "Wrong swing!"
				local cdText = (cd % 1 == 0) and tostring(math.floor(cd)) or string.format("%.1f", cd)
				local notif = knitSvc("NotificationService")
				if notif then
					pcall(function()
						notif:Preset(hunter, "ERROR", reasonText .. "  -1 life, " .. cdText .. "s cooldown", { Duration = math.max(cd, 2.5) })
					end)
				end
			end
			pcall(function()
				Knife.clearKnife(hunter)
			end)
			if lives[hunter] <= 0 then
				print(("[ReverseRace][lives] %s is OUT -> spectator"):format(hunter.Name))
				sendHUD(hunter, { sound = "LoseAllLives" })
				MatchState.seekerOut[hunter] = true
				removeLivesBillboard(hunter)
				hideCharacter(hunter)
				SpectateRemote:FireClient(hunter, true, true)
			else
				sendHUD(hunter, { sound = "LoseLife" })
				task.delay(cd, function()
					if MatchState.current == "HUNT" and lives[hunter] and lives[hunter] > 0 then
						pcall(function()
							Knife.giveKnife(hunter)
						end)
					end
				end)
			end
		end

		local function classifyHit(hitInstance)
			if not hitInstance then
				return "air"
			end
			if GetPlayerFromPart(hitInstance) == target then
				return "target"
			elseif decoysFolder and hitInstance:IsDescendantOf(decoysFolder) then
				return "decoy"
			end
			return "prop"
		end

		local function penalize(hunter, outcome, source)
			print(("[ReverseRace][lives] %s %s -> %s"):format(hunter.Name, source, outcome))
			if outcome == "target" then
				return
			end
			if outcome == "air" and not ReverseRaceConfig.COUNT_AIR_MISS then
				return
			end
			local cd = (outcome == "decoy") and ReverseRaceConfig.WRONG_HIDER_TAG_COOLDOWN or ReverseRaceConfig.PROP_TAG_COOLDOWN
			loseLife(hunter, cd, outcome)
		end

		local function readyToSwing(hunter)
			if not countingLives then
				return false
			end
			if MatchState.current ~= "HUNT" then
				return false
			end
			local hl = lives[hunter]
			if hl == nil or hl <= 0 then
				return false
			end
			if lastLoss[hunter] and (os.clock() - lastLoss[hunter]) < 0.4 then
				return false
			end
			return true
		end

		-- THROW swing: raycast along the throw path.
		local throwConn = KnifeRemotes.RenderKnifeProjectile.OnServerEvent:Connect(function(hunter, knifeArgs)
			if not readyToSwing(hunter) then
				return
			end
			if typeof(knifeArgs) ~= "table" then
				return
			end
			local x0, dir = knifeArgs.x0, knifeArgs.dir
			if typeof(x0) ~= "Vector3" or typeof(dir) ~= "Vector3" or dir.Magnitude < 1e-3 then
				return
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { hunter.Character }
			params.IgnoreWater = true
			local result = Workspace:Raycast(x0, dir.Unit * 240, params)
			penalize(hunter, classifyHit(result and result.Instance), "throw")
		end)

		-- STAB swing: raycast forward from the hunter (melee range).
		local stabConn = KnifeSwingRemote.OnServerEvent:Connect(function(hunter)
			if not readyToSwing(hunter) then
				return
			end
			local char = hunter.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				return
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char }
			params.IgnoreWater = true
			local result = Workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 16, params)
			penalize(hunter, classifyHit(result and result.Instance), "stab")
		end)

		local wasFound = false
		local foundBy = nil
		local huntConns = {}
		local function watchTarget()
			local char = target.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				table.insert(huntConns, hum.Died:Connect(function()
					wasFound = true
					local tag = hum:FindFirstChild("LastKnifeKiller")
					if tag and tag:IsA("ObjectValue") and tag.Value then
						foundBy = tag.Value
					end
				end))
			end
		end
		watchTarget()
		table.insert(huntConns, target.CharacterAdded:Connect(function()
			task.wait(0.2)
			watchTarget()
		end))

		local huntStart = os.clock()
		local elapsed = 0
		local huntersEliminated = false
		while elapsed < ReverseRaceConfig.HUNT_SECONDS and not wasFound and target.Parent do
			task.wait(0.2)
			elapsed = os.clock() - huntStart
			if MatchState.preemptRound then
				break
			end
			-- SkipPhase command: end the hunt early. wasFound stays false, so it counts as the target
			-- surviving -- matching the regular mode, where skipping the seek phase ends the round with
			-- the survivors revealed.
			if MatchState.skipPhase then
				MatchState.skipPhase = false
				break
			end
			-- Every hunter out of lives (or all left)? The frozen target can no longer be caught,
			-- so they win -- end the hunt early.
			if countingLives and everHadActiveHunter and activeHunterCount() == 0 then
				huntersEliminated = true
				break
			end
		end
		liveHunt = nil
		if MatchState.preemptRound then
			if throwConn then
				throwConn:Disconnect()
			end
			if stabConn then
				stabConn:Disconnect()
			end
			for _, connection in ipairs(huntConns) do
				connection:Disconnect()
			end
			break
		end

		local targetLeft = not target.Parent
		clearViewportTarget()
		if targetLeft then
			print("[ReverseRace] target left mid-hunt -> transitioning to the next target")
		elseif wasFound then
			print(("[ReverseRace] %s was FOUND in %ds"):format(target.Name, math.floor(elapsed)))
			local finderName = (foundBy and foundBy.Parent and foundBy.DisplayName) or "A hunter"
			local notif = knitSvc("NotificationService")
			if notif then
				pcall(function()
					notif:Broadcast({ text = finderName .. " found " .. target.DisplayName .. "!", duration = 3 })
				end)
			end
		elseif huntersEliminated then
			print(("[ReverseRace] %s WON -- all hunters eliminated"):format(target.Name))
			-- Hider win: flat coin boost (skipped in private servers), announced to the target now.
			local WIN_COINS = ReverseRaceConfig.HUNTERS_ELIMINATED_COINS or 300
			local awarded = false
			if not GetEnv:IsPrivateServer() then
				local coin = knitSvc("CoinService")
				if coin then
					pcall(function()
						coin:Award(target, WIN_COINS, "Reverse Race win - hunters eliminated")
					end)
					ensureStats(target).coins += WIN_COINS
					awarded = true
				end
			end
			local notif = knitSvc("NotificationService")
			if notif then
				local msg = awarded
					and ("You survived! All hunters are out.  +" .. WIN_COINS .. " coins!")
					or "You survived! All hunters are out."
				pcall(function()
					notif:Preset(target, "SUCCESS", msg, { Duration = 6 })
				end)
			end
		else
			print(("[ReverseRace] %s SURVIVED the hunt"):format(target.Name))
		end

		-- ===== SCORING (this target's turn) =====
		-- Skip the survivor's scoring entirely if they left mid-turn (nothing to award a departed player).
		if not targetLeft then
			local survivedSecs = wasFound and math.floor(elapsed) or ReverseRaceConfig.HUNT_SECONDS
			local _, hCoins = ReverseRaceConfig.hiderReward(survivedSecs)
			if hCoins and hCoins > 0 then
				awardReward(target, 0, hCoins, "Reverse Race survival")
				ensureStats(target).coins += hCoins
			end
			-- Hider Turn XP: +1 XP per 3 seconds survived while selected as the target.
			local hiderXP = math.floor(survivedSecs / ReverseRaceConfig.XP.HIDER_SECONDS_PER_XP) * ReverseRaceConfig.XP.HIDER_XP_PER_TICK
			awardXP(target, hiderXP, "Reverse Race survival")
			-- Victory Bonus: the hider wins the turn only if they actually survived (weren't found).
			if not wasFound then
				awardXP(target, ReverseRaceConfig.XP.VICTORY, "Reverse Race hider win")
			end
			do
				local ts = ensureStats(target)
				ts.longestSurvival = math.max(ts.longestSurvival or 0, survivedSecs)
			end
			if not results.longestSurvival or survivedSecs > results.longestSurvival.secs then
				results.longestSurvival = { name = target.DisplayName, userId = target.UserId, secs = survivedSecs }
			end
			print(("[ReverseRace][score] %s survived %ds -> +%d XP"):format(target.Name, survivedSecs, hiderXP))
		end

		if wasFound and foundBy and foundBy.Parent then
			local findSecs = math.floor(elapsed)
			local _, uCoins = ReverseRaceConfig.hunterReward(findSecs)
			uCoins = uCoins or 0
			if uCoins > 0 then
				awardReward(foundBy, 0, uCoins, "Reverse Race find")
			end
			-- Hunter find XP (+12) plus a speed bonus for how early in the hunt the target was found.
			local speedBonus = huntSpeedBonusXP(elapsed, ReverseRaceConfig.HUNT_SECONDS)
			awardXP(foundBy, ReverseRaceConfig.XP.HUNTER_FIND + speedBonus, "Reverse Race find")
			do
				local fs = ensureStats(foundBy)
				fs.kills += 1
				fs.coins += uCoins
				if not fs.fastestFind or findSecs < fs.fastestFind then
					fs.fastestFind = findSecs
				end
			end
			if not results.fastestFind or findSecs < results.fastestFind.secs then
				results.fastestFind = { name = foundBy.DisplayName, userId = foundBy.UserId, secs = findSecs }
			end
			print(("[ReverseRace][score] %s found in %ds -> +%d find / +%d speed XP"):format(foundBy.Name, findSecs, ReverseRaceConfig.XP.HUNTER_FIND, speedBonus))
			-- Hunters won this turn: team find bonus (+6) + victory bonus (+30) XP to every active hunter.
			-- The team-find COIN bonus is accrued as points here and paid out as coins (10 per point) at the
			-- END of the round, not awarded immediately. (The finder is an active hunter too.)
			for _, h in ipairs(hunters) do
				if h.Parent and (lives[h] or 0) > 0 then
					teamFindPoints[h.UserId] = (teamFindPoints[h.UserId] or 0) + ReverseRaceConfig.TEAM_FIND_POINTS
					awardXP(h, ReverseRaceConfig.XP.TEAM_FIND_PER_HUNTER + ReverseRaceConfig.XP.VICTORY, "Reverse Race team win")
				end
			end
		end

		broadcastLeaderboard()

		-- End this target's Free Cam (they use the standard Freecam button). Leave the spectate role
		-- map as-is so any out-of-lives spectators keep a valid target until they're re-placed next turn.
		target:SetAttribute("ReverseRaceFreeCam", false)

		-- ===== REVEAL: if the target survived, highlight them RED so the hunters can see where they
		-- were hiding (mirrors the regular mode's REVEALING_HIDERS phase). Skipped if they were found
		-- or left. Uses the shared RevealHighlights module for the same red, see-through-walls look.
		if not targetLeft and not wasFound and target.Character then
			broadcastState("REVEAL", ReverseRaceConfig.REVEAL_SECONDS, "reveal")
			local revealHls = RevealHighlights.show({ target })
			for _, h in ipairs(hunters) do
				if h.Parent then
					rrTimer(h, "REVEAL", ReverseRaceConfig.REVEAL_SECONDS, TEXT.REVEAL_TITLE, "Reveal")
				end
			end
			if target.Parent then
				rrTimer(target, "REVEAL", ReverseRaceConfig.REVEAL_SECONDS, TEXT.REVEAL_TARGET_TITLE, "Reveal")
			end
			phaseWait(ReverseRaceConfig.REVEAL_SECONDS)
			RevealHighlights.clear(revealHls)
		end

		-- disarm hunters and end the turn. The ex-target is left as-is (frozen or found) and
		-- gets reset behind the fade when they become a hunter next turn -- respawning them
		-- here would bounce them through the lobby.
		if throwConn then
			throwConn:Disconnect()
		end
		if stabConn then
			stabConn:Disconnect()
		end
		for _, c in ipairs(huntConns) do
			c:Disconnect()
		end
		for _, h in ipairs(hunters) do
			pcall(function()
				Knife.clearKnife(h)
			end)
			sendHUD(h, { hideLives = true })
			removeLivesBillboard(h)
			setInRound(h, false)
			MatchState.seekerOut[h] = nil
			MatchState.roles[h] = nil
		end

		-- TODO (Phase 4/5): record target survivedSeconds + winning hunter findSeconds from hunt outcome

		-- TRANSITION
		phaseWait(ReverseRaceConfig.TRANSITION_SECONDS)
	end

	if decoysFolder then
		decoysFolder:Destroy()
	end

	-- round over: cancel any free cam, unfreeze + respawn everyone back to the lobby
	RoleMapRemote:FireAllClients({})
	clearViewportTarget()
	for _, plr in ipairs(players) do
		if plr.Parent then
			SpectateRemote:FireClient(plr, false)
			rrClearTimer(plr)
			plr:SetAttribute("InMatch", false)
			plr:SetAttribute("ReverseRaceFreeCam", false)
			plr:SetAttribute("ReverseRacePreserveDisguise", nil)
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = false
			end
			pcall(function()
				plr:LoadCharacter()
			end)
		end
	end

	roundActive = false
	local wasPreempted = MatchState.preemptRound
	MatchState.preemptRound = false
	for _, plr in ipairs(lateHunters) do
		if plr.Parent then
			SpectateRemote:FireClient(plr, false)
			rrClearTimer(plr)
			plr:SetAttribute("InMatch", false)
			plr:SetAttribute("ReverseRaceFreeCam", false)
			plr:SetAttribute("ReverseRacePreserveDisguise", nil)
			removeLivesBillboard(plr)
			pcall(function()
				Knife.clearKnife(plr)
			end)
			pcall(function()
				plr:LoadCharacter()
			end)
		end
	end
	for plr in pairs(offeredSet) do
		if plr.Parent and not lateSet[plr] then
			offerJoinRemote:FireClient(plr, false)
		end
	end
	if addedConn then
		addedConn:Disconnect()
	end
	if joinConn then
		joinConn:Disconnect()
	end
	if wasPreempted then
		print("[ReverseRace] === ROUND PREEMPTED FOR PAINT BOSS ===")
		return
	end

	-- ===== ROUND PLAYED XP: +12 to everyone who participated (capped like all other XP) =====
	for _, plr in ipairs(players) do
		awardXP(plr, ReverseRaceConfig.XP.ROUND_PLAYED, "Reverse Race round played")
	end
	for _, plr in ipairs(lateHunters) do
		awardXP(plr, ReverseRaceConfig.XP.ROUND_PLAYED, "Reverse Race round played")
	end

	-- ===== TEAM-FIND BONUS PAYOUT: convert each player's accrued team-find points to coins (10 per
	-- point) and pay them out here at round end, so the bonus lands with the other end-of-round rewards
	-- instead of popping mid-round. Folded into the summary's coin total below. =====
	for uid, pts in pairs(teamFindPoints) do
		local coins = pts * 10  -- 10 coins per point
		if coins > 0 then
			local plr = Players:GetPlayerByUserId(uid)
			if plr then
				awardReward(plr, 0, coins, "Reverse Race team-find bonus")
			end
			local st = myStats[uid]
			if st then
				st.coins += coins
			end
		end
	end

	-- ===== END SCREEN: per-player results summary (placement + personal stats) =====
	local ranking = {}
	for _, e in pairs(results.points) do
		table.insert(ranking, e)
	end
	table.sort(ranking, function(a, b)
		return a.points > b.points
	end)
	local placeByUser = {}
	for i, e in ipairs(ranking) do
		placeByUser[e.userId] = i
	end

	local function ordinal(n)
		local suffix = "th"
		local ones = n % 10
		local tens = math.floor(n / 10) % 10
		if tens ~= 1 then
			if ones == 1 then
				suffix = "st"
			elseif ones == 2 then
				suffix = "nd"
			elseif ones == 3 then
				suffix = "rd"
			end
		end
		return tostring(n) .. suffix
	end

	local function fmtSecs(s)
		if not s then
			return "--"
		end
		s = math.max(0, math.floor(s))
		if s < 60 then
			return s .. "s"
		end
		return string.format("%dm %02ds", math.floor(s / 60), s % 60)
	end

	local function sendSummary(plr)
		if not plr or not plr.Parent then
			return
		end
		local uid = plr.UserId
		local st = myStats[uid] or { fastestFind = nil, longestSurvival = nil, kills = 0, coins = 0 }
		local snap = levelSnapshot[uid] or snapshotLevel(plr)
		local place = placeByUser[uid] or #ranking
		local totalPoints = (results.points[uid] and results.points[uid].points) or 0
		local earnedXP = xpEarned[uid] or 0
		local capXP = xpCapFor(plr)
		RoundSummary:FireClient(plr, {
			won = true,
			myUserId = uid,
			roleText = ordinal(place) .. " Place",
			roleColor = { 255, 205, 55 },
			statsRows = {
				{ label = "Fastest Find", valueText = fmtSecs(st.fastestFind) },
				{ label = "Longest Survival", valueText = fmtSecs(st.longestSurvival) },
				{ label = "Kills", valueText = tostring(st.kills or 0) },
			},
			totalXp = totalPoints,
			xpCapped = earnedXP >= capXP,
			xpEarned = earnedXP,
			xpCap = capXP,
			coinsEarned = st.coins or 0,
			level = snap and snap.level or 1,
			xp = snap and snap.xp or 0,
			xpNeeded = snap and snap.xpNeeded,
			maxLevel = snap and snap.maxLevel,
			leveledUp = false,
		})
	end

	for _, plr in ipairs(players) do
		sendSummary(plr)
	end
	for _, plr in ipairs(lateHunters) do
		sendSummary(plr)
	end

	fireParticipants(leaderboardRemote, { hide = true })
	task.wait(8)

	print("[ReverseRace] === ROUND END ===")
end

function ReverseRace.cleanup(ctx)
	MatchState.preemptRound = false
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("ReverseRacePreserveDisguise", nil)
	end
	if ReverseRace._roundConns then
		for _, c in ipairs(ReverseRace._roundConns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		ReverseRace._roundConns = {}
	end
end

return ReverseRace
