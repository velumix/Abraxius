local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "yellowfinTuna", -- This is the what you set the _fishId arttibute to!
	Name = "Yellowfin Tuna",
	Aliases = { "Thunnus albacares" },
	Model = Assets["Yellowfintuna"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://120919089298877",

	Family = "Scombridae",
	Diet = "Fish and Squid",
	Size = "2.39 m (7.8 ft)",
	Depths = "1-1602 m (3.3-5255 ft)",

	Facts = {
		"Yellowfin tuna are known to school with similar sized animals, including other tuna species and dolphins!",
		"Yellowfin tuna seem to prefer depths above the thermocline, the area where water temperature drops with depth.",
		"Tuna are warm-blooded fish. This, as well as an efficient cardiovascular system, allows for high top speeds.",
	},

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.0000011920928955078125, -6.262065887451172),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 9.5367431640625e-07, -3.9686737060546875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 7,
			},
			["Position"] = Vector3.new(0, 4.76837158203125e-07, -0.5174331665039062),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.7250587940216064, 1.2781181335449219),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.3595297336578369, 2.806121826171875),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, -0.0799870491027832, 4.554290771484375),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 1.3576982021331787, 0.11756134033203125),
		},
	}
}