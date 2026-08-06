local OPTIONS = { "Hider", "Hunter", "Off" }

local soloRoleType = {
	Transform = function(text: string)
		if string.lower(text) == "seeker" then
			return "Hunter"  -- accept "seeker" as an alias for the hunter role
		end
		for _, name in OPTIONS do
			if string.lower(name) == string.lower(text) then
				return name
			end
		end
		return text
	end,

	Validate = function(value: string)
		return value == "Hider" or value == "Hunter" or value == "Off", `"{value}" must be Hider, Hunter, or Off.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, name in OPTIONS do
			if string.sub(string.lower(name), 1, #value) == string.lower(value) then
				table.insert(matches, name)
			end
		end
		return matches
	end,

	Parse = function(value: string)
		return value
	end,
}

return function(registry)
	registry:RegisterType("soloRoleType", soloRoleType)
end
