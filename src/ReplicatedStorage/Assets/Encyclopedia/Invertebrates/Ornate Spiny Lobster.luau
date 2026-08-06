local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "OrnateSpinyLobster", -- This is the what you set the _fishId arttibute to!
	Name = "Ornate Spiny Lobster", -- The name of the fish that will show up in the book
	Aliases = { "Panulirus ornatus" },
	Model = Assets["Ornate Spiny Lobster"],
	Icon = "",

	Family = "Palinuridae",
	Diet = "Invertebrates",
	Size = "50 cm (19.6 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-50 m (3.3-164 ft)",

	Facts = {
		"This stunning species is one of the larger spiny lobsters in its range.",
		"Spiny lobsters undergo long breeding migrations. This particular species travels from Australia north to New Guinea.",
		"Larval spiny lobsters are flattened and transparent, and are called phyllosoma.",
		"This species is a very popular food item due to its large size and abundance."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
				[3] = 8,
			},
			["Position"] = Vector3.new(-0.02327728271484375, -0.8631973266601562, -0.1621417999267578),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.00196075439453125, 0.07568359375, 0.09345054626464844),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0.024139404296875, 0.8971405029296875, 0.24269962310791016),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.5198593139648438, 1.1331329345703125, 0.26086902618408203),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.36782073974609375, 1.1723175048828125, 0.26088523864746094),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
				[2] = 7,
			},
			["Position"] = Vector3.new(0.44014739990234375, -1.0146865844726562, -0.17138671875),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(1.7184524536132812, 0.8059844970703125, -0.14568042755126953),
		},
		[8] = {
			["Links"] = {
				[1] = 1,
				[2] = 9,
			},
			["Position"] = Vector3.new(-0.47956085205078125, -0.9688949584960938, -0.1710062026977539),
		},
		[9] = {
			["Links"] = {
				[1] = 8,
			},
			["Position"] = Vector3.new(-1.796478271484375, 1.0980224609375, -0.013917982578277588),
		},
	}

}