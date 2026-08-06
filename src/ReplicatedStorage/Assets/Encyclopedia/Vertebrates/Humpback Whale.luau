local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "humpbackWhale", -- This is the what you set the _fishId arttibute to!
	Name = "Humpback Whale", -- The name of the fish that will show up in the book
	Aliases = { "Megaptera novaeangliae" },
	Model = Assets["Humpback Whale"], -- ReplicatedStorage -> Assets -> FishModels 
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
			["Position"] = Vector3.new(0.0000019073486328125, 1.5684375762939453, -42.87369918823242),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 1.5684356689453125, -25.762893676757812),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 8,
				[4] = 9,
			},
			["Position"] = Vector3.new(0, 1.5684318542480469, -13.781044006347656),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.0000019073486328125, 1.568429946899414, 7.8005218505859375),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
				[3] = 7,
			},
			["Position"] = Vector3.new(0, -0.5134983062744141, 31.673606872558594),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(-15.9779052734375, -2.937694549560547, 43.102783203125),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
				[2] = 5,
			},
			["Position"] = Vector3.new(16.26987075805664, -2.937694549560547, 43.102783203125),
		},
		[8] = {
			["Links"] = {
				[1] = 3,
				[2] = 10,
			},
			["Position"] = Vector3.new(-10.87258529663086, -7.194433212280273, -15.362083435058594),
		},
		[9] = {
			["Links"] = {
				[1] = 3,
				[2] = 11,
			},
			["Position"] = Vector3.new(11.149849891662598, -7.176915168762207, -15.362091064453125),
		},
		[10] = {
			["Links"] = {
				[1] = 8,
			},
			["Position"] = Vector3.new(-20.160396575927734, -19.41794776916504, -13.781036376953125),
		},
		[11] = {
			["Links"] = {
				[1] = 9,
			},
			["Position"] = Vector3.new(19.833404541015625, -18.627702713012695, -13.781036376953125),
		},
	}

}