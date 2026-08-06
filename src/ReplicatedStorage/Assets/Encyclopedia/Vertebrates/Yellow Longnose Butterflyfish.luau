local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "ForcepsFish", -- This is the what you set the _fishId arttibute to!
	Name = "Yellow Longnose Butterflyfish", -- The name of the fish that will show up in the book
	Aliases = { "Forcipiger flavissimus" },
	Model = Assets["Yellow Longnose Butterflyfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Chaetodontidae",
	Diet = "Small Benthic Invertebrates",
	Size = "22 cm (8.6 in)",
	Depths = "1-145 m (3-475 ft)",

    Facts = {
		"Longnose butterflyfish are known to produce sounds to warn other fish to stay out of their territories!",
		"These fish are monogomous, and have been known to stay with the same partner for up to seven years.",
		"These fish are also known as forcepsfish due to their narrow snouts. Their scientific name even translates to forceps!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.09355983138084412, -0.5074462890625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.09355992078781128, -0.01146697998046875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.3283698856830597, 0.2712554931640625),
		},
	}
}