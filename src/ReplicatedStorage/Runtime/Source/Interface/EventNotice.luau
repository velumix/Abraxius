local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Notices = Mince:Get("Notices")

local DEFAULT_COLOR = Color3.fromRGB(255, 223, 152)

local EventNotice = {
	Name = "CreatureEventNoticeInterface",
	DefaultDuration = 6,
	DefaultColor = DEFAULT_COLOR,
}

local function resolveDuration(fallback, duration)
	if typeof(duration) ~= "number" or duration <= 0 then
		return fallback
	end
	return duration
end

local function resolveColor(fallback, color)
	if typeof(color) == "Color3" then
		return color
	end
	return fallback
end

function EventNotice:Setup()

end

return EventNotice
