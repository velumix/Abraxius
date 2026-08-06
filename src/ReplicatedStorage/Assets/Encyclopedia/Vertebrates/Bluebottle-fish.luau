local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "bluebottleFish", -- This is the what you set the _fishId arttibute to!
	Name = "Bluebottle-fish (Juvenile)", -- The name of the fish that will show up in the book
	Aliases = { "Nomeus gronovii" },
	Model = Assets["Bluebottlefish"],
	Icon = "",

	Family = "Nomeidae",
	Diet = "Bluebottle Tentacles and Plankton",
	Size = "39 cm (15.3 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-1000 m (0-3280 ft)",

	Facts = {
		"Juvenile bluebottlefish are found near man-o-war, or bluebottles. They use these venomous animals for shelter and food!",
		"Adult bluebottlefish look different from juveniles and dwell in very deep water! They are not found with man-o-war as adults.",
		"Bluebottlefish are seemingly not immune to being eaten or stung by man-o-war. They simply avoid the stinging tentacles!",
		"Despite being named after and commonly seen with man-o-war, these fish sometimes can be found with other cnidarian species.",
		"These are not the only fish that can be found with man-o-war. Others such as golden trevally and longspine snipefish also can be!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.6377029418945312, 0.1880035400390625, 0.2011260986328125),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.12584686279296875, 0.18837738037109375, -0.576751708984375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.7820053100585938, 0.18902587890625, -0.093841552734375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(-0.01956939697265625, 0.1884307861328125, 0.6491851806640625),
		},
	}
}