local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Leatherback Turtle Appearance",
	Identifier = "leatherback_turtle",
	AssetName = "Leatherback Sea Turtle",
	ScanId = "LeatherbackSeaTurtle",
	Rarity = "Epic",
	Chance = 0.42,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "A leatherback sea turtle glides slowly but steadily by the observatory!",
		Finish = "The leatherback turtle returns to the open ocean.",
		Failure = "No turtle sighting just yet—keep watching the swells.",
	},
})

return EventDefinition:ToEvent()
