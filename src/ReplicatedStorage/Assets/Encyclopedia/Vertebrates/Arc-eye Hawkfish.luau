local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "AEHawkfish", -- This is the what you set the _fishId arttibute to!
	Name = "Arc-eye Hawkfish", -- The name of the fish that will show up in the book
	Aliases = { "Paracirrhites arcatus" },
	Model = Assets["Arc-eye Hawkfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Cirrhitidae",
	Diet = "Crustaceans",
	Size = "20 cm (7.8 in)",
	Depths = "0-91 m (0-298 ft)",
	
    Facts = {
		"This hawkfish is one of many fish that specialize in living on corals, though this fish uses many different coral species as refuge.",
		"This fish shows both light and dark color morphs, and they can be seen on the same coral colony together!",
		"The arc-eye hawkfish is a solitary fish, typically keeping to itself until it is time to reproduce.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.000030517578125, -0.5390090942382812, 0.024654775857925415),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 5,
			},
			["Position"] = Vector3.new(-0.0000152587890625, -0.2252655029296875, -0.01074594259262085),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 6,
				[4] = 7,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.05329132080078125, -0.01074586808681488),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.0001373291015625, 0.49968719482421875, -0.004199817776679993),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0000152587890625, -0.1346435546875, -0.21549735963344574),
		},
		[6] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.0001373291015625, 0.13143157958984375, -0.18348418176174164),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.0001373291015625, 0.22440338134765625, 0.13593816757202148),
		},
	}
}