local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "IPCTW", -- This is the what you set the _fishId arttibute to!
	Name = "Indo-Pacific Christmas Tree Worm", -- The name of the fish that will show up in the book
	Aliases = { "Spirobranchus corniculatus" },
	Model = Assets["Indo-Pacific Christmas Tree Worm"],
	Icon = "",

	Family = "Serpulidae",
	Diet = "Plankton",
	Size = "4 cm (1.5 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-30 m (3.3-98 ft)",

	Facts = {
		"The visible feather-like crowns of these worms come in a huge variey of colors and patterns, even within the same species!",
		"The crowns of these worms are specialized parts used for feeding and breathing, while the body of the animal resides in a tube!",
		"When disturbed, these worms will retreat into their tubes. They stop things from getting in with a sort of plug, called an operculum!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.0001220703125, -0.001590728759765625, -0.004950046539306641),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.0395050048828125, -0.000885009765625, 0.04367375373840332),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.03228759765625, -0.002895355224609375, 0.05092263221740723),
		},
	}
}