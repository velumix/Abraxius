local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GiantTigerPrawn", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Tiger Prawn", -- The name of the fish that will show up in the book
	Aliases = { "Penaeus monodon" },
	Model = Assets["Giant Tiger Prawn"],
	Icon = "rbxassetid://105884948520297",

	Family = "Penaeidae",
	Diet = "Invertebrates",
	Size = "33 cm (13 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-150 m (0-492 ft)",

	Facts = {
		"Giant tiger prawns are the second most widely farmed prawn in the world, making up for 50% of farmed shrimp production!",
		"Juvenile tiger prawns are found in brackish and coastal environments, while adults venture deeper offshore.",
		"Prawns are very good swimmers and use feather-like, modified structures under their tail, called pleopods, to paddle around.",
		"In the context of food, the terms prawn and shrimp are often used interchangeably. Prawns are usually larger, however.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.8089828491210938, 9.834766387939453e-07),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.05898284912109375, -0.04602983593940735),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 0.8089752197265625, 0.05242547392845154),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.25, 1.1478424072265625, 0.14024503529071808),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.25, 1.1478424072265625, 0.14024464786052704),
		},
	}

}