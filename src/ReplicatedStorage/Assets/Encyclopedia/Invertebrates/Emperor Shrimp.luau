local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "EmperorShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Emperor Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Zenopontonia rex" },
	Model = Assets["Emperor Shrimp"],
	Icon = "rbxassetid://93909781624765",

	Family = "Palaemonidae",
	Diet = "Detritus",
	Size = "2 cm (0.7 in)",
	Depths = "1-40 m (3.3-131.2 ft)",

	Facts = {
		"Emperor shrimp live their lives on larger invertebrates! They do not harm the other creature, but also do not benefit them.",
		"These shrimp have chromatophores, and sometimes change color based on the species they live on.",
		"The symbiotic relationship that these shrimp have with their host species is called commensalism."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, -0.02581024169921875, 0.0012054443359375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.0794677734375, -0.003711223602294922),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.03162384033203125, -0.051483154296875, 0.002403736114501953),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.04911041259765625, -0.0578460693359375, 0.0027008056640625),
		},
	}

}