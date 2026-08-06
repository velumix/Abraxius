local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PillowCushionStar", -- This is the what you set the _fishId arttibute to!
	Name = "Pillow Cushion Star", -- The name of the fish that will show up in the book
	Aliases = { "Culcita novaeguineae" },
	Model = Assets["Pillow Cushion Star"],
	Icon = "",

	Family = "Oreasteridae",
	Diet = "Encrusting Organisms",
	Size = "30 cm (11.8 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-20 m (3.3-65.6 ft)",

	Facts = {
		"This chunky sea star becomes more pillow shaped as they grow. Juveniles are slightly more star-shaped.",
		"Some species of shrimp will commensally live on the underside of these sea stars.",
		"Cushion stars are highly variable in color and pattern!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
				[5] = 6,
			},
			["Position"] = Vector3.new(0, 0, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-1.25, 0, 0.25),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0, 1.25),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(1.25, 0, 0.25),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.75, 0, -1.25),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.75, 0, -1.25),
		},
	}

}