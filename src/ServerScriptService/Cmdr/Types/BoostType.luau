local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoostConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BoostConfig"))

local SUGGESTIONS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }

local boostType = {
	Transform = function(text: string)
		return string.match(text, "^%s*(.-)%s*$") or text
	end,

	Validate = function(value: string)
		local multiplier = tonumber(value)
		return BoostConfig.parseMultiplier(multiplier) ~= nil, "Multiplier must be a positive whole number."
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, suggestion in SUGGESTIONS do
			if string.sub(suggestion, 1, #value) == value then
				table.insert(matches, suggestion)
			end
		end
		return matches
	end,

	Parse = function(value: string)
		return BoostConfig.parseMultiplier(tonumber(value))
	end,
}

return function(registry)
	registry:RegisterType("boostType", boostType)
end