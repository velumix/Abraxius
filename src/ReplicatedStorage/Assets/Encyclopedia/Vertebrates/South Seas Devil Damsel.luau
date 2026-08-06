local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "TheDevil", -- This is the what you set the _fishId arttibute to!
	Name = "South Seas Devil Damsel",
	Aliases = { "Chrysiptera taupou" },
	Model = Assets["South Seas Devil Damsel"], -- ReplicatedStorage -> Assets -> FishModels
	Icon = "rbxassetid://90518191875305",

	Family = "Pomacentridae",
	Diet = "Plankton and Algae",
	Size = "8 cm (3.1 in)",
	Depths = "0-15 m (0-32.8 ft)",

	Facts = {
		"These striking blue fish get therir name from their incredibly territorial and agressive behavior in home aquaria!",
		"During the breeding season, the male devil damsel guards the eggs!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.123779296875, 0.015307247638702393),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0, 0.11487197875976562, -0.005589410662651062),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.21012115478515625, -0.08428281545639038),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.22095489501953125, 0.06333862245082855),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.2981529235839844, -0.005589231848716736),
		},
	}
}