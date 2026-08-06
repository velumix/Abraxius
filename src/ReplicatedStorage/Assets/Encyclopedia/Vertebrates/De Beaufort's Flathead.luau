local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "crocFish", -- This is the what you set the _fishId arttibute to!
	Name = "De Beaufort's Flathead", -- The name of the fish that will show up in the book
	Aliases = { "Cymbacephalus beauforti" },
	Model = Assets["Crocodilefish"],
	Icon = "rbxassetid://133212128548702",

	Family = "Platycephalidae",
	Diet = "Fish and Crustaceans",
	Size = "50 cm (19.7 in)",
	Depths = "1-12 m (3.3-39 ft)",

	Facts = {
		"This fish is also known as the crocodilefish. This refers to its slightly crocodilian appearance.",
		"Flatheads are in the same order as scorpionfish and lionfish. They are venomous like many of this group, but the venom is mild.",
		"One of the most striking features of this fish is the lappet that covers the eye, breaking up its outline to help improve camouflage.",
		"The family name of this fish, Platycephalidae, directly translates to flat head!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.0070343017578125, -1.055145263671875, 0.011313825845718384),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.1546630859375, -0.6030731201171875, 0.019696563482284546),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.171539306640625, -0.6052474975585938, 0.019654422998428345),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
				[3] = 5,
			},
			["Position"] = Vector3.new(0.0070343017578125, -0.166168212890625, 0.027952462434768677),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0.0070343017578125, 0.43729400634765625, 0.03913572430610657),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0.0070343017578125, 1.19903564453125, 0.05325418710708618),
		},
	}
}