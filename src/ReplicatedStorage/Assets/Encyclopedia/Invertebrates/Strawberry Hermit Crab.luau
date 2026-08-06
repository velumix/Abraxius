local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "strawberryHermitCrab", -- This is the what you set the _fishId arttibute to!
	Name = "Strawberry Hermit Crab", -- The name of the fish that will show up in the book
	Aliases = { "Coenobita perlatus" },
	Model = Assets["Strawberry Hermit Crab"],
	Icon = "rbxassetid://103543933956344",

	Family = "Coenobitidae",
	Diet = "Detritus and Invertebrates",
	Size = "8 cm (3.1 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "Shoreline",

	Facts = {
		"This species is one of many terrestrial hermit crabs. They are closely related to the largest terrestrial arthropod, the coconut crab!",
		"Despite being terrestrial, these crustaceans have a planktonic aquatic larval stage. They return to the sea to lay their eggs.",
		"Hermit crabs are not true crabs, and are in a different order entirely. However, the two groups did share a common ancestor.",
		"Hermit crabs use discarded snail shells to protect themselves. This individual is using one from a snail of the Turbo genus.",
		"Hermit crabs need to switch shells as they grow, which exposes their soft body. They have long tails and reduced back legs!",
		"These crustaceans are very good at climbing trees. It is not uncommon to see one in the branches of their native habitat!",
		"Despite being common in pet stores, hermit crabs are unfortunately difficult to breed in captivity and are almost all wild caught."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, -0.11359405517578125, -0.019411087036132812),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.12981414794921875, 0.022184371948242188),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.21791839599609375, -0.09717559814453125, -0.11540794372558594),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.161865234375, -0.0971832275390625, -0.11540985107421875),
		},
	}

}