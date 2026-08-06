local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SapphireFlatworm", -- This is the what you set the _fishId arttibute to!
	Name = "Sapphire Flatworm", -- The name of the fish that will show up in the book
	Aliases = { "Pseudoceros caeruleocinctus" },
	Model = Assets["Sapphire Flatworm"],
	Icon = "",

	Family = "Pseudocerotidae",
	Diet = "Sponges",
	Size = "5 cm (1.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-30 m (3.3-98 ft)",

	Facts = {
		"Marine flatworms are notable for their intense variety of colors and patterns!",
		"Flatworms are in one of 12 animal groups commonly referred to as worms. Despite this, none of these groups are closely related!",
		"The small ear-like folds on the head of marine flatworms are called pseudotentacles, and are used to detect their surroundings."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.00000762939453125, -0.10565948486328125, 0.0029996298253536224),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.03957366943359375, 0.0027481280267238617),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.13344573974609375, -0.04764422029256821),
		},
	}
}