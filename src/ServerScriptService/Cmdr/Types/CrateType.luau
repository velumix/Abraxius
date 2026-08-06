local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))

local function names(): { string }
	local out = {}
	for name in KnifeSkinManager.CRATES do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

local crateType = {
	Transform = function(text: string)
		for _, name in names() do
			if string.lower(name) == string.lower(text) then
				return name
			end
		end
		return text
	end,

	Validate = function(value: string)
		return KnifeSkinManager.CRATES[value] ~= nil, `"{value}" is not a valid crate.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, name in names() do
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
	registry:RegisterType("crateType", crateType)
end
