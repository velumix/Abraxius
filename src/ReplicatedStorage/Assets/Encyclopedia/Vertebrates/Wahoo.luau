local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "wahoo", -- This is the what you set the _fishId arttibute to!
	Name = "Wahoo",
	Aliases = { "Acanthocybium solandri" },
	Model = Assets["Wahoo"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Scombridae",
	Diet = "Fish and Squid",
	Size = "2.5 m (8.2 ft)",
	Depths = "1-200 m (3.3-656 ft)",

	Facts = {
		"The wahoo is usually a solitary fish, but it forms smaller groups on occasion.",
		"This elongate member of the tuna family is a popular sportfish, and is a prized catch across its range!",
		"The stunning stripes of the wahoo flaring up when the fish is excited. When calm, the animal appears simply silver!",
		"The origin of the common name of this fish is unclear. One idea is that it comes from a misspelling of the Hawaiian island of Oahu.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 9,
			},
			["Position"] = Vector3.new(0.0000152587890625, -7.969062805175781, 0.19458377361297607),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 9,
			},
			["Position"] = Vector3.new(0, -3.7537002563476562, -1.0870012044906616),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.48166656494140625, -0.20616424083709717),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.0000152587890625, 2.0005950927734375, -0.20752203464508057),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0.00006103515625, 3.13818359375, -0.9477635622024536),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0.000091552734375, 4.84027099609375, 0.35092735290527344),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
				[2] = 8,
			},
			["Position"] = Vector3.new(0.0001220703125, 7.3935546875, -0.16868746280670166),
		},
		[8] = {
			["Links"] = {
				[1] = 7,
			},
			["Position"] = Vector3.new(0.0001983642578125, 8.529205322265625, -1.697144865989685),
		},
		[9] = {
			["Links"] = {
				[1] = 1,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, -3.7394180297851562, 1.023510456085205),
		},
	}
}