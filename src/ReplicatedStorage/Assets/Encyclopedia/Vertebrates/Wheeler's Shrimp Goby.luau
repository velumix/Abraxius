local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "WheelersGoby", -- This is the what you set the _fishId arttibute to!
	Name = "Wheeler's Shrimp Goby",
	Aliases = { "Amblyeleotris wheeleri" },
	Model = Assets["Wheeler's Shrimp Goby"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Gobiidae",
	Diet = "Small Invertebrates",
	Size = "10 cm (4 in)",
	Depths = "5-40 m (16- 131 ft)",

	Facts = {
		"While many shrimp are used, this species of goby is commonly found in association with the fine-lined pistol shrimp.",
		"Another common name for this fish is the gorgeous prawn goby!",
		"There is a very similar shrimp goby species, the red-banded shrimpgoby, but Wheeler's has thicker bands that help identify it.",
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