local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "ChocoChipSeaStar", -- This is the what you set the _fishId arttibute to!
	Name = "Chocolate Chip Sea Star", -- The name of the fish that will show up in the book
	Aliases = { "Protoreaster nodosus" },
	Model = Assets["Chocolate Chip Sea Star"],
	Icon = "rbxassetid://121329575475158",

	Family = "Oreasteridae",
	Diet = "Invertebrates",
	Size = "30 cm (11.8 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-37 m (3.3-121.4 ft)",

	Facts = {
		"This species is suggested to be a bioindicator species. This means that their presence indicates good environment health!",
		"This sea star can be a variety of colors. It can be pink, tan, brown, and even red!",
		"Sea stars are oppportunistic carnivores, eating anything that they can catch. They feed by ejecting their stomach!",
		"Due to their distinct appearance, this species is unfortunately often harvested and dried for the souvenir trade."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
				[5] = 6,
			},
			["Position"] = Vector3.new(0.0295562744140625, -0.002513885498046875, 0.07611083984375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.45360565185546875, -0.19834041595458984, 0.70989990234375),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.7570648193359375, -0.19431257247924805, -0.141448974609375),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.02243804931640625, -0.15699529647827148, -0.65631103515625),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.7258872985839844, -0.13744401931762695, -0.1704559326171875),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.4482841491699219, -0.1643543243408203, 0.72503662109375),
		},
	}

}