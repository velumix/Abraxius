local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SchoolingBannerfish", -- This is the what you set the _fishId arttibute to!
	Name = "Schooling Bannerfish", -- The name of the fish that will show up in the book
	Aliases = { "Heniochus diphreutes" },
	Model = Assets["Schooling Bannerfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://100095298609310",
	
	Family = "Chaetodontidae",
	Diet = "Plankton",
	Size = "21 cm (8.2 in)",
	Depths = "5-210 m (16-689 ft)",

    Facts = {
		"Despite resembling the Moorish idol, the bannerfish is unrelated and is a species of butterflyfish.",
		"As its name suggests, the schooling bannerfish is often seen forming very large schools.",
		"Juvenile schooling bannerfish are known to act as cleaners for larger fish, removing and eating parasites."
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