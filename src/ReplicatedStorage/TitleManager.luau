-- TitleManager: compatibility/helper layer over TitleDefinitions (the single source of truth).
-- Title definitions now live in ReplicatedStorage.TitleDefinitions; this exposes the lowercase-field
-- shape ({ id, name, rarity }) and helpers the rest of the game already uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleDefinitions = require(ReplicatedStorage:WaitForChild("TitleDefinitions"))

local TitleManager = {}

TitleManager.RARITY_COLORS = TitleDefinitions.RARITY_COLORS

-- Build the legacy list/lookup ({ id, name, rarity }) from TitleDefinitions.
TitleManager.TITLES = {}
TitleManager.TITLE_BY_ID = {}
for id, def in pairs(TitleDefinitions.Definitions) do
	local entry = { id = def.Id, name = def.Name, rarity = def.Rarity }
	TitleManager.TITLES[#TitleManager.TITLES + 1] = entry
	TitleManager.TITLE_BY_ID[id] = entry
end

function TitleManager.getTitle(id)
	return TitleManager.TITLE_BY_ID[id]
end

function TitleManager.titleName(id)
	return TitleDefinitions.name(id)
end

function TitleManager.titleColor(id)
	return TitleDefinitions.color(id)
end

return TitleManager
