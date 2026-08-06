local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CrownofThorns", -- This is the what you set the _fishId arttibute to!
	Name = "Crown-of-Thorns Starfish", -- The name of the fish that will show up in the book
	Aliases = { "Acanthaster planci" },
	Model = Assets["Crown-of-Thorns Starfish"],
	Icon = "rbxassetid://114173854481918",

	Family = "Acanthasteridae",
	Diet = "Stony Coral",
	Size = "80 cm (31.5 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-65 m (3.3-213 ft)",

	Facts = {
		"Crown-of-thorns can have up to 21 arms per individual, each armed with many venomous spines.",
		"These sea stars are native to the Great Barrier Reef, but overpopulation outbreaks make them a threat to the corals there.",
		"Each adult crown-of-thorns can consume up to 10 square meters (32 sq ft) of coral a year.",
		"The reason for outbreaks in the Great Barrier Reef are debated, but lack of predators is one possible reason."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0, 0, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.75, 0.0000016838312149047852, 0),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.7500076293945312, -0.0000016689300537109375, 0),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.0000011175870895385742, -0.7500076293945312),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, -0.0000011026859283447266, 0.75),
		},
	}
}