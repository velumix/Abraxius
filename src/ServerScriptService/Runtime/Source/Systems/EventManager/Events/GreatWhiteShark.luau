local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Great White Shark Appearance",
	Identifier = "great_white_shark",
	AssetName = "Great White Shark",
	ScanId = "GWhiteShark",
	Rarity = "Legendary",
	Chance = 0.2,
	AnimationLoops = 1,
	PreservePosition = true,
	Messages = {
		Start = "A mighty great white shark has appeared in observatory waters!",
		Finish = "The great white continues its hunt elsewhere.",
		Failure = "The legend of the seas is a no show today, no great white shark appears.",
	},
})

return EventDefinition:ToEvent()