local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "TexCone", -- This is the what you set the _fishId arttibute to!
	Name = "Textile Cone", -- The name of the fish that will show up in the book
	Aliases = { "Conus textile" },
	Model = Assets["Textile Cone"],
	Icon = "",

	Family = "Conidae",
	Diet = "Fish",
	Size = "Shell 16 cm (5.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-50 m (3.3-164 ft)",

	Facts = {
		"Cone snails are the most venomous snails in the world, with up to 30 known fatalities being caused by their stings.",
		"This snail is an ambush hunter, using a harpoon-like appendage to catch fish off guard!",
		"There are over 600 cone snail species! Some specialize on invertebrate prey, and are less venomous than the fish eating ones.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 8,
			},
			["Position"] = Vector3.new(0.0394287109375, -0.34897613525390625, 0.0759158730506897),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.1268310546875, -0.2124786376953125, 0.0032994747161865234),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.108978271484375, -0.09393310546875, -0.12018156051635742),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.0120391845703125, 0.0219879150390625, -0.20725584030151367),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(-0.1581268310546875, 0.14788055419921875, -0.20724725723266602),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(-0.2433624267578125, 0.22379302978515625, -0.10460317134857178),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(-0.186492919921875, 0.28371429443359375, 0.041880011558532715),
		},
		[8] = {
			["Links"] = {
				[1] = 1,
				[2] = 9,
			},
			["Position"] = Vector3.new(-0.005523681640625, -0.37679290771484375, -0.0005682706832885742),
		},
		[9] = {
			["Links"] = {
				[1] = 8,
			},
			["Position"] = Vector3.new(-0.0055084228515625, -0.45868682861328125, -0.026721835136413574),
		},
	}
}