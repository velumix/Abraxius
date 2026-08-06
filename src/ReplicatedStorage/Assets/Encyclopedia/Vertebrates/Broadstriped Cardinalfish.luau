local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BroadStripeCardinal", -- This is the what you set the _fishId arttibute to!
	Name = "Broadstriped Cardinalfish", -- The name of the fish that will show up in the book
	Aliases = { "Ostorhinchus angustatus" },
	Model = Assets["Broadstriped Cardinalfish"],
	Icon = "rbxassetid://90130620212266",

	Family = "Apogonidae",
	Diet = "Benthic Invertebrates",
	Size = "11 cm (4.3 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "6-65 m (19.7-210.2 ft)",

	Facts = {
		"Cardinalfish are nocturnal and are often seen in pairs or small groups under ledges during the day.",
		"Male cardinalfish raise their eggs in thier mouths, known as mouthbrooding! They do not feed during this time.",
		"Despite thier name, not all cardinalfish species are red. The name stuck because the first described ones were!"
	},

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.011052794754505157, -0.243804931640625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.01105278730392456, -0.05837249755859375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.011052772402763367, 0.20162200927734375),
		},
	}
}