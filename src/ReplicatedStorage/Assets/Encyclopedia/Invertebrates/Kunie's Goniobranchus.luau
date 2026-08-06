local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "KunieGoniobranchus", -- This is the what you set the _fishId arttibute to!
	Name = "Kunie's Goniobranchus", -- The name of the fish that will show up in the book
	Aliases = { "Goniobranchus kuniei" },
	Model = Assets["Kunie's Goniobranchus"],
	Icon = "",

	Family = "Chromodorididae",
	Diet = "Sponges",
	Size = "5 cm (1.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-40 m (3.3-131 ft)",

	Facts = {
		"Goniobranchus species come in a wide varierty of colors and patterns. Some even lack patterns, being mostly white.",
		"This species of sea slug is very similar to two other species. This is common in sea slugs, and takes a careful eye to identify them.",
		"The flower-like structure at the back of these animals are their gills!",
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