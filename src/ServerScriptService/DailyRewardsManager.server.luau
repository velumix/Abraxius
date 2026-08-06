-- DailyRewardsManager (server): tracks each player's daily-login streak + last-claim time in a
-- DataStore, decides when a claim is available, grants the configured reward, and tells the client
-- what to show. The reward track itself lives in ReplicatedStorage.DailyRewardsConfig (shared with
-- the client so display == grant).
--
-- RULES (per the design):
--   * 24h between claims. After claiming, the next claim unlocks CLAIM_INTERVAL seconds later.
--   * Streak advances by 1 each claimed day; it LOOPS back to Day 1 after the last configured day.
--   * Missing a day (more than MISS_AFTER seconds since the last claim, without claiming) RESETS the
--     streak to Day 1.
--   * The GUI opens on join ONLY when a claim is available.
--
-- All timing is server-authoritative (os.time()); the client only displays a countdown and sends a
-- claim request, which the server re-validates before granting (so a tampered client can't over-claim).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("DailyRewardsConfig"))

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

-- ===== reward-granting dependencies (resolved lazily; all optional-safe) =====
local UnboxManager
local function deps()
	if not UnboxManager then
		local m = ServerScriptService:FindFirstChild("UnboxManager")
		if m then UnboxManager = require(m) end
	end
end

local DEFAULT_DATA = { streak = 0, lastClaim = 0, loaded = true }
local cache = {}  -- [userId] = data table (authoritative in-memory copy for the session)

local function saveData(player)
	local userId = player.UserId
	local data = cache[userId]
	if not data then return end
	-- NEVER save a record whose load failed: it would overwrite the real streak with Day 1.
	if data.loaded == false then
		warn("[DailyRewardsManager] skipping save for u_" .. userId .. " (load had failed; protecting real streak)")
		return
	end
	local d = dataSvc()
	if not d then
		warn("[DailyRewardsManager] saveData: DataService unavailable for u_" .. userId)
		return
	end
	d:SetDaily(player, data.streak, data.lastClaim)
	d:Save(player)
end

-- ===== Remotes =====
local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remotes then
	remotes = Instance.new("Folder"); remotes.Name = "GameRemotes"; remotes.Parent = ReplicatedStorage
end
local function getRemote(name, class)
	local r = remotes:FindFirstChild(name)
	if not r then r = Instance.new(class); r.Name = name; r.Parent = remotes end
	return r
end
-- server -> client: push the current daily state {available, streak, claimedDay, nextClaimAt, dayCount}
local DailyState = getRemote("DailyRewardsState", "RemoteEvent")
-- client -> server: request to claim. server validates + grants, then pushes a fresh state.
local DailyClaim = getRemote("DailyRewardsClaim", "RemoteEvent")

-- ===== state computation =====
-- Given stored data + now, compute the player-facing state.
--   available  : is a claim available right now?
--   streak     : the streak the player is ON (the day they would claim next is `streak` for display)
--   claimedDay : how many days in the current streak have been claimed (for marking cards Claimed)
--   nextClaimAt: unix time when the next claim unlocks (for the countdown). 0 if available now.
local function computeState(data, now)
	now = now or os.time()
	local lastClaim = data.lastClaim or 0
	local streak = data.streak or 0

	if lastClaim == 0 then
		-- never claimed: Day 1 is available immediately
		return { available = true, claimedDay = 0, nextClaimAt = 0 }
	end

	local elapsed = now - lastClaim
	if elapsed >= Config.MISS_AFTER then
		-- missed a day -> streak resets; Day 1 available now
		return { available = true, claimedDay = 0, nextClaimAt = 0, reset = true }
	elseif elapsed >= Config.CLAIM_INTERVAL then
		-- 24h passed but within the miss window -> next day available, continuing the streak
		return { available = true, claimedDay = streak, nextClaimAt = 0 }
	else
		-- claimed recently; waiting for the 24h window. Not available; show countdown.
		return { available = false, claimedDay = streak, nextClaimAt = lastClaim + Config.CLAIM_INTERVAL }
	end
end

-- Build the payload sent to the client.
local function buildPayload(userId)
	local data = cache[userId] or DEFAULT_DATA
	local st = computeState(data, os.time())
	return {
		available   = st.available,
		claimedDay  = st.claimedDay,        -- number of consecutive days already claimed in this streak
		nextClaimAt = st.nextClaimAt,       -- unix time the next claim unlocks (0 if available now)
		lastClaimAt = data.lastClaim or 0,  -- unix time of the last claim (0 = never); for the client's
		                                    -- miss-window check when its local countdown elapses
		dayCount    = Config.dayCount(),
	}
end

local function pushState(player)
	if not player or not player.Parent then return end
	DailyState:FireClient(player, buildPayload(player.UserId))
end

-- ===== granting =====
local function grantReward(player, reward)
	if not reward then return end
	deps()
	if reward.kind == "coins" then
		-- use credit() (not award()): award() is blocked in private/Studio servers and applies the
		-- Double Coins 2x multiplier — neither is wanted for a fixed daily reward. credit() grants the
		-- exact amount everywhere and pushes the new balance to the client.
		coinSvc():Credit(player, reward.amount or 0, "DailyReward")
	elseif reward.kind == "crate" then
		-- open as a REWARD (not a shop purchase) so the crate shop does NOT reopen afterwards (the player
		-- didn't open it from the shop) and the header reads "Daily Reward".
		if UnboxManager and UnboxManager.openCrateAsReward and reward.crate then
			UnboxManager.openCrateAsReward(player, reward.crate, "Daily Reward")
		end
	elseif reward.kind == "knife" then
		if reward.skinId then
			local d = dataSvc()
			if d then d:AddWeapon(player, reward.skinId, nil, true) end
		end
	elseif reward.kind == "random_legendary" then
		-- play the unbox animation landing on a random Legendary from one of the standard crates
		-- (Brainrot / Graffiti / Basic). UnboxManager picks the crate + the specific Legendary, grants
		-- it, and runs the reel. Opened as a reward so the crate shop does NOT reopen afterwards.
		if UnboxManager and UnboxManager.openLegendaryReward then
			UnboxManager.openLegendaryReward(player, { "Brainrot Crate", "Silver Crate", "Wooden Crate" }, "Daily Reward")
		end
	end
end

-- ===== claim handler =====
local claiming = {}  -- debounce per userId
local function handleClaim(player)
	local userId = player.UserId
	if claiming[userId] then return end
	claiming[userId] = true

	local data = cache[userId]
	if not data then claiming[userId] = nil; return end
	-- If their load FAILED (loaded=false), refuse to claim: we'd be granting against a fake Day-1
	-- fallback and the save would be skipped anyway. Resync the UI and bail.
	if data.loaded == false then
		pushState(player)
		claiming[userId] = nil
		return
	end

	local now = os.time()
	local st = computeState(data, now)
	if not st.available then
		-- not actually claimable (client out of sync or tampering) -> just resync
		pushState(player)
		claiming[userId] = nil
		return
	end

	-- determine which day is being claimed: reset -> Day 1, else continue (loops via rewardForDay)
	local newStreak
	if st.reset or (data.lastClaim or 0) == 0 then
		newStreak = 1
	else
		newStreak = (data.streak or 0) + 1
	end

	local reward = Config.rewardForDay(newStreak)

	-- commit FIRST (so a grant error can't let them re-claim), then grant
	data.streak = newStreak
	data.lastClaim = now
	saveData(player)

	grantReward(player, reward)

	-- tell the client the claim went through (so it can flip the card to Claimed + restart timer).
	-- Include justClaimed + the reward details so the client can play the success feedback (coin sound
	-- + floating text + confetti). For a crate reward we flag claimedCrate so the client SKIPS the coin
	-- sound/text (the unbox animation provides its own feedback) but still pops confetti.
	local payload = buildPayload(userId)
	payload.justClaimed = true
	payload.rewardKind = reward and reward.kind or nil
	payload.rewardAmount = reward and reward.amount or nil
	payload.rewardLabel = reward and reward.label or nil
	DailyState:FireClient(player, payload)

	claiming[userId] = nil
end

DailyClaim.OnServerEvent:Connect(function(player)
	handleClaim(player)
end)

-- ===== lifecycle =====
local function onJoin(player)
	local d
	for _ = 1, 60 do
		d = dataSvc()
		if d then break end
		task.wait(0.5)
	end
	if not d then
		warn("[DailyRewardsManager] DataService never became available for " .. player.Name)
		return
	end

	d:WaitForData(player)
	if player.Parent then
		local streak, lastClaim = d:GetDaily(player)
		cache[player.UserId] = { streak = streak, lastClaim = lastClaim, loaded = d:IsReady(player) }
	end
	-- give the client a moment to set up its GUI listener, then push initial state
	task.delay(2, function()
		if player.Parent then pushState(player) end
	end)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do onJoin(p) end
Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	cache[player.UserId] = nil
	claiming[player.UserId] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do saveData(p) end
end)
