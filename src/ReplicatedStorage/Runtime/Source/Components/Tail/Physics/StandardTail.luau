local BaseTail = require(script.Parent.BaseTail)

local StandardTail = setmetatable({}, {__index = BaseTail})
StandardTail.__index = StandardTail

local STIFFNESS = 0.5
local ROOT_BEND = 0.4

function StandardTail.new(tailController)
	local self = setmetatable(BaseTail.new(tailController), StandardTail)
	self.LastVelocity = Vector3.zero
	return self
end

function StandardTail:Calculate(dt, speed, velocity, angularVelocity)
	local rootPart = self.Tail.RootPart
	if not rootPart then return { Pitch = 0, Roll = 0 } end

	local localAngular = rootPart.CFrame:VectorToObjectSpace(angularVelocity)
	local localVelocity = -rootPart.CFrame:VectorToObjectSpace(velocity)

	local turnAmount = localAngular.Y * 0.4

	self.SmoothedTurn = self:SmoothValue(self.SmoothedTurn, turnAmount, 120, dt)

	local pitchAmount = -localVelocity.Y * 0.02

	self.SmoothedPitch = self:SmoothValue(self.SmoothedPitch, pitchAmount, 240, dt)

	local influenceStrength = math.clamp(speed / 3, 0, 1)

	return {
		Pitch = self.SmoothedPitch * influenceStrength * STIFFNESS,
		Roll = self.SmoothedTurn * influenceStrength * STIFFNESS,
		RootBend = ROOT_BEND
	}
end

return StandardTail
