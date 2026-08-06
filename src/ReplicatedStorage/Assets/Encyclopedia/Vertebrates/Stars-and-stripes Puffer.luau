local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SassPuffer", -- This is the what you set the _fishId arttibute to!
	Name = "Stars-and-Stripes Puffer", -- The name of the fish that will show up in the book
	Aliases = { "Arothron hispidus" },
	Model = Assets["Stars-and-stripes Puffer"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Tetraodontidae",
	Diet = "Invertebrates",
	Size = "48 cm (18.9 in)",
    Depths = "1-50 m (3.1-164 ft)",
	
    Facts = {
		"Pufferfish are known by many common names, such as blowfish, toadfish, and toado.",
		"The deadly toxins found in the organs of pufferfish is thought to come from their diet!",
		"This pufferfish gets this patriotic name from its stripes and spots that can be used to identify it!",
	},
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -5.960464477539063e-08, -1.291107177734375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -1.1920928955078125e-07, -0.291107177734375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
				[4] = 6,
			},
			["Position"] = Vector3.new(0, -1.1920928955078125e-07, 0.708892822265625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, -1.7881393432617188e-07, 1.2089004516601562),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.4110952615737915, 0.708892822265625),
		},
		[6] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, -0.4469405710697174, 0.708892822265625),
		},
	}
}