local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "bluegreenChromis", -- This is the what you set the _fishId arttibute to!
	Name = "Blue-Green Chromis", -- The name of the fish that will show up in the book
	Aliases = { "Chromis viridis" },
	Model = Assets["Blue-Green Chromis"],
	Icon = "rbxassetid://80467662160760",

	Family = "Pomacentridae",
	Diet = "Plankton",
	Size = "10 cm (3.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-20 m (3.3-66 ft)",

	Facts = {
		"Blue-green chromis are known to form feeding aggregations above branching corals such as staghorn coral (Acropora).",
		"These fish are found across the Indo-Pacific, from the Red Sea to the Galapagos.",
		"Male chromis will protect eggs at their nests, which are built on sandy substrate."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.5981903076171875, 0.500525712966919),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.60443115234375, -0.3563164472579956),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.5862503051757812, -0.36499106884002686),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, 0.5918312072753906, 0.4964592456817627),
		},
	}
}