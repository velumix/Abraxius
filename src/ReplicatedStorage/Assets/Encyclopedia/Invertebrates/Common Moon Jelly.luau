local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "MoonJellyfish", -- This is the what you set the _fishId arttibute to!
	Name = "Common Moon Jelly", -- The name of the fish that will show up in the book
	Aliases = { "Aurelia aurita" },
	Model = Assets["MoonJelly"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://92278830605278",

	Family = "Ulmaridae",
    Diet = "Zooplankton",
	Size = "38 cm (1.2 ft)",
	Depths = "0-1250 m (0-4101 ft)",
	
	Facts = {
		"Moon jellies have very short tentacles they use to capture food. Their stings do not affect humans.",
		"Jellies start life as a sedentary polyp, and metamorphize into their adult, free swimming form called a medusa.",
		"Jellies lack a respiratory or cardiovascular system. They do have a nervous system, but lack a brain.",
		"There are many moon jelly species, and all look very similar. It can take genetic testing to confirm species ID."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.440757155418396, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.12725293636322021, -0.6367416381835938),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.6500167846679688, 0.12725293636322021, 0.03733062744140625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.6663284301757812, 0.12725293636322021, 0.02086639404296875),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 0.12725287675857544, 0.7016372680664062),
		},
	}
}