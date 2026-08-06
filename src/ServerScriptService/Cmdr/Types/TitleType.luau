local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TitleDefinitions = require(ReplicatedStorage:WaitForChild("TitleDefinitions"))

local titleType = {
	Transform = function(text: string)
		for _, id in ipairs(TitleDefinitions.ids()) do
			if string.lower(id) == string.lower(text) then
				return id
			end
		end
		return text
	end,

	Validate = function(value: string)
		return TitleDefinitions.get(value) ~= nil, `"{value}" is not a valid title.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, id in ipairs(TitleDefinitions.ids()) do
			if string.sub(string.lower(id), 1, #value) == string.lower(value) then
				table.insert(matches, id)
			end
		end
		return matches
	end,

	Parse = function(value: string)
		return value
	end,
}

return function(registry)
	registry:RegisterType("titleType", titleType)
end
