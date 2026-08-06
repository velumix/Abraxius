local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Yellow Tang", -- This is the what you set the _fishId arttibute to!
	Name = "Yellow Tang",
	Aliases = { "Zebrasoma flavescens" },
	Model = Assets["Yellow Tang"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://100977543685073",

	Family = "Acanthuridae",
	Diet = "Herbivore",
	Size = "Up to 20 cm (8 in)",
	Depths ="2-46 m (6 - 150 ft)",

	Facts = {
		"The yellow tang is one of the most popular marine aquarium fish.",
		"The yellow tang is native to the Pacific Ocean, living in shallow reefs and lagoons.",
		"Yellow tangs are herbivores, feeding on algae and seaweed.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.05869758129119873, -0.4062042236328125),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.1961444616317749, -0.056854248046875),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.26225951313972473, -0.06037139892578125),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, -0.056030988693237305, 0.32183074951171875),
		},
	}
}