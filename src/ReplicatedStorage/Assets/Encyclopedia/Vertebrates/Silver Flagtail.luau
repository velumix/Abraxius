local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SilverFlagtail", -- This is the what you set the _fishId arttibute to!
	Name = "Silver Flagtail", -- The name of the fish that will show up in the book
	Aliases = { "Kuhlia munda" },
	Model = Assets["Silver Flagtail"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Kuhliidae",
	Diet = "Small Invertebrates",
	Size = "13 cm (5.1 in)",
	Depths = "0-10 m (0 - 30 ft)",

    Facts = {
		"These fish migrate to the sea to spawn, living most of their adult life in freshwater environments.",
		"In Hawaii, flagtails are known as ʻāhole. They are an important cultural species there, with even an airport named after them.",
		"Flagtails species are usually found in freshwater or brackish environments."
	},

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.28667449951171875, -0.00003153085708618164),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 6,
				[4] = 7,
			},
			["Position"] = Vector3.new(0, 0.02545166015625, -0.008553624153137207),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 0.2035369873046875, -0.009087800979614258),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.3585052490234375, -0.07038229703903198),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.3552093505859375, 0.05484658479690552),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.1020965576171875, -0.09596365690231323),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.08228302001953125, 0.07968032360076904),
		},
	} 
}