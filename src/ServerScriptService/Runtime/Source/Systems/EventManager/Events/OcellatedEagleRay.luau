local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Ocellated Eagle Ray Appearance",
	Identifier = "ocellated_eagle_ray",
	AssetName = "Ocellated Eagle Ray",
	ScanId = "ocellatedEagle",
	Rarity = "Epic",
	Chance = 0.44,
	AnimationLoops = 1,
	PreservePosition = true,
	Messages = {
		Start = "An ocellated eagle ray visits from the aquamarine waters of a nearby atoll!",
		Finish = "The eagle ray moves on with its migration.",
		Failure = "No eagle ray spotted this time, the migration has not begun.",
	},
})

return EventDefinition:ToEvent()