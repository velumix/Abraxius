local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packets = require(ReplicatedStorage.Modules.BoidPackets)

local TARGET_UPDATE_INTERVAL = 1 / 5

local BoidHybridService = {
	Name = "BoidHybridService",
	MovingNodes = {},
	ReadyPlayers = {},
	Accumulator = 0,
}

function BoidHybridService:RegisterNode(node)
	if not node:IsA("BasePart") or not node:GetAttribute("Moves") then
		return
	end

	local goal = node:GetAttribute("Goal")
	local duration = node:GetAttribute("TimeToMove")
	if typeof(goal) ~= "Vector3" or typeof(duration) ~= "number" or duration <= 0 then
		return
	end

	self.MovingNodes[node] = {
		Origin = node.Position,
		Goal = goal,
		Duration = duration,
		StartedAt = os.clock(),
	}
end

function BoidHybridService:UnregisterNode(node)
	self.MovingNodes[node] = nil
end

function BoidHybridService:GetTarget(data, now)
	local duration = data.Duration
	local phase = (now - data.StartedAt) % (duration * 2)
	local alpha = if phase <= duration then phase / duration else 2 - phase / duration
	return data.Origin:Lerp(data.Goal, alpha)
end

function BoidHybridService:Update(delta)
	self.Accumulator += delta
	if self.Accumulator < TARGET_UPDATE_INTERVAL then
		return
	end
	self.Accumulator %= TARGET_UPDATE_INTERVAL

	local readyPlayers = {}
	for player in self.ReadyPlayers do
		if player.Parent == Players then
			table.insert(readyPlayers, player)
		else
			self.ReadyPlayers[player] = nil
		end
	end
	if #readyPlayers == 0 then
		return
	end

	local now = os.clock()
	local updates = {}
	for node, data in self.MovingNodes do
		if node.Parent then
			table.insert(updates, {
				node = node,
				target = self:GetTarget(data, now),
			})
		else
			self.MovingNodes[node] = nil
		end
	end

	if #updates > 0 then
		Packets.TargetBatch.sendToList(updates, readyPlayers)
	end
end

function BoidHybridService:Setup()
	Packets.Ready.listen(function(_, player)
		if player and player.Parent == Players then
			self.ReadyPlayers[player] = true
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.ReadyPlayers[player] = nil
	end)

	for _, node in CollectionService:GetTagged("Boid") do
		self:RegisterNode(node)
	end

	CollectionService:GetInstanceAddedSignal("Boid"):Connect(function(node)
		self:RegisterNode(node)
	end)
	CollectionService:GetInstanceRemovedSignal("Boid"):Connect(function(node)
		self:UnregisterNode(node)
	end)
	RunService.Heartbeat:Connect(function(delta)
		self:Update(delta)
	end)
end

return BoidHybridService
