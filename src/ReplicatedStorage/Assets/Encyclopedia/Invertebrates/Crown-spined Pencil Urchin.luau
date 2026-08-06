local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CSPencilUrchin", -- This is the what you set the _fishId arttibute to!
	Name = "Crown-spined Pencil Urchin", -- The name of the fish that will show up in the book
	Aliases = { "Prionocidaris baculosa" },
	Model = Assets["Crown-spined Pencil Urchin"],
	Icon = "",

	Family = "Cidaridae",
	Diet = "Sessile Animals and Detritus",
	Size = "17 cm (7 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-250 m (3.3-820 ft)",

	Facts = {
		"Pencil urchins are notable for their very thick and often blunt spines compared to other urchins.",
		"This urchin is nocturnal, choosing to hide in crevices during the day to avoid predators.",
		"Urchins are surprisingly dexterous with their spines. Some will even pick up objects to move around!",
		"This species has appeared to gain a reputation as a bulldozer in home aquaria, destroying anything in its path!"
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