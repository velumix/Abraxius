-- SeekerQueueAdManager: lets a player WATCH A REWARDED VIDEO AD to earn one guaranteed-seeker queue
-- spot, with a persistent 10-minute cooldown between ad watches (survives rejoin / server hops).
--
-- Uses the SAME rewarded-ad method as the lobby Watch-Ad signs:
--   client checks AdService:GetAdAvailabilityNowAsync(RewardedVideo) and fires a remote ->
--   server calls AdService:ShowRewardedVideoAdAsync(player, reward), where
--   reward = AdService:CreateAdRewardFromDevProductId(<devProductId>).
-- On ad COMPLETION, Roblox fires ProcessReceipt for that dev product. We back this reward with the
-- existing GUARANTEED_SEEKER_PRODUCT (3601754778) -- its ProcessReceipt branch in MatchManager already
-- does "add this player to the seeker queue" -- so finishing the ad adds exactly one queue spot through
-- the same code path a Robux purchase uses. (The cooldown is enforced ONLY here in the ad flow, so real
-- Robux "Be Seeker" purchases are completely unaffected.)
--
-- Cooldown persistence mirrors ObbyWinnerPadServer: a DataStore keyed by userId stores the last
-- ad-claim os.time(); we stamp it only when ShowRewardedVideoAdAsync returns ShowCompleted (so a failed
-- load or an early-closed ad does NOT burn the cooldown).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local AdService = game:GetService("AdService")

-- ===== config =====
local COOLDOWN = 10 * 60                 -- 10 minutes, in seconds
local SEEKER_PRODUCT_ID = 3601754778     -- GUARANTEED_SEEKER_PRODUCT (the "Be Seeker" dev product). Its
                                         -- ProcessReceipt branch in MatchManager adds a seeker-queue spot.

local cooldownStore = DataStoreService:GetDataStore("SeekerQueueAdCooldown_v1")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")

-- client -> server: "I clicked Watch Ad; show me the rewarded video."
local ClaimSeekerQueueAd = Remotes:FindFirstChild("ClaimSeekerQueueAd")
if not ClaimSeekerQueueAd then
	ClaimSeekerQueueAd = Instance.new("RemoteEvent")
	ClaimSeekerQueueAd.Name = "ClaimSeekerQueueAd"
	ClaimSeekerQueueAd.Parent = Remotes
end

-- server -> client: cooldown / result status so the button can show its state
--   { kind = "cooldown", remaining = n }  -- still on cooldown, n seconds left
--   { kind = "reward" }                    -- ad completed, queue spot granted, cooldown (re)started
--   { kind = "unavailable" }               -- no ad available / ad failed to show
local SeekerQueueAdStatus = Remotes:FindFirstChild("SeekerQueueAdStatus")
if not SeekerQueueAdStatus then
	SeekerQueueAdStatus = Instance.new("RemoteEvent")
	SeekerQueueAdStatus.Name = "SeekerQueueAdStatus"
	SeekerQueueAdStatus.Parent = Remotes
end

-- client -> server: ask for current cooldown remaining (to seed the button text on open/join)
local SeekerQueueAdQuery = Remotes:FindFirstChild("SeekerQueueAdQuery")
if not SeekerQueueAdQuery then
	SeekerQueueAdQuery = Instance.new("RemoteEvent")
	SeekerQueueAdQuery.Name = "SeekerQueueAdQuery"
	SeekerQueueAdQuery.Parent = Remotes
end

-- ===== persistent cooldown (mirrors ObbyWinnerPadServer) =====
local lastClaim = {}  -- in-memory cache of last-claim os.time() per userId

local function getLastClaim(userId)
	if lastClaim[userId] ~= nil then
		return lastClaim[userId]
	end
	local ok, value = pcall(function()
		return cooldownStore:GetAsync("u_" .. userId)
	end)
	if ok then
		lastClaim[userId] = value or 0
	else
		return 0  -- couldn't load; treat as off-cooldown but don't cache, so we retry next time
	end
	return lastClaim[userId]
end

local function remainingCooldown(userId)
	local last = getLastClaim(userId)
	local elapsed = os.time() - last
	if elapsed >= COOLDOWN then return 0 end
	return COOLDOWN - elapsed
end

local function stampCooldown(userId)
	local now = os.time()
	lastClaim[userId] = now
	pcall(function() cooldownStore:SetAsync("u_" .. userId, now) end)
end

-- per-player debounce so spamming the button can't open multiple ad requests at once
local busy = {}

-- NOTE: there is intentionally no server-side ad-availability probe here. We mirror the lobby coins
-- Watch-Ad sign, which goes straight to ShowRewardedVideoAdAsync and treats its ShowCompleted result
-- as the only arbiter. The client (SeekerQueueShopClient.adLikelyAvailable) does a permissive
-- pre-check to avoid pointless requests; a SECOND probe on the server would only add a chance to
-- falsely report "unavailable" when an ad is actually available.

ClaimSeekerQueueAd.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	if busy[userId] then return end
	busy[userId] = true

	local function release(delaySec)
		task.delay(delaySec or 1, function() busy[userId] = nil end)
	end

	-- 1) cooldown gate (persistent)
	local remaining = remainingCooldown(userId)
	if remaining > 0 then
		SeekerQueueAdStatus:FireClient(player, { kind = "cooldown", remaining = remaining })
		release(1)
		return
	end

	-- 2) show the rewarded video. On ShowCompleted, Roblox fires ProcessReceipt for SEEKER_PRODUCT_ID,
	-- which adds the seeker-queue spot (MatchManager). We stamp the cooldown only on a completed view.
	--
	-- IMPORTANT: we do NOT do a server-side GetAdAvailabilityNowAsync pre-check here. The lobby coins
	-- Watch-Ad sign (which works) goes straight from the client's permissive pre-check to
	-- ShowRewardedVideoAdAsync, letting that call's ShowCompleted result be the SOLE arbiter. A second
	-- availability probe on the server (milliseconds after the client's) can transiently report a
	-- non-eligible state and falsely send "unavailable" even when an ad is right there -- that mismatch
	-- is exactly why this button said "Unavailable" while the coins sign worked for the same player. The
	-- client already pre-checks (adLikelyAvailable) to avoid pointless requests; here we just show it.
	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(SEEKER_PRODUCT_ID)
		return AdService:ShowRewardedVideoAdAsync(player, reward)
	end)

	if ok and result == Enum.ShowAdResult.ShowCompleted then
		stampCooldown(userId)
		SeekerQueueAdStatus:FireClient(player, { kind = "reward", remaining = COOLDOWN })
	else
		-- not completed (failed to load, interrupted, or closed early): no reward, no cooldown burned
		SeekerQueueAdStatus:FireClient(player, { kind = "unavailable" })
	end

	release(2)
end)

-- seed the button with current cooldown on request (open / join)
SeekerQueueAdQuery.OnServerEvent:Connect(function(player)
	local remaining = remainingCooldown(player.UserId)
	SeekerQueueAdStatus:FireClient(player, { kind = (remaining > 0) and "cooldown" or "ready", remaining = remaining })
end)

-- drop the cache when a player leaves so it can't go stale across a rejoin in a long-lived server
Players.PlayerRemoving:Connect(function(player)
	lastClaim[player.UserId] = nil
end)

print("[SeekerQueueAdManager] ready (watch ad -> seeker queue, 10m persistent cooldown)")
