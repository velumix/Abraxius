-- GroupRewardChestServer: an hourly chest. Touch the ChestPad to claim:
--   * in the community group + off cooldown -> +100 coins, play CoinReward, start a 1h cooldown
--   * not in the group                      -> tell the client to prompt joining the group
--   * on cooldown                            -> tell the client how long until it resets
-- Cooldown is per-player and persisted (DataStore) so it survives rejoin/server hops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _coin
local function coinSvc() if not _coin then _coin = svc("CoinService") end return _coin end

-- ===== config =====
local GROUP_ID = 133797237          -- "Blend In Or Die" community group
local REWARD_COINS = 100
local COOLDOWN = 60 * 60            -- 1 hour, in seconds
local chest = Workspace:WaitForChild("LobbyInteractives"):FindFirstChild("GroupRewardChest", true)
local pad = chest:WaitForChild("ChestPad")
-- the pad relies on .Touched, which only fires when CanTouch is true; enforce it (defensive: the part
-- was shipped with CanTouch=false, which silently broke the chest).
if pad:IsA("BasePart") then pad.CanTouch = true end

local cooldownStore = DataStoreService:GetDataStore("GroupChestCooldown_v1")

-- remote: server -> client outcome { kind = "reward"|"notingroup"|"cooldown", remaining = number? }
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local GroupChestResult = Remotes:FindFirstChild("GroupChestResult")
if not GroupChestResult then
	GroupChestResult = Instance.new("RemoteEvent")
	GroupChestResult.Name = "GroupChestResult"
	GroupChestResult.Parent = Remotes
end
-- remote: client asks for its current cooldown remaining (to drive the timer text on join)
local GroupChestQuery = Remotes:FindFirstChild("GroupChestQuery")
if not GroupChestQuery then
	GroupChestQuery = Instance.new("RemoteEvent")
	GroupChestQuery.Name = "GroupChestQuery"
	GroupChestQuery.Parent = Remotes
end

-- in-memory cache of last-claim os.time() per userId (loaded from DataStore on demand)
local lastClaim = {}

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
		-- couldn't load; treat as unknown (0) but don't cache, so we retry next time
		return 0
	end
	return lastClaim[userId]
end

local function remainingCooldown(userId)
	local last = getLastClaim(userId)
	local elapsed = os.time() - last
	if elapsed >= COOLDOWN then return 0 end
	return COOLDOWN - elapsed
end

-- per-player debounce so a single step on the pad doesn't fire dozens of touches
local busy = {}

local function tryClaim(player)
	if busy[player.UserId] then return end
	busy[player.UserId] = true

	-- 1) in the group? Check membership FIRST, so a non-member is always prompted to join (a non-member
	-- can't have legitimately claimed, so they should never be blocked by a cooldown). Use the async
	-- (fresh) query so a just-joined player is recognised immediately (the synchronous IsInGroup can
	-- return a stale cached result right after they join via the prompt).
	local okGroup, inGroup = pcall(function()
		return player:IsInGroupAsync(GROUP_ID)
	end)
	if not okGroup then
		-- membership check failed (web error); let them try again shortly
		busy[player.UserId] = nil
		return
	end

	if not inGroup then
		GroupChestResult:FireClient(player, { kind = "notingroup" })
		task.delay(2, function() busy[player.UserId] = nil end)
		return
	end

	-- 2) on cooldown?
	local remaining = remainingCooldown(player.UserId)
	if remaining > 0 then
		GroupChestResult:FireClient(player, { kind = "cooldown", remaining = remaining })
		task.delay(1, function() busy[player.UserId] = nil end)
		return
	end

	-- 3) eligible -> grant reward, stamp + persist the cooldown
	local now = os.time()
	lastClaim[player.UserId] = now
	pcall(function()
		cooldownStore:SetAsync("u_" .. player.UserId, now)
	end)

	coinSvc():Credit(player, REWARD_COINS, "group chest hourly")
	GroupChestResult:FireClient(player, { kind = "reward", remaining = COOLDOWN, amount = REWARD_COINS })

	task.delay(2, function() busy[player.UserId] = nil end)
end

pad.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorWhichIsA("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if player then
		tryClaim(player)
	end
end)

-- answer client cooldown queries, and allow a client-requested claim (used right after the player
-- joins via the in-experience prompt, so they get the reward immediately without re-touching).
GroupChestQuery.OnServerEvent:Connect(function(player, action)
	if action == "claim" then
		tryClaim(player)
	else
		GroupChestResult:FireClient(player, { kind = "cooldown", remaining = remainingCooldown(player.UserId) })
	end
end)

-- clear cache when a player leaves
Players.PlayerRemoving:Connect(function(player)
	lastClaim[player.UserId] = nil
	busy[player.UserId] = nil
end)
