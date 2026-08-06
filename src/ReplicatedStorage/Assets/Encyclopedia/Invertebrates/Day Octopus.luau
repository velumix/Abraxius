local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "DayOctopus", -- This is the what you set the _fishId arttibute to!
	Name = "Day Octopus", -- The name of the fish that will show up in the book
	Aliases = { "Octopus cyanea" },
	Model = Assets["Day Octopus"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://81285923352645",

	Family = "Octopodidae",
    Diet = "Molluscs and Crustaceans",
	Size = "Armspan 80 cm (31.5 in)",
    Depths = "0-150 m (0-492 ft)",
	
    Facts = {
        "Day octopus are notable for being a semi-day active octopus species. Most octopus are nocturnal.",
		"Octopus have brain cells that spread from a central brain into their arms! They are very intelligent, and often use tools.",
		"Octopus have three hearts and blue blood. The blue color of the blood is due to the presence of copper instead of iron.",
		"Octopus are known to quickly change shape and color. This is done with cells in their skin muscles called chromatophores.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
				[5] = 6,
				[6] = 7,
				[7] = 8,
				[8] = 9,
				[9] = 10,
			},
			["Position"] = Vector3.new(0, 0, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.5918350219726562, 0, 2),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(1.8000259399414062, 0, 1.5),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(1.8937759399414062, 0, -1.1104202270507812),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(1.2609405517578125, 0, -1.96844482421875),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.9523849487304688, 0, -2),
		},
		[7] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-2, 0, -0.75),
		},
		[8] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.6386184692382812, 0, 2.25),
		},
		[9] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-2, -0.4608876705169678, 1.4992141723632812),
		},
		[10] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.6001255512237549, -1.0631484985351562),
		},
	}

}