local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CrucifixCrab", -- This is the what you set the _fishId arttibute to!
	Name = "Crucifix Crab", -- The name of the fish that will show up in the book
	Aliases = { "Charybdis feriata" },
	Model = Assets["Crucifix Crab"],
	Icon = "",

	Family = "Portunidae",
	Diet = "Small Fish and Invertebrates",
	Size = "Shell Width 20 cm (7.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "5-118 m (16-387 ft)",

	Facts = {
		"This colorful crab gets its name from the cross-like pattern on its back! It is also alternatively known as the coral swimmer crab..",
		"Swimmer crabs are sometimes known to cling onto jellies, likely to use as protection and a food source!",
		"The genus of this species, Charybdis, is the name of the legendary Greek sea monster! ",
		"The patterning on this crab is quite variable, though almost all individuals display the distinct cross pattern.",
	},

	Skeleton =  {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.0000152587890625, -0.097320556640625, -0.24883544445037842),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.3173828125, -0.27613067626953125, -0.06614542007446289),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.317230224609375, -0.2761383056640625, -0.06614518165588379),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
			},
			["Position"] = Vector3.new(0.9468231201171875, -0.5755767822265625, -0.06583058834075928),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
				[2] = 7,
			},
			["Position"] = Vector3.new(-0.9563446044921875, -0.5755844116210938, -0.06584542989730835),
		},
		[6] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0.4693603515625, -0.9457855224609375, -0.06546378135681152),
		},
		[7] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(-0.4616546630859375, -0.9457778930664062, -0.06547105312347412),
		},
	} 
}