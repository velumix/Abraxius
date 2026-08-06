local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Mahi-Mahi Appearance",
	Identifier = "mahi_mahi",
	AssetName = "Mahi-Mahi",
	ScanId = "Mahi",
	Rarity = "Rare",
	Chance = 0.70,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "A dazzling diplay! A shoal of mahi-mahi has appeared!",
		Finish = "The mahi-mahi make their exit.",
		Failure = "No gold here, the mahi have not appeared.",
	},
})

return EventDefinition:ToEvent()
