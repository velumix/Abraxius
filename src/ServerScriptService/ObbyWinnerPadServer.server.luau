-- ObbyWinnerPadServer: touch the ObbyWinnerPad to claim 20 coins, then a 5-minute cooldown.
--   off cooldown -> +20 coins, start a 5-minute per-player cooldown
--   on cooldown  -> tell the client how long until it resets (drives the countdown TextLabel)
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
local REWARD_COINS = 20
local COOLDOWN = 5 * 60          -- 5 minutes, in seconds
local pad = Workspace:WaitForChild("LobbyInteractives"):FindFirstChild("ObbyWinnerPad", true)

local cooldownStore = DataStoreService:GetDataStore("ObbyWinnerPadCooldown_v1")

-- MatchManager exposes round state via BindableFunctions (children of its Script). We read these
-- DEFENSIVELY (they're created at runtime; pcall + nil-guards) to decide whether it's safe to do the
-- pad's delayed lobby teleport. This prevents a race: if a player steps on the pad at the exact moment
-- a round starts, the round teleports them onto the map (under a black screen) and then the pad's
-- 2s-delayed teleport would yank them BACK to the lobby — stranding them there for the whole round.
-- We only do the lobby teleport when the player is genuinely a lobby player (intermission, or no role).
local MatchManager = ServerScriptService:FindFirstChild("MatchManager")
local function playerIsInRound(player)
	if not MatchManager then return false end
	-- phase check: HIDE or ROUND means a round is actively running
	local phaseApi = MatchManager:FindFirstChild("GetPhase")
	if phaseApi then
		local ok, phase = pcall(function() return phaseApi:Invoke() end)
		if ok and (phase == "HIDE" or phase == "ROUND") then
			-- a round is live; check whether THIS player has a round role (is a participant)
			local roleApi = MatchManager:FindFirstChild("GetRole")
			if roleApi then
				local okR, role = pcall(function() return roleApi:Invoke(player) end)
				if okR and role ~= nil then return true end  -- they're in this round
			else
				-- no role API available: be safe and treat a live round as "don't teleport"
				return true
			end
		end
	end
	return false
end

-- Resolve a lobby spawn target (same logic MatchManager uses). Supports MULTIPLE SpawnLocations
-- named "LobbySpawn": collect them all and pick one at random so players don't stack on one spot.
-- Prefer ones under Workspace.LobbyFixtures, fall back to any "LobbySpawn" BasePart anywhere.
local function getLobbyTarget()
	local spawns = {}
	local fixtures = Workspace:FindFirstChild("LobbyFixtures")
	if fixtures then
		for _, d in ipairs(fixtures:GetDescendants()) do
			if d.Name == "LobbySpawn" and d:IsA("BasePart") then table.insert(spawns, d) end
		end
	end
	if #spawns == 0 then
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d.Name == "LobbySpawn" and d:IsA("BasePart") then table.insert(spawns, d) end
		end
	end
	if #spawns > 0 then
		local spawn = spawns[math.random(1, #spawns)]
		local top = spawn.Position.Y + spawn.Size.Y / 2
		local hx = math.max(0, math.floor(spawn.Size.X / 2 - 4))
		local hz = math.max(0, math.floor(spawn.Size.Z / 2 - 4))
		return CFrame.new(
			spawn.Position.X + math.random(-hx, hx),
			top + 5,
			spawn.Position.Z + math.random(-hz, hz)
		)
	end
	return CFrame.new(0, 50, 0)
end

-- remote: server -> client outcome { kind = "reward"|"cooldown", remaining = number? }
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ObbyPadResult = Remotes:FindFirstChild("ObbyPadResult")
if not ObbyPadResult then
	ObbyPadResult = Instance.new("RemoteEvent")
	ObbyPadResult.Name = "ObbyPadResult"
	ObbyPadResult.Parent = Remotes
end
-- remote: client asks for its current cooldown remaining (to seed the timer text on join)
local ObbyPadQuery = Remotes:FindFirstChild("ObbyPadQuery")
if not ObbyPadQuery then
	ObbyPadQuery = Instance.new("RemoteEvent")
	ObbyPadQuery.Name = "ObbyPadQuery"
	ObbyPadQuery.Parent = Remotes
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

	-- on cooldown?
	local remaining = remainingCooldown(player.UserId)
	if remaining > 0 then
		ObbyPadResult:FireClient(player, { kind = "cooldown", remaining = remaining })
		task.delay(1, function() busy[player.UserId] = nil end)
		return
	end

	-- eligible -> grant reward, stamp + persist the cooldown
	local now = os.time()
	lastClaim[player.UserId] = now
	pcall(function()
		cooldownStore:SetAsync("u_" .. player.UserId, now)
	end)

	coinSvc():Credit(player, REWARD_COINS, "obby winner pad")
	ObbyPadResult:FireClient(player, { kind = "reward", remaining = COOLDOWN, amount = REWARD_COINS })

	-- 2 seconds after the claim, teleport the player back to the lobby spawn — but ONLY if they're
	-- still a lobby player. If a round started during this window and placed them on the map, doing the
	-- teleport would strand them in the lobby for the whole round, so we skip it in that case.
	task.delay(2, function()
		if playerIsInRound(player) then return end  -- round started + they're in it: don't yank them back
		local char = player.Character
		if char and char.Parent and char:FindFirstChild("HumanoidRootPart") then
			char:PivotTo(getLobbyTarget())
		end
	end)

	task.delay(2, function() busy[player.UserId] = nil end)
end

pad.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorWhichIsA("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if player then
		tryClaim(player)
	end
end)

-- answer client cooldown queries (used to seed the timer text on join)
ObbyPadQuery.OnServerEvent:Connect(function(player)
	ObbyPadResult:FireClient(player, { kind = "cooldown", remaining = remainingCooldown(player.UserId) })
end)

-- clear cache when a player leaves
Players.PlayerRemoving:Connect(function(player)
	lastClaim[player.UserId] = nil
	busy[player.UserId] = nil
end)
