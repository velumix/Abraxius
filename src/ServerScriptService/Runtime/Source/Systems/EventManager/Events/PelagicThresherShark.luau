local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Pelagic Thresher Shark Appearance",
	Identifier = "pelagic_thresher_shark",
	AssetName = "Pelagic Thresher Shark",
	ScanId = "pelagicthreshershark",
	Rarity = "Legendary",
	Chance = 0.21,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "A pelagic thresher shark glides through the observatory waters! This is no tall tale!",
		Finish = "The thresher shark vanishes into the open ocean.",
		Failure = "The deep waters stay quiet—no thresher shark appears.",
	},
})

return EventDefinition:ToEvent()