local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BTWSailor", -- This is the what you set the _fishId arttibute to!
	Name = "By-the-Wind Sailor", -- The name of the fish that will show up in the book
	Aliases = { "Velella velella" },
	Model = Assets["By-the-Wind Sailor"],
	Icon = "",

	Family = "Porpitidae",
	Diet = "Zooplankton",
	Size = "10 cm (3.9 in)",
	Depths = "Surface",

	Facts = {
		"Wind sailors are most commonly observed while washed up on shore, sometimes in the millions!",
		"The sail on these animals is the only way they can move, they cannot move at all without wind propulsion.",
		"This animal is actually a colony of smaller parts, each having one sail. Each individual colony can be male or female.",
	},

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(-0.000640869140625, 0.1045074462890625, 0.01142914593219757),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.13592529296875, 0.361968994140625, 0.011429138481616974),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.4578094482421875, 0.32010650634765625, 0.011429153382778168),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.13226318359375, -0.2291259765625, 0.011429093778133392),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.4391937255859375, -0.2073822021484375, 0.01142912358045578),
		},
	}
}