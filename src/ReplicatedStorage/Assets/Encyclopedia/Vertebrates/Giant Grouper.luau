local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GiantGrouper", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Grouper", -- The name of the fish that will show up in the book
	Aliases = { "Epinephelus lanceolatus" },
	Model = Assets["Giant Grouper"],
	Icon = "rbxassetid://75496282764852",

	Family = "Epinephelidae",
	Diet = "Anything Able to Fit in Mouth",
	Size = "2.7 m (8.8 feet)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-200 m (3.3-656 ft)",

	Facts = {
		"Also known as the Queensland or bumblebee grouper, this is one of the largest bony fish in reef environments.",
		"Giant groupers are not picky eaters, known to eat other bony fish, young turtles, crustaceans, and even sharks!",
		"Young and juvenile giant groupers have striking yellow patterning, which gives them the bumblebee alternate name.",
		"Adult giant groupers are brown, sometimes showing faint evidence of their yellow juvenile coloration on the fins.",
		"In public aquaria, the giant grouper is often confused with the Atlantic goliath grouper due to their similar size."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.33600330352783203, -7.738420009613037),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 6,
				[4] = 7,
			},
			["Position"] = Vector3.new(0, 0.3360025882720947, -2.89481782913208),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 2.6056017875671387, 0.8683075904846191),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
				[3] = 6,
			},
			["Position"] = Vector3.new(0, 0.42143797874450684, 3.950042963027954),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 0.42143750190734863, 7.85200834274292),
		},
		[6] = {
			["Links"] = {
				[1] = 4,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, -1.7515355348587036, 0.9699983596801758),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -1.2604546546936035, -6.788929462432861),
		},
	}
}