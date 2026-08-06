local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Modules.RealismPackets)

local MAX_UPDATES_PER_SECOND = 30
local MIN_UPDATE_INTERVAL = 1 / MAX_UPDATES_PER_SECOND
local MAX_ABS_ANGLE = 1

local RealismService = {
	Name = "RealismService",
	LastUpdates = {},
}

local function finiteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function RealismService:OnLookInput(data, player)
	if not player or not player:IsDescendantOf(Players) or typeof(data) ~= "table" then
		return
	end

	local pitch = data.pitch
	local yaw = data.yaw
	if not finiteNumber(pitch) or not finiteNumber(yaw) then
		return
	end

	local now = os.clock()
	local lastUpdate = self.LastUpdates[player]
	if lastUpdate and now - lastUpdate < MIN_UPDATE_INTERVAL then
		return
	end
	self.LastUpdates[player] = now

	Packets.LookBroadcast.sendToAllExcept({
		player = player,
		pitch = math.clamp(pitch, -MAX_ABS_ANGLE, MAX_ABS_ANGLE),
		yaw = math.clamp(yaw, -MAX_ABS_ANGLE, MAX_ABS_ANGLE),
	}, player)
end

function RealismService:Setup()
	Packets.LookInput.listen(function(data, player)
		self:OnLookInput(data, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.LastUpdates[player] = nil
	end)
end

return RealismService
