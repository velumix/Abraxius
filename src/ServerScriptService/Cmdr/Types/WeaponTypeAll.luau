local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))

local ALL = "All"

local function options(): { string }
	local out = { ALL }
	for _, skin in ipairs(KnifeSkinManager.SKINS) do
		table.insert(out, skin.id)
	end
	return out
end

local weaponTypeAll = {
	Transform = function(text: string)
		if string.lower(text) == string.lower(ALL) then
			return ALL
		end
		for _, skin in ipairs(KnifeSkinManager.SKINS) do
			if string.lower(skin.id) == string.lower(text) then
				return skin.id
			end
		end
		return text
	end,

	Validate = function(value: string)
		return value == ALL or KnifeSkinManager.getSkin(value) ~= nil, `"{value}" is not a valid knife.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, name in options() do
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
	registry:RegisterType("weaponTypeAll", weaponTypeAll)
end
