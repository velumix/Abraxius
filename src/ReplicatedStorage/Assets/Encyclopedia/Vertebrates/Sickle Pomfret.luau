local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SicklePomfret", -- This is the what you set the _fishId arttibute to!
	Name = "Sickle Pomfret",
	Aliases = { "Taractichthys steindachneri" },
	Model = Assets["Sickle Pomfret"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Bramidae",
	Diet = "Fish and Squid",
	Size = "60 cm (23 in)",
	Depths = "50-700 m (164- 2296 ft)",

	Facts = {
		"Species in the pomfret family almost exclusively live in the high seas. Very little footage of them alive in their habitat exists.",
		"Sickle pomfret are a prized food fish, as are many other species in the family.",
		"The perferred habitat of the sickle pomfret is deeper waters of the continental shelf, as well as seamounts.",
		"Several unrelated fish are also called pomfrets,. The true pomfrets are those in the family Bramidae.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -1.6319656372070312, 0.029123902320861816),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0, -0.34638214111328125, 0.029123902320861816),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
				[3] = 7,
			},
			["Position"] = Vector3.new(0, 1.10498046875, -0.03720223903656006),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.13295745849609375, -1.322263240814209),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.426910400390625, 1.3924394845962524),
		},
		[6] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 1.8680953979492188, -0.5870757102966309),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 1.8128433227539062, 0.7015596628189087),
		},
	}
}
	
	