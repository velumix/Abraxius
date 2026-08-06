local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PennantCoralfish", -- This is the what you set the _fishId arttibute to!
	Name = "Pennant Coralfish", -- The name of the fish that will show up in the book
	Aliases = { "Heniochus acuminatus" },
	Model = Assets["Pennant Coralfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Chaetodontidae",
	Diet = "Plankton",
	Size = "25 cm (9.8 in)",
	Depths = "5-75 m (16-246 ft)",

    Facts = {
		"These fish are near identical to the very closely related schooling bannerfish, with the main difference being the length of the snout.",
		"These fish are also known as reef or longfin bannerfish. They are one of 8 bannerfish species.",
		"Pennant coralfish feed on small invertebrates. Much like the schooling bannerfish, juveniles will also clean other fish."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.14239996671676636, -0.5339431762695312),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.28286850452423096, -0.24083709716796875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.5644079446792603, 0.5499801635742188),
		},
	}

}