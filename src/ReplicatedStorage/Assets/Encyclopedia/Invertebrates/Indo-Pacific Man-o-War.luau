local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "IPMOW", -- This is the what you set the _fishId arttibute to!
	Name = "Indo-Pacific Man-o-War", -- The name of the fish that will show up in the book
	Aliases = { "Physalia utriculus" },
	Model = Assets["Indo-Pacific Man-o-War"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://97521164186617",

	Family = "Physaliidae",
    Diet = "Small Fish and Plankton",
	Size = "Tentacles up to 30 m (90 ft)",
	Depths = "Surface",
	
	Facts = {
		"Man-o-war are siphonophores. These animals are made up of a colony of individual, genetically identical animals, called zooids.",
		"Each individual zooid has a separate job for the colony. Some catch food, some digest, and some help the colony float!",
		"There are four species of man-o-war, distingushed by the shape of the floating zooid and where they are found.",
		"These animals are very venomous. They are notible for stinging long after washing up on shore. Watch out for them!",
		"There are several animals that use man-o-war as food or shelter. These include the blue dragon slug and bluebottlefish.",
		"Man-o-war are also called bluebottles, particularly in Australia!",
		"Despite being capable of reaching great lengths, the tentacle zooids are usually tightly curled. This makes them seem shorter.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.6131362915039062, -0.279876708984375, 0.12749481201171875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.0070343017578125, -0.558074951171875, 0.05515289306640625),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.6035690307617188, -0.25548553466796875, -0.017425537109375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.00769805908203125, 0.0053253173828125, 0.05370330810546875),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0.060882568359375, 2.084320068359375, 0.048553466796875),
		},
	}
}