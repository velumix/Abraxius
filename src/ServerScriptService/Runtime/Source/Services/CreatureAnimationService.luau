local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packets = require(ReplicatedStorage.Modules.CreatureAnimationPackets)

local CREATURE_TAG = "ServerCreatures"

local CreatureAnimationService = {
	Name = "CreatureAnimationService",
	Creatures = {},
	ReadyPlayers = {},
}

local function getAnimation(creature)
	local animation = creature:FindFirstChild("Animation", true)
	if not animation or not animation:IsA("Animation") then
		return nil
	end

	local animationId = animation.AnimationId
	if animationId == "" or animationId == "0" or animationId == "rbxassetid://0" then
		return nil
	end

	return animation
end

local function isManagedWorldCreature(creature)
	return creature:IsDescendantOf(Workspace)
end

local function getSpeed(creature, animation)
	local speed = creature:GetAttribute("AnimationSpeed") or animation:GetAttribute("Speed") or 1
	if typeof(speed) ~= "number" or speed ~= speed or speed <= 0 or speed == math.huge then
		return 1
	end
	return speed
end

function CreatureAnimationService:_entry(creature, data)
	return {
		creature = creature,
		startedAt = data.StartedAt,
		speed = data.Speed,
	}
end

function CreatureAnimationService:_sendSnapshot(player)
	local snapshot = {}
	for creature, data in self.Creatures do
		if creature.Parent then
			table.insert(snapshot, self:_entry(creature, data))
		end
	end

	Packets.Sync.sendTo(snapshot, player)
end

function CreatureAnimationService:Register(creature)
	if self.Creatures[creature] or not creature:IsA("Model") or not isManagedWorldCreature(creature) then
		return
	end

	local animation = getAnimation(creature)
	if not animation then
		return
	end

	local data = {
		StartedAt = Workspace:GetServerTimeNow(),
		Speed = getSpeed(creature, animation),
	}
	self.Creatures[creature] = data

	local readyPlayers = {}
	for player in self.ReadyPlayers do
		if player.Parent == Players then
			table.insert(readyPlayers, player)
		else
			self.ReadyPlayers[player] = nil
		end
	end

	if #readyPlayers > 0 then
		Packets.Sync.sendToList({ self:_entry(creature, data) }, readyPlayers)
	end
end

function CreatureAnimationService:Unregister(creature)
	self.Creatures[creature] = nil
end

function CreatureAnimationService:Setup()
	Packets.Ready.listen(function(_, player)
		if not player or player.Parent ~= Players then
			return
		end

		self.ReadyPlayers[player] = true
		self:_sendSnapshot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.ReadyPlayers[player] = nil
	end)

	for _, creature in CollectionService:GetTagged(CREATURE_TAG) do
		self:Register(creature)
	end

	CollectionService:GetInstanceAddedSignal(CREATURE_TAG):Connect(function(creature)
		self:Register(creature)
	end)
	CollectionService:GetInstanceRemovedSignal(CREATURE_TAG):Connect(function(creature)
		self:Unregister(creature)
	end)
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") and CollectionService:HasTag(instance, CREATURE_TAG) then
			self:Register(instance)
		end
	end)
end

return CreatureAnimationService
