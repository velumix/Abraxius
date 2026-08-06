local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "YellowtailCoris", -- This is the what you set the _fishId arttibute to!
	Name = "Yellowtail Coris", -- The name of the fish that will show up in the book
	Aliases = { "Allocoris gaimard" },
	Model = Assets["Yellowtail Coris"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://124420986605773",

	Family = "Labridae",
	Diet = "Benthic Invertebrates",
	Size = "40 cm (15.8 in)",
	Depths = "1-50 m (3-164 ft)",

	Facts = {
		"Juveniles of this species do not look like adults. They are a bright orange with white saddles outlined by black.",
		"Many wrasse, including yellowtail, are known to manipulate their environment in search of prey items by flipping rocks.",
		"As with other wrasse, yellowtails can change from female to male when large enough. Their appearance also changes."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.7022018432617188, -0.0037384033203125, -0.07277357578277588),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.40423583984375, -0.00363922119140625, 0.13316117227077484),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.0900726318359375, -0.00727081298828125, -0.19603270292282104),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.24175262451171875, -0.001251220703125, 0.15302270650863647),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(-0.543365478515625, -0.00437164306640625, -0.1357230842113495),
		},
	}
}