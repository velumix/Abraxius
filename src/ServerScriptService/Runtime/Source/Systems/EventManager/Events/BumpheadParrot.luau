local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local CreatureEventService = Mince:Get("CreatureEventService")

local EventDefinition = CreatureEventService:CreateDefinition({
	Name = "Green Bumphead Parrotfish Appearance",
	Identifier = "bumphead_parrot",
	AssetName = "Green Bumphead Parrotfish",
	ScanId = "GreenBumpParrot",
	Rarity = "Epic",
	Chance = 0.5,
	AnimationLoops = 2,
	PreservePosition = true,
	Messages = {
		Start = "Here comes the reef renovators! A school of green bumphead parrotfish has been spotted!",
		Finish = "Their work here is done, the bumphead parrotfish have left.",
		Failure = "No parrotfish spotted, the reef remains unchanged.",
	},
})

return EventDefinition:ToEvent()