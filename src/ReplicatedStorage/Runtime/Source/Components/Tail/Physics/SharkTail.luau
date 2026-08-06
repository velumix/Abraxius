local BaseTail = require(script.Parent.BaseTail)

local SharkTail = setmetatable({}, {__index = BaseTail})
SharkTail.__index = SharkTail

local STIFFNESS = 0.3
local ROOT_BEND = 0.3

function SharkTail.new(tailController)
	local self = setmetatable(BaseTail.new(tailController), SharkTail)
	self.LastVelocity = Vector3.zero
	return self
end

function SharkTail:Calculate(dt, speed, velocity, angularVelocity, isSwimming)
	local rootPart = self.Tail.RootPart
	if not rootPart then return { Pitch = 0, Roll = 0 } end

	local localAngular = -rootPart.CFrame:VectorToObjectSpace(angularVelocity)
	local localVelocity = rootPart.CFrame:VectorToObjectSpace(velocity)

	local turnAmount = localAngular.Y * 0.4

	self.SmoothedTurn = self:SmoothValue(self.SmoothedTurn, turnAmount, 72, dt)

	local pitchAmount = -localVelocity.Y * 0.02

	self.SmoothedPitch = self:SmoothValue(self.SmoothedPitch, pitchAmount, 144, dt)

	local influenceStrength = math.clamp(speed / 3, 0, 1)

	return {
		Pitch = self.SmoothedPitch * influenceStrength * STIFFNESS,
		Roll = self.SmoothedTurn * influenceStrength * STIFFNESS,
		RootBend = ROOT_BEND
	}
end

return SharkTail
