local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BlanketOctopus", -- This is the what you set the _fishId arttibute to!
	Name = "Indo-Pacific Blanket Octopus", -- The name of the fish that will show up in the book
	Aliases = { "Tremoctopus gracilis" },
	Model = Assets["Indo-Pacific Blanket Octopus"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Tremoctopodidae",
    Diet = "Fish, Molluscs and Crustaceans",
	Size = "2 m (6.5 ft)",
    Depths = "0-150 m (0-492 ft)",
	
    Facts = {
		"The web seen in female blanket octopus is used as a defense mechanism to look bigger. It can be rolled up when not in use.",
		" Blanket octopus are immune to the venom of the man o' war. Small ones even use the stinging tentacles as defense!",
		"Male blanket octopus are 40,000 times smaller than females. This is one of the largest differences in any animal!",
		"Female blanket octopus are incredibly rarely seen due to their deeper open ocean habitat and nomadic nature.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -5.733642578125, -4.76837158203125e-07),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 5,
				[5] = 6,
			},
			["Position"] = Vector3.new(-0.05841064453125, -3.29638671875, -6.556510925292969e-07),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(4.76715087890625, -0.20819091796875, -2.384185791015625e-07),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(1.1916046142578125, 4.70361328125, -5.960464477539063e-08),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-1.30841064453125, 5.45361328125, 0),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-4.55841064453125, -0.29638671875, -5.364418029785156e-07),
		},
	}

}