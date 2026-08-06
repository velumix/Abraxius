local GameModeConfig = {}


GameModeConfig.DEV_FORCE_MODE = nil -- "reverserace"

local modes = {
	{
		id = "hideandseek",
		displayName = "Paint & Seek",
		tagline = "Hiders blend in. Seekers hunt.",
		icon = "",
		color = Color3.fromRGB(90, 170, 255),
		minPlayers = 2,
		votable = true,
	},
	{
		id = "reverserace",
		displayName = "Reverse Race",
		tagline = "All hide. Then hunt one at a time.",
		icon = "",
		color = Color3.fromRGB(255, 140, 90),
		minPlayers = 3,
		votable = true,
	},
}

local byId = {}
for _, mode in ipairs(modes) do
	byId[mode.id] = mode
end

GameModeConfig.List = modes

function GameModeConfig.get(id)
	return byId[id]
end

function GameModeConfig.getVotable()
	local out = {}
	for _, mode in ipairs(modes) do
		if mode.votable then
			table.insert(out, mode)
		end
	end
	return out
end

function GameModeConfig.getDefault()
	return modes[1]
end

return GameModeConfig
