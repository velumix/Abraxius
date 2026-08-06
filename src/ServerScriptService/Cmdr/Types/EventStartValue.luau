local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostConfig = require(ReplicatedStorage.Config.BoostConfig)
local CmdrEventScope = require(ReplicatedStorage.Util.CmdrEventScope)

local MULTIPLIERS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
local DURATIONS = { "1", "5", "10", "15", "30", "60" }

local function isMultiplierEvent(): boolean
	return CmdrEventScope.lastEvent == "BoostLuck"
		or CmdrEventScope.lastEvent == BoostConfig.EventName
		or CmdrEventScope.lastEvent == "SpeedBoost"
end

local eventStartValue = {
	Transform = function(text: string)
		return string.match(text, "^%s*(.-)%s*$") or text
	end,

	Validate = function(value: string)
		local number = tonumber(value)
		if isMultiplierEvent() then
			return BoostConfig.parseMultiplier(number) ~= nil, "Multiplier must be a positive whole number."
		end
		return number ~= nil and number > 0, "Duration must be a positive number of minutes."
	end,

	Autocomplete = function(value: string)
		local matches = {}
		local suggestions = if isMultiplierEvent() then MULTIPLIERS else DURATIONS
		for _, suggestion in suggestions do
			if string.sub(suggestion, 1, #value) == value then
				table.insert(matches, suggestion)
			end
		end
		return matches
	end,

	Parse = function(value: string)
		return tonumber(value)
	end,
}

return function(registry)
	registry:RegisterType("eventStartValue", eventStartValue)
end