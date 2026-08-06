local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Snotty Lions Mane Appearance",
	Identifier = "lions_mane",
	AssetName = "Snotty Lions Mane Jelly",
	ScanId = "SnottyJelly",
	Rarity = "Rare",
	Chance = 0.65,
	AnimationLoops = 1,
	PreservePosition = true,
	Messages = {
		Start = "A snotty lions mane has been spotted on the fringes of the reef! Sick!",
		Finish = "The snotty lions mane leaves, its ailments cured.",
		Failure = "No afflictions, no snotty.",
	},
})

return EventDefinition:ToEvent()