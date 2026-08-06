local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModeConfig"))
local GameModeRegistry = require(script.Parent:WaitForChild("GameModeRegistry"))

local GameModeVoteManager = {}

local Remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "GameRemotes"
	Remotes.Parent = ReplicatedStorage
end

local ModeVoteState = Remotes:FindFirstChild("ModeVoteState")
if not ModeVoteState then
	ModeVoteState = Instance.new("RemoteEvent")
	ModeVoteState.Name = "ModeVoteState"
	ModeVoteState.Parent = Remotes
end

local ModeVoteCast = Remotes:FindFirstChild("ModeVoteCast")
if not ModeVoteCast then
	ModeVoteCast = Instance.new("RemoteEvent")
	ModeVoteCast.Name = "ModeVoteCast"
	ModeVoteCast.Parent = Remotes
end

local candidates = {}
local votes = {}
local playerVote = {}
local voteWeight = {}
local voteOpen = false

local weightProvider = function()
	return 1
end

function GameModeVoteManager.setWeightProvider(fn)
	if type(fn) == "function" then
		weightProvider = fn
	end
end

local function weightFor(plr)
	local ok, w = pcall(weightProvider, plr)
	if ok and type(w) == "number" and w > 0 then
		return w
	end
	return 1
end

local function isCandidate(modeId)
	for _, id in ipairs(candidates) do
		if id == modeId then
			return true
		end
	end
	return false
end

local function buildState(plr)
	local options = {}
	for i, id in ipairs(candidates) do
		local cfg = GameModeConfig.get(id)
		options[i] = {
			id = id,
			name = cfg and cfg.displayName or id,
			tagline = cfg and cfg.tagline or "",
			icon = cfg and cfg.icon or "",
			votes = votes[id] or 0,
		}
	end
	return { open = voteOpen, options = options, myVote = playerVote[plr] }
end

local function broadcastState()
	for _, plr in ipairs(Players:GetPlayers()) do
		ModeVoteState:FireClient(plr, buildState(plr))
	end
end

local function castVote(plr, modeId)
	if not voteOpen then
		return false
	end
	if not isCandidate(modeId) then
		return false
	end
	local prev = playerVote[plr]
	if prev == modeId then
		return false
	end
	if prev and votes[prev] then
		votes[prev] = math.max(0, votes[prev] - (voteWeight[plr] or 1))
	end
	local w = weightFor(plr)
	votes[modeId] = (votes[modeId] or 0) + w
	playerVote[plr] = modeId
	voteWeight[plr] = w
	return true
end

ModeVoteCast.OnServerEvent:Connect(function(plr, modeId)
	if type(modeId) ~= "string" then
		return
	end
	if castVote(plr, modeId) then
		local parts = {}
		for _, id in ipairs(candidates) do
			table.insert(parts, id .. "=" .. tostring(votes[id] or 0))
		end
		print(("[GameModeVoteManager] %s voted '%s' | tally: %s"):format(plr.Name, modeId, table.concat(parts, ", ")))
		broadcastState()
	else
		print(("[GameModeVoteManager] %s vote for '%s' REJECTED (open=%s, isCandidate=%s)"):format(plr.Name, modeId, tostring(voteOpen), tostring(isCandidate(modeId))))
	end
end)

function GameModeVoteManager.canVote()
	return #GameModeRegistry.getVotableIds() >= 2
end

function GameModeVoteManager.isOpen()
	return voteOpen
end

function GameModeVoteManager.openVote()
	candidates = GameModeRegistry.getVotableIds()
	votes = {}
	playerVote = {}
	voteWeight = {}
	for _, id in ipairs(candidates) do
		votes[id] = 0
	end
	voteOpen = true
	broadcastState()
	print("[GameModeVoteManager] vote opened: " .. table.concat(candidates, ", "))
end

GameModeVoteManager.openNextVote = GameModeVoteManager.openVote

function GameModeVoteManager.resolveVote()
	if #candidates == 0 then
		return nil
	end
	local best = -1
	for _, id in ipairs(candidates) do
		if (votes[id] or 0) > best then
			best = votes[id] or 0
		end
	end
	local tied = {}
	for _, id in ipairs(candidates) do
		if (votes[id] or 0) == best then
			table.insert(tied, id)
		end
	end
	local winner = tied[math.random(1, #tied)]
	print(string.format("[GameModeVoteManager] vote resolved: %s (%d votes)", tostring(winner), best))
	return winner
end

function GameModeVoteManager.cancelVote()
	voteOpen = false
	candidates = {}
	votes = {}
	playerVote = {}
	voteWeight = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		ModeVoteState:FireClient(plr, { open = false, options = {} })
	end
end

Players.PlayerRemoving:Connect(function(plr)
	local prev = playerVote[plr]
	if prev and votes[prev] then
		votes[prev] = math.max(0, votes[prev] - (voteWeight[plr] or 1))
		if voteOpen then
			broadcastState()
		end
	end
	playerVote[plr] = nil
	voteWeight[plr] = nil
end)

Players.PlayerAdded:Connect(function(plr)
	task.spawn(function()
		task.wait(1)
		ModeVoteState:FireClient(plr, buildState(plr))
	end)
end)

return GameModeVoteManager
