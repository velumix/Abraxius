local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GreenSeaTurtle", -- This is the what you set the _fishId arttibute to!
	Name = "Green Sea Turtle", -- The name of the fish that will show up in the book
	Aliases = { "Chelonia mydas" },
	Model = Assets["Green Sea Turtle"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Cheloniidae",
	Diet = "Seagrass",
	Size = "1.5 m (4.9 ft)",
	Depths = "0-200 m (0-656 ft)",
	
    Facts = {
		"Green sea turtles are the most herbivorous of the sea turtle species, with most of their adult diet consisting of seagrasses.",
		"Despite being called the green sea turtle, they can come in a variety of colors. Some individuals are very dark, appearing black!",
		"Green sea turtles were listed as an endangered species for years. In 2025, they had recovered to the point they were delisted!",
		"Green sea turtles are commonly seen sleeping on the seabed. They usually wedge themselves in a secure spot to do this.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.000030517578125, -4.327964782714844, -0.5695240497589111),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 5,
				[4] = 7,
				[5] = 13,
			},
			["Position"] = Vector3.new(0.00003814697265625, -2.3797531127929688, -0.5695338249206543),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(2.6077804565429688, -2.3797531127929688, 0.43047213554382324),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(4.6077728271484375, -1.3797683715820312, 0.43047118186950684),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
			},
			["Position"] = Vector3.new(-2.6077651977539062, -2.3797683715820312, 0.43045687675476074),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(-4.607757568359375, -1.3797607421875, 0.43047642707824707),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
				[2] = 8,
			},
			["Position"] = Vector3.new(2.517303466796875, 0.6202163696289062, 0.5380859375),
		},
		[8] = {
			["Links"] = {
				[1] = 7,
				[2] = 9,
				[3] = 10,
			},
			["Position"] = Vector3.new(1.4171981811523438, 3.2198257446289062, -0.027636051177978516),
		},
		[9] = {
			["Links"] = {
				[1] = 8,
				[2] = 11,
			},
			["Position"] = Vector3.new(0.00323486328125, 4.1155548095703125, -0.461911678314209),
		},
		[10] = {
			["Links"] = {
				[1] = 8,
			},
			["Position"] = Vector3.new(2.1099700927734375, 4.110076904296875, 0.6798403263092041),
		},
		[11] = {
			["Links"] = {
				[1] = 9,
				[2] = 12,
				[3] = 13,
			},
			["Position"] = Vector3.new(-1.2947540283203125, 3.2051773071289062, -0.06612920761108398),
		},
		[12] = {
			["Links"] = {
				[1] = 11,
			},
			["Position"] = Vector3.new(-2.1514511108398438, 4.070167541503906, 0.7736830711364746),
		},
		[13] = {
			["Links"] = {
				[1] = 11,
				[2] = 2,
			},
			["Position"] = Vector3.new(-2.5409469604492188, 0.5403823852539062, 0.5925631523132324),
		},
	}
}