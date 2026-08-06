local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GiantMudCrab", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Mud Crab", -- The name of the fish that will show up in the book
	Aliases = { "Scylla serrata" },
	Model = Assets["Giant Mud Crab"],
	Icon = "rbxassetid://100710804275465",

	Family = "Portunidae",
	Diet = "Small Fish and Invertebrates",
	Size = "Shell Width 28 cm (11 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-50 m (0-164 ft)",

	Facts = {
		"These crabs are known by many common names, including Indo-Pacific swamp crab, mangrove crab, and simply mud crab.",
		"Mud crabs are found in shallow waters across the Indo-Pacific. They have been introduced to Hawaii.",
		"Mud crabs are a type of swimmer crab. They use their modified last pair of legs as flippers to freely swim!",
		"These crabs are a very popular food item across their range, and are a target for many recreational fishermen.",
		"Newly hatched larval crabs are called zoea, and look nothing like adults. They have a long tail and head spine!"
	},
	
	Skeleton = 
		{
			[1] = {
				["Links"] = {
					[1] = 2,
					[2] = 4,
				},
				["Position"] = Vector3.new(0, 0, 0),
			},
			[2] = {
				["Links"] = {
					[1] = 1,
					[2] = 3,
				},
				["Position"] = Vector3.new(1, -0.24999988079071045, -0.5),
			},
			[3] = {
				["Links"] = {
					[1] = 2,
				},
				["Position"] = Vector3.new(0.25, -0.2499997615814209, -0.75),
			},
			[4] = {
				["Links"] = {
					[1] = 1,
					[2] = 5,
				},
				["Position"] = Vector3.new(-1, -0.24999988079071045, -0.5),
			},
			[5] = {
				["Links"] = {
					[1] = 4,
				},
				["Position"] = Vector3.new(-0.25, -0.2499997615814209, -0.75),
			},
		}

}