local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Striped Marlin Appearance",
	Identifier = "striped_marlin",
	AssetName = "Striped Marlin",
	ScanId = "stripedMarlin",
	Rarity = "Rare",
	Chance = 0.48,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "A striped marlin streaks through the observatory waters!",
		Finish = "The striped marlin vanishes into the blue.",
		Failure = "The marlin shoals stay empty for now.",
	},
})

return EventDefinition:ToEvent()
