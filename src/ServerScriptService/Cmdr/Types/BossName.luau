local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossConfig = require(ReplicatedStorage.Config.BossConfig)

local function getNames(): { string }
	return BossConfig.GetNames()
end

local bossNameType = {
	Transform = function(text: string)
		local lower = text:lower()
		for _, name in ipairs(getNames()) do
			if name:lower() == lower then
				return name
			end
		end
		return text
	end,

	Validate = function(value: string)
		return BossConfig.Get(value) ~= nil, `"{value}" is not a valid boss.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		local lower = value:lower()
		for _, name in ipairs(getNames()) do
			if name:lower():sub(1, #lower) == lower then
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
	registry:RegisterType("bossName", bossNameType)
end
