local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GBROctopus", -- This is the what you set the _fishId arttibute to!
	Name = "Greater Blue Ringed Octopus", -- The name of the fish that will show up in the book
	Aliases = { "Hapalochlaena lunulata" },
	Model = Assets["Greater Blue Ringed Octopus"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://87639297038964",

	Family = "Octopodidae",
    Diet = "Crustaceans",
	Size = "Armspan 10 cm (3.9 in)",
    Depths = "0-20 m (0-65.6 ft)",
	
    Facts = {
        "Despite their small size, these octopus are one of the most venomous animals in the ocean!",
		"One of the most potent toxins that blue-ringed octopus utilize is tetrodotoxin, the same found in pufferfish.",
		"When disturbed, these octopus flash their vivid blue rings to warn about their dangerous venom.",
		"There are four species of blue-ringed octopus, all equally toxic. This species is notable for its large rings."
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
			["Position"] = Vector3.new(0, 0.22264690697193146, -0.36014556884765625),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.36438751220703125, -9.238719940185547e-07, 0.11949920654296875),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.414276123046875, 0.0000010579824447631836, 0.13048553466796875),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.118896484375, 2.5331974029541016e-07, -0.366302490234375),
		},
	}

}