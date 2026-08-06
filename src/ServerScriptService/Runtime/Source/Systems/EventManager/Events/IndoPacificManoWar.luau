local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Indo-Pacific Man-o-war Appearance",
	Identifier = "pacific_man_o_war",
	AssetName = "Indo-Pacific Man-o-War",
	ScanId = "IPMOW",
	Rarity = "Rare",
	Chance = 0.70,
	AnimationLoops = 1,
	PreservePosition = true,
	Messages = {
		Start = "Ahoy! The winds have blown a man-o-war to the observatory!",
		Finish = "The winds have shifted and the man-o-war drifts off.",
		Failure = "The winds remain calm, no man-o-war sighted.",
	},
})

return EventDefinition:ToEvent()