local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "sevenElevenCrab", -- This is the what you set the _fishId arttibute to!
	Name = "Seven-Eleven Crab", -- The name of the fish that will show up in the book
	Aliases = { "Carpilius maculatus" },
	Model = Assets["Seven Eleven Crab"],
	Icon = "rbxassetid://84084920116910",

	Family = "Carpiliidae",
	Diet = "Snails and Crustaceans",
	Size = "Shell Width 15 cm (5.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-35 m (0-114 ft)",

	Facts = {
		"This crab gets its name from its spot arrangement. The distinct seven in front, plus the lesser four in back, forms eleven in total.",
		"There are some reports of this crab being toxic, despite often being consumed. These reports do not appear to be conclusive.",
		"Due to a wide range, this crab is known by a variety of common names. These include spotted reef crab and large spotted crab.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 6,
			},
			["Position"] = Vector3.new(0, 0, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.5, -0.19515123963356018, -0.00000762939453125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.16512298583984375, -0.27522873878479004, -0.327423095703125),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.4114837646484375, -0.16425848007202148, -0.00002288818359375),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0.14159393310546875, -0.2484082281589508, -0.3519134521484375),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.00000762939453125, -0.2225055992603302, 0.25),
		},
	}

}