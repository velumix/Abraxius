local OPTIONS = { "local", "global" }

local scopeType = {
	Transform = function(text: string)
		return string.lower(text)
	end,

	Validate = function(value: string)
		return value == "local" or value == "global", `"{value}" must be local or global.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, name in OPTIONS do
			if string.sub(name, 1, #value) == string.lower(value) then
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
	registry:RegisterType("scope", scopeType)
end