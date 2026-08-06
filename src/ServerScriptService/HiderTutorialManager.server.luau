-- HiderTutorialManager: gates the interactive FIRST-HIDER tutorial so it runs exactly once per
-- player, ever. The client asks (HiderTutorialQuery) whether this player has already done it; we
-- reply (HiderTutorialState) with true/false from the consolidated ProfileStore flag. When the client
-- finishes the walkthrough it tells us (HiderTutorialDone) and we persist the flag so it never runs again.
--
-- This is intentionally a separate flag from the join-time TutorialManager (TutorialSeen_v1): that one
-- is the "welcome" slideshow shown on first join; THIS one is the hands-on paint/pose walkthrough shown
-- the first time a player is actually assigned the Hider role.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local DataService = require(ServerScriptService.Services.DataService)
local FLAG_NAME = "HiderTutorialSeen"
local legacySeenStore = DataStoreService:GetDataStore("HiderTutorialSeen_v1")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")

-- client -> server: "have I done the hider tutorial?" (fire-and-wait via the reply remote)
local function ensureRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Remotes
	end
	return r
end
local HiderTutorialQuery = ensureRemote("HiderTutorialQuery")  -- client -> server: am I eligible?
local HiderTutorialState = ensureRemote("HiderTutorialState")  -- server -> client: true=already seen
local HiderTutorialDone  = ensureRemote("HiderTutorialDone")   -- client -> server: mark it seen

-- in-memory cache so repeated queries in one session don't re-read the profile, and so a player
-- who finishes the tutorial is immediately treated as "seen" for the rest of the session.
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

-- The client asks once, the first time it sees the player assigned Hider. We reply with whether the
-- tutorial has already been seen; the client only runs the walkthrough when this is false.
HiderTutorialQuery.OnServerEvent:Connect(function(player)
	HiderTutorialState:FireClient(player, hasSeen(player))
end)

-- The client finished (or skipped) the walkthrough; persist so it never runs again.
HiderTutorialDone.OnServerEvent:Connect(function(player)
	markSeen(player)
end)

-- pre-warm the cache on join (off the main thread) so the first query answers instantly
Players.PlayerAdded:Connect(function(player)
	task.spawn(hasSeen, player)
end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(hasSeen, p) end
Players.PlayerRemoving:Connect(function(player)
	seenCache[player.UserId] = nil
end)
