local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "RandallsShrimpGoby", -- This is the what you set the _fishId arttibute to!
	Name = "Randall's Shrimp-Goby", -- The name of the fish that will show up in the book
	Aliases = { "Amblyeleotris randalli" },
	Model = Assets["Randall's Shrimp Goby"],
	Icon = "rbxassetid://93104560474694",

	Family = "Gobiidae",
	Diet = "Small Invertebrates",
	Size = "9 cm (3.5 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "25-50 m (82-164 ft)",

	Facts = {
		"Many goby species form symbiotic relationships with pistol shrimp. The goby acts as a lookout.",
		"Shrimp gobies communicate with their partner shrimp using sharp movements, such as a tail flick.",
		"There are over 100 species of gobies that are known to have relationships with shrimp.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.005889892578125, -0.2860527038574219, 0.015037432312965393),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0.00116729736328125, -0.12440299987792969, -0.0013376325368881226),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.00139617919921875, -0.13968467712402344, -0.15223035216331482),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0057830810546875, 0.11413955688476562, 0.00390683114528656),
		},
	}
}