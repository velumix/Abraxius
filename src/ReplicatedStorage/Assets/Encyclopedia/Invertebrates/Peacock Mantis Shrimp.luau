local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PeacockMantisShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Peacock Mantis Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Odontodactylus scyllarus" },
	Model = Assets["Peacock Mantis Shrimp"],
	Icon = "rbxassetid://106999938286662",

	Family = "Odontodactylidae",
	Diet = "Crustaceans",
	Size = "17 cm (6.7 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-100 m (3.3-328 ft)",

	Facts = {
		"A crustacean known for its powerful smashing appendages, reaching the acceleration of a firearm!",
		"This species strikes prey so fast that a small cavitation bubble is created, instantly evaporating the water around it.",
		"There are two types of mantis shrimp, the smashers and spearers. The peacock is the largest of the smashers."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 0.2165679931640625, 0.03333854675292969),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.1369781494140625, -0.021085739135742188),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.47277069091796875, -0.04489707946777344),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.13645172119140625, 0.20538330078125, 0.10601425170898438),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.1480712890625, 0.20476531982421875, 0.11001205444335938),
		},
	}

}