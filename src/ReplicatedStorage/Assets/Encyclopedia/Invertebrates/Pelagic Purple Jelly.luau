local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PURPLEGUY", -- This is the what you set the _fishId arttibute to!
	Name = "Pelagic Purple Jelly", -- The name of the fish that will show up in the book
	Aliases = { "Thysanostoma loriferum" },
	Model = Assets["Pelagic Purple Jelly"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Thysanostomatidae",
    Diet = "Zooplankton",
	Size = "Diameter 20 cm (7.8 in)",
	Depths = "0-6 m (0-19 ft)",
	
	Facts = {
		"This long-armed jelly is most often seen drifting at the surface.",
		"Many juvenile fish are seen associating with these jellies, often being species of filefish or trevally!",
		"There is not a lot known about these jellies, though they can be identified by their purple color and long arms.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(-0.0205078125, -2.370729923248291, -0.00000762939453125),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 6,
			},
			["Position"] = Vector3.new(-0.0205230712890625, -1.8222603797912598, -0.3934059143066406),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 7,
			},
			["Position"] = Vector3.new(-0.0205078125, -1.820467472076416, 0.3940887451171875),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
				[2] = 8,
			},
			["Position"] = Vector3.new(-0.397369384765625, -1.8197712898254395, -0.000003814697265625),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
				[2] = 9,
			},
			["Position"] = Vector3.new(0.376983642578125, -1.8465619087219238, -0.000003814697265625),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0206146240234375, 2.771711587905884, -0.23424911499023438),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.0205535888671875, 2.775594472885132, 0.3063087463378906),
		},
		[8] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(-0.3974456787109375, 2.7549898624420166, -0.00000762939453125),
		},
		[9] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0.3255462646484375, 2.8210418224334717, -0.00000762939453125),
		},
	}
}