local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Sea Wasp Appearance",
	Identifier = "box_jelly",
	AssetName = "Sea Wasp",
	ScanId = "SeaWasp",
	Rarity = "Rare",
	Chance = 0.68,
	AnimationLoops = 1,
	PreservePosition = true,
	Messages = {
		Start = "A massive sea wasp has been spotted in observatory waters! Stay on your guard!",
		Finish = "The coast is clear, the sea wasp drifts back into the blue.",
		Failure = "The waters remain safe, no sea wasp appears.",
	},
})

return EventDefinition:ToEvent()