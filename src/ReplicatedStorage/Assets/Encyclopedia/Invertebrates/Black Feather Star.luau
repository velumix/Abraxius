local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BlackFeatheStar", -- This is the what you set the _fishId arttibute to!
	Name = "Black Feather Star", -- The name of the fish that will show up in the book
	Aliases = { "Colobometra perspinosa" },
	Model = Assets["Black Feather Star"],
	Icon = "",

	Family = "Colobometridae",
	Diet = "Zooplankton",
	Size = "30 cm (11.8 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-122 m (0-400.3 ft)",

	Facts = {
		"Feather stars are notable for their ability to swim, undulating their many arms in an otherworldly manner!",
		"Feather stars also known as sea lilies or crinoids. Some species in the deep sea have stalks!",
		"These animals are ancient, with some feather star fossils dating back to the Ordovician.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0, 0, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.5856170654296875, -0.736772894859314, -0.46856689453125),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.5856170654296875, -0.7499999403953552, 0.46856689453125),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.46856689453125, -0.7500019669532776, 0.585601806640625),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.46856689453125, -0.74822998046875, -0.5856170654296875),
		},
	} 

}