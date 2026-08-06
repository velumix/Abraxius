local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))

local ALL = "All"

local function options(): { string }
	local out = { ALL }
	for _, def in ipairs(KillEffectManager.EFFECTS) do
		table.insert(out, def.id)
	end
	return out
end

local killEffectTypeAll = {
	Transform = function(text: string)
		if string.lower(text) == string.lower(ALL) then
			return ALL
		end
		for _, def in ipairs(KillEffectManager.EFFECTS) do
			if string.lower(def.id) == string.lower(text) then
				return def.id
			end
		end
		return text
	end,

	Validate = function(value: string)
		return value == ALL or KillEffectManager.getEffect(value) ~= nil, `"{value}" is not a valid kill effect.`
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
	registry:RegisterType("killEffectTypeAll", killEffectTypeAll)
end
