local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Wahoo Appearance",
	Identifier = "wahoo",
	AssetName = "Wahoo",
	ScanId = "wahoo",
	Rarity = "Rare",
	Chance = 0.60,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "Wahoo! Check the open seas!",
		Finish = "The party is over. Wahoo is gone.",
		Failure = "No travelling creature has been spotted. We will keep watch!",
	},
})

return EventDefinition:ToEvent()
