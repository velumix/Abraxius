local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Sargassumfish", -- This is the what you set the _fishId arttibute to!
	Name = "Sargassumfish", -- The name of the fish that will show up in the book
	Aliases = { "Histrio histrio" },
	Model = Assets["Sargassumfish"],
	Icon = "rbxassetid://125855424750389",

	Family = "Antennariidae",
	Diet = "Small Fish and Crustaceans",
	Size = "Up to 20 cm (7.8 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-50 m (3.3-164 ft)",

	Facts = {
		"The sargassumfish is strongly associated with floating sargassum, a type of kelp, patches in the open ocean.",
		"The sargassumfish is a frogfish, shallow water anglerfish that excel in camoflauge and quick ambush predation.",
		"Due to their pelagic existance, this fish can be found in most tropical waters wolrdwide."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.325653076171875, 0.002308279275894165),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, -0.177459716796875, -0.2767336666584015),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 0.024250030517578125, 0.026764363050460815),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.3354034423828125, -0.08187103271484375, 0.27374738454818726),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.3354339599609375, -0.0818634033203125, 0.2736174464225769),
		},
	}
}