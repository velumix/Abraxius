local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "humpbackWhaleB", -- This is the what you set the _fishId arttibute to!
	Name = "Humpback Whale (Baby)", -- The name of the fish that will show up in the book
	Aliases = { "Megaptera novaeangliae" },
	Model = Assets["Humpback Whale (Young)"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://94199700449428",

	Family = "Balaenopteridae",
	Diet = "Fish and Krill",
	Size = "18 m (59.1 ft)",
	Depths = "0-616 m (0-2021 ft)",
	
    Facts = {
		"Humpbacks make complex vocalisations, called songs. Male whales use them during breeding season, likely to attract mates.",
		"Each humpback whale has unique markings on their tail flukes. This aids scientists in identifying individual whales.",
		"Scientists studying these whales often use descriptive names for individuals for identification purposes.",
		"Some humpback populations use bubbles to corral a school of fish into a small area for feeding, known as bubble-netting.",
		"Humpback whales are characterized by their long flippers. Their genus, Megaptera, even means long-winged!",
		"Humpback whales have recovered from low population numbers in the 1980s, are now one of the most numerous large whales!",
		"Humpbacks are popular with whale-watchers. They display many surface behaviors, such as breaching and fin slapping."
		
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.00000762939453125, 0.2540454864501953, -18.848785400390625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 7,
				[4] = 8,
			},
			["Position"] = Vector3.new(0.00000762939453125, 0.2540454864501953, -7.907920837402344),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.2540454864501953, 3.1270904541015625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
				[3] = 6,
			},
			["Position"] = Vector3.new(0, 0.2540454864501953, 13.6048583984375),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(-6.235221862792969, -0.8370699882507324, 17.896865844726562),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 4,
			},
			["Position"] = Vector3.new(6.4194793701171875, -0.8370704650878906, 17.896865844726562),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
				[2] = 9,
			},
			["Position"] = Vector3.new(-4.8124237060546875, -3.1133227348327637, -6.499137878417969),
		},
		[8] = {
			["Links"] = {
				[1] = 2,
				[2] = 10,
			},
			["Position"] = Vector3.new(4.956779479980469, -3.0101852416992188, -6.501380920410156),
		},
		[9] = {
			["Links"] = {
				[1] = 7,
			},
			["Position"] = Vector3.new(-8.565223693847656, -7.368122100830078, -6.100128173828125),
		},
		[10] = {
			["Links"] = {
				[1] = 8,
			},
			["Position"] = Vector3.new(8.431922912597656, -7.304327011108398, -6.1649017333984375),
		},
	}
}