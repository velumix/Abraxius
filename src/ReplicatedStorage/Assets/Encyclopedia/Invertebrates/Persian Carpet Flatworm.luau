local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PCFlatworm", -- This is the what you set the _fishId arttibute to!
	Name = "Persian Carpet Flatworm", -- The name of the fish that will show up in the book
	Aliases = { "Pseudoceros bedfordi" },
	Model = Assets["Persian Carpet Flatworm"],
	Icon = "",

	Family = "Pseudocerotidae",
	Diet = "Tunicates",
	Size = "10 cm (4 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-30 m (3.3-98 ft)",

	Facts = {
		"Marine flatworms have an interesting way of breeding. They engage in a type of fencing battle, and the loser carries the eggs!",
		"These flatworms are nocturnal carnivores, emerging from cracks to feed on ascidians (sea squirts) and other small invertebrates.",
		"While they may look similar at first glance, flatworms are not related to nudibranches at all!",
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