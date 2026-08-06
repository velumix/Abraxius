-- KnifeTutorialManager: gates the interactive FIRST-KNIFE-UNBOX tutorial so it runs exactly once per
-- player, ever. The client asks (KnifeTutorialQuery) whether this player has already done it; we reply
-- (KnifeTutorialState) with true/false from the consolidated ProfileStore flag. When the client finishes
-- the walkthrough it tells us (KnifeTutorialDone) and we persist the flag so it never runs again.
--
-- Mirrors HiderTutorialManager exactly, but with its OWN separate flag so the two once-per-player
-- tutorials are tracked independently.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local DataService = require(ServerScriptService.Services.DataService)
local FLAG_NAME = "KnifeTutorialSeen"
local legacySeenStore = DataStoreService:GetDataStore("KnifeTutorialSeen_v1")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")

local function ensureRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Remotes
	end
	return r
end
local KnifeTutorialQuery = ensureRemote("KnifeTutorialQuery")  -- client -> server: am I eligible?
local KnifeTutorialState = ensureRemote("KnifeTutorialState")  -- server -> client: true=already seen
local KnifeTutorialDone  = ensureRemote("KnifeTutorialDone")   -- client -> server: mark it seen

local seenCache = {}  -- [userId] = bool

local function hasSeen(player)
	local cached = seenCache[player.UserId]
	if cached ~= nil then return cached end
	local data = DataService:WaitForData(player)
	local seen = data ~= nil and DataService:GetFlag(player, FLAG_NAME) == true
	if data ~= nil and not seen then
		local ok, legacySeen = pcall(function()
			return legacySeenStore:GetAsync("u_" .. player.UserId)
		end)
		if ok and legacySeen == true then
			seen = true
			DataService:SetFlag(player, FLAG_NAME, true)
			pcall(function()
				DataService:Save(player)
			end)
		end
	end
	seenCache[player.UserId] = seen
	return seen
end

local function markSeen(player)
	seenCache[player.UserId] = true
	if DataService:WaitForData(player) then
		DataService:SetFlag(player, FLAG_NAME, true)
		pcall(function()
			DataService:Save(player)
		end)
	end
end

KnifeTutorialQuery.OnServerEvent:Connect(function(player)
	KnifeTutorialState:FireClient(player, hasSeen(player))
end)

KnifeTutorialDone.OnServerEvent:Connect(function(player)
	markSeen(player)
end)

-- pre-warm the cache on join so the first query answers instantly
Players.PlayerAdded:Connect(function(player)
	task.spawn(hasSeen, player)
end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(hasSeen, p) end
Players.PlayerRemoving:Connect(function(player)
	seenCache[player.UserId] = nil
end)
