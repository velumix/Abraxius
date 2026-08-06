local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "potatocod", -- This is the what you set the _fishId arttibute to!
	Name = "Potato Grouper", -- The name of the fish that will show up in the book
	Aliases = { "Epinephelus tukula" },
	Model = Assets["potatocod"],
	Icon = "rbxassetid://75496282764852",

	Family = "Epinephelidae",
	Diet = "Anything Able to Fit in Mouth",
	Size = "2 m (6.5 ft)",
	Time = "Day", -- Time of day the fish is active
	Depths = "10-400 m (32.8-1312.3 ft)",

	Facts = {
		"The potato grouper gets its name from the dark. potato-shaped spots covering its body.",
		" This grouper is one of the Great Barrier Reef's great 8, comprising of 8 species that are popular for divers to see!",
		"The potato grouper is known as the potato cod in Australia. One of the top places to see the species there is known as Cod Hole!",
		"Thanks to the conservation efforts of Ron and Valerie Taylor, the Potato grouper and Cod Hole were officially protected by law in 1996."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 8,
			},
			["Position"] = Vector3.new(0, -0.49486231803894043, -3.3726806640625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.19791746139526367, -5.544441223144531),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, -0.21313631534576416, -5.794242858886719),
		},
		[4] = {
			["Links"] = {},
			["Position"] = Vector3.new(0, -0.49486231803894043, -3.3726806640625),
		},
		[5] = {
			["Links"] = {},
			["Position"] = Vector3.new(0, -0.1858004331588745, -1.1089706420898438),
		},
		[6] = {
			["Links"] = {},
			["Position"] = Vector3.new(-0.0000152587890625, 0.1906883716583252, 1.4746589660644531),
		},
		[7] = {
			["Links"] = {},
			["Position"] = Vector3.new(-0.000030517578125, 0.057189226150512695, 3.8829002380371094),
		},
		[8] = {
			["Links"] = {
				[1] = 1,
				[2] = 9,
			},
			["Position"] = Vector3.new(0, 0.7800395488739014, -3.3726806640625),
		},
		[9] = {
			["Links"] = {
				[1] = 8,
				[2] = 10,
			},
			["Position"] = Vector3.new(0, 1.047372579574585, -0.7425575256347656),
		},
		[10] = {
			["Links"] = {
				[1] = 9,
				[2] = 11,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.4482879638671875, 1.8811225891113281),
		},
		[11] = {
			["Links"] = {
				[1] = 10,
			},
			["Position"] = Vector3.new(-0.000030517578125, 0.13354086875915527, 4.181896209716797),
		},
	}
}