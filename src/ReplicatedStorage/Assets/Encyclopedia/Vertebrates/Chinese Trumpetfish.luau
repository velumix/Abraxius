local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "ChineseTrumpetfish", -- This is the what you set the _fishId arttibute to!
	Name = "Chinese Trumpetfish", -- The name of the fish that will show up in the book
	Aliases = { "Aulostomus chinensis" },
	Model = Assets["Chinese Trumpetfish"],
	Icon = "rbxassetid://126446267999568",

	Family = "Aulostomidae",
	Diet = "Small Fishes and Crustaceans",
	Size = "80 cm (2.6 feet)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-122 m (3.3-400 ft)",

	Facts = {
		"Despite their name, Chinese trumpetfish are found across the tropical Indo-Pacific.",
		"Trumpetfish can come in a variety of colors, from white-striped orange, to bright yellow. It can even change color!",
		"Trumpetfish are known to shadow other larger fish to hide themselves from prey items.",
		"Trumpetfish will specifically follow parrotfish for their herbivorous nature, making them less conspicuous to prey fish.",
		"Trumpetfish have a habit of horizontally swimming face-down against gorgonians and vertical corals for camouflage."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.26718538999557495, -2.2605056762695312),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.08077102899551392, -0.8925933837890625),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, -0.01651972532272339, 0.821258544921875),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.2580277919769287, 1.374725341796875),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.24400590360164642, 1.3978958129882812),
		},
	}
}