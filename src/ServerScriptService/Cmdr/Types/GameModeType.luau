local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameModeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModeConfig"))

local function ids()
	local out = {}
	for _, mode in ipairs(GameModeConfig.List) do
		table.insert(out, mode.id)
	end
	return out
end

local gameModeType = {
	Transform = function(text: string)
		return string.lower(text)
	end,

	Validate = function(value: string)
		return GameModeConfig.get(value) ~= nil, `"{value}" is not a valid game mode.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, id in ipairs(ids()) do
			if string.sub(id, 1, #value) == value then
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
	registry:RegisterType("gameModeType", gameModeType)
end
