local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Rough-toothed Dolphin Appearance",
	Identifier = "rough_toothed_dolphin",
	AssetName = "Rough-toothed Dolphin",
	ScanId = "RTDolphin",
	Rarity = "Epic",
	Chance = 0.34,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "A playful pod of rough-toothed dolphins has appeared!",
		Finish = "Playtime is over as the dolphins move on.",
		Failure = "No darn mammoids. This is not mammiferous. (No dolphins).",
	},
})

return EventDefinition:ToEvent()