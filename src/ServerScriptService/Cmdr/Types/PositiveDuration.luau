local DURATIONS = { "1", "5", "10", "15", "30", "60" }

local positiveDuration = {
	Transform = function(text: string)
		return string.match(text, "^%s*(.-)%s*$") or text
	end,

	Validate = function(value: string)
		local minutes = tonumber(value)
		return minutes ~= nil and minutes > 0, "Duration must be a positive number of minutes."
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, suggestion in DURATIONS do
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
	registry:RegisterType("positiveDuration", positiveDuration)
end