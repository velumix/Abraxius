local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "poisonGoby", -- This is the what you set the _fishId arttibute to!
	Name = "Poison Goby", -- The name of the fish that will show up in the book
	Aliases = { "Gobiodon citrinus" },
	Model = Assets["Posion Goby"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Gobiidae",
	Diet = "Plankton",
	Size = "6 cm (2.3 in)",
	Depths = "0-20 m (0-65 ft)",
	
    Facts = {
		"Poison gobies live on branching corals entire lives, usually living in a pair. Often, this means they live on a single coral colony.",
		"These fish get their name from the toxic mucus that they can produce.",
		"These fish are one of several fish that can breath air! They will do this if their coral home is exposed during low tide."
	},
	
	Skeleton =  {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0000152587890625, -0.09754180908203125, 0.00995248556137085),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0.0000152587890625, 0.01080322265625, -0.0000649280846118927),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
				[3] = 6,
				[4] = 7,
			},
			["Position"] = Vector3.new(0.0000152587890625, 0.11313629150390625, -0.004657834768295288),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0000152587890625, 0.02100372314453125, -0.08572012931108475),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.13483428955078125, -0.08509450405836105),
		},
		[6] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.15126800537109375, 0.06834788620471954),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.0000762939453125, 0.27457427978515625, -0.004657842218875885),
		},
	} 
}