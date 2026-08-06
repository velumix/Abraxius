local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Notices = Mince:Get("Notices")
local Event = Mince:GetEvent("CreatureEventNotice")

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
	Event.Event:Connect(function(text, duration, sound, color)
		print("Client received", text, duration, sound, color)

		if typeof(text) ~= "string" or text == "" then
			return
		end

		local noticeApi = Notices
		if not noticeApi or not noticeApi.CreateNotice then
			warn("Notices module unavailable; cannot show creature event notice")
			return
		end

		local ok, err = pcall(function()
			noticeApi:CreateNotice(text, resolveColor(self.DefaultColor, color), resolveDuration(self.DefaultDuration, duration), sound)
		end)

		if not ok then
			warn("Failed to display creature event notice:", err)
		end
	end)
end

return EventNotice
