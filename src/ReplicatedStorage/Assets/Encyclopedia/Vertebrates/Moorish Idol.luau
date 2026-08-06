local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "moorishIdol", -- This is the what you set the _fishId arttibute to!
	Name = "Moorish Idol", -- The name of the fish that will show up in the book
	Aliases = { "Zanclus cornutus" },
	Model = Assets["Moorish Idol"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://119605764477922",
	
	Family = "Zanclidae",
	Diet = "Sponges",
	Size = "23 cm (9 in)",
    Depths = "3-182 m (10-597 ft)",
	
    Facts = {
		"The Moorish idol has a wide distribution, being found in tropical reefs across the Indian and Pacific Oceans.",
		"The Moorish idol is the only living member of its family.",
		"Moorish idols are rarely seen in captivity, as they are very delicate and often do not survive in aquariums."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.0928243100643158, -0.7237701416015625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 0.32711148262023926, -0.2228546142578125),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.37260037660598755, -0.1976165771484375),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.4538581371307373, 0.5189895629882812),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.030918926000595093, 0.2168121337890625),
		},
	}

}