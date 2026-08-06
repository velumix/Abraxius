local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "mangroveWhipray", -- This is the what you set the _fishId arttibute to!
	Name = "Mangrove Whipray", -- The name of the fish that will show up in the book
	Aliases = { "Urogymnus granulatus" },
	Model = Assets["Mangrove Whipray"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://122298879886897",

	Family = "Dasyatidae",
	Diet = "Benthic Fishes and Invertebrates",
	Size = "Wingspan 1.4 m (4.5 ft)",
	Depths = "1-85 m (3-278 ft)",
	
    Facts = {
		"Mangrove whiprays are distinguished by their long white tails and white spots.",
		"These rays are unfortunately considered vulnerable due to fishing and habitat loss.",
		"Juvenile mangrove whiprays will stay around coastal mangroves, while adults are known to go offshore.",
		"Mangrove whiprays are considered solitary, unlike some other stingray species."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.05873870849609375, -1.1920928955078125e-07, 0.7267990112304688),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.7458305358886719, -4.246830940246582e-07, 0.18662261962890625),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.6883773803710938, 3.129243850708008e-07, 0.1787109375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
				[3] = 5,
			},
			["Position"] = Vector3.new(0.053638458251953125, 2.2351741790771484e-08, -0.7005462646484375),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0.0589447021484375, 1.4156103134155273e-07, -2.15802001953125),
		},
	}
}