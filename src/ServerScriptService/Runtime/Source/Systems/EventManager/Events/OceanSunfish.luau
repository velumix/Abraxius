local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Ocean Sunfish Appearance",
	Identifier = "ocean_sunfish",
	AssetName = "Ocean Sunfish",
	ScanId = "oceanSunfish",
	Rarity = "Epic",
	Chance = 0.56,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "A massive ocean sunfish drifts into view near the observatory!",
		Finish = "The ocean sunfish slowly disappears into the depths.",
		Failure = "The waters remain calm—no sunfish sighting this time.",
	},
})

return EventDefinition:ToEvent()