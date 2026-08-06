-- ReplicatedStorage.TitleDefinitions
-- Canonical definitions for nametag Titles (mirrors Knockout's TitleDefinitions).
-- Each title: { Id, Name, Rarity }. Rarity drives the nametag color via RARITY_COLORS.
-- TitleManager re-exports these for the rest of the game; PlayerTitleService reads them directly.

local TitleDefinitions = {}

TitleDefinitions.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 190),
	Uncommon = Color3.fromRGB(90, 200, 110),
	Rare = Color3.fromRGB(70, 130, 240),
	Epic = Color3.fromRGB(180, 90, 230),
	Legendary = Color3.fromRGB(255, 190, 60),
	Secret = Color3.fromRGB(0, 0, 0),
	Exclusive = Color3.fromRGB(64, 224, 208),
}

-- Keyed by the title id used in player data (lowercase). All Common for now (placeholder rarities).
TitleDefinitions.Definitions = {
	islander = { Id = "islander", Name = "Islander", Rarity = "Legendary" },
	student  = { Id = "student",  Name = "Student",  Rarity = "Legendary" },
	patriot  = { Id = "patriot",  Name = "Patriot",  Rarity = "Legendary" },
}

function TitleDefinitions.get(id)
	if id == nil then
		return nil
	end
	return TitleDefinitions.Definitions[id]
end

function TitleDefinitions.name(id)
	local def = TitleDefinitions.get(id)
	return def and def.Name or tostring(id)
end

function TitleDefinitions.rarity(id)
	local def = TitleDefinitions.get(id)
	return def and def.Rarity or "Common"
end

function TitleDefinitions.color(id)
	local def = TitleDefinitions.get(id)
	local rarity = def and def.Rarity
	return (rarity and TitleDefinitions.RARITY_COLORS[rarity]) or Color3.fromRGB(255, 255, 255)
end

function TitleDefinitions.ids()
	local list = {}
	for id in pairs(TitleDefinitions.Definitions) do
		list[#list + 1] = id
	end
	table.sort(list)
	return list
end

return TitleDefinitions
