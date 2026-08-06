local BaseTail = {}
BaseTail.__index = BaseTail

function BaseTail.new(tailController)
	local self = setmetatable({}, BaseTail)
	self.Tail = tailController
	self.SmoothedTurn = 0
	self.SmoothedPitch = 0
	self.SmoothedRoll = 0
	return self
end

function BaseTail:SmoothValue(current, target, speed, dt)
	local alpha = 1 - math.exp(-speed * dt)
	return current + (target - current) * alpha
end

function BaseTail:Calculate(dt, speed, velocity, angularVelocity, isSwimming)
	return { Pitch = 0, Yaw = 0, Roll = 0 }
end

return BaseTail
