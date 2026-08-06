local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Blanket Octopus Appearance",
	Identifier = "blanket_octopus",
	AssetName = "Indo-Pacific Blanket Octopus",
	ScanId = "BlanketOctopus",
	Rarity = "Legendary",
	Chance = 0.1,
	AnimationLoops = 1,
	PreservePosition = true,
	Messages = {
		Start = "An incredibly rare blanket octopus shimmers into view near the reef! This must be a dream!",
		Finish = "The blanket octopus slips back into the open ocean.",
		Failure = "The currents stay calm—no blanket octopus this time.",
	},
})

return EventDefinition:ToEvent()
