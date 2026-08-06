local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "LochsChromodoris", -- This is the what you set the _fishId arttibute to!
	Name = "Loch's Chromodoris", -- The name of the fish that will show up in the book
	Aliases = { "Chromodoris lochi" },
	Model = Assets["Loch's Chromodoris"],
	Icon = "",

	Family = "Chromodorididae",
	Diet = "Sponges",
	Size = "4 cm (1.5 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-25 m (3.3-80 ft)",

	Facts = {
		"There are currently over 60 accepted species of chromodoris, but this number often changes as new discoveries are made.",
		"The name Chromodoris comes from the Greek word chroma, meaning color, and Doris, likely referring to a Greek sea nymph.",
		"This species of sea slug can have either yellow or pink gills!",
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