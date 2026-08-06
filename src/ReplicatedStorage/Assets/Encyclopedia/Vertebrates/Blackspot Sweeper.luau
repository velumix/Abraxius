local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BlackspotSweeper", -- This is the what you set the _fishId arttibute to!
	Name = "Blackspot Sweeper",
	Aliases = { "Pempheris oualensis" },
	Model = Assets["Blackspot Sweeper"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Pempheridae",
	Diet = "Invertebrates",
	Size = "22 cm (8.6 cm)",
	Depths = "0-36 m (0-118.1 ft)",

	Facts = {
		"Some species of sweepers are bioluminsecent!",
		"Blackspot sweepers are nocturnal, and are most often seen in caves and under ledges during the day.",
		"These fish are also known as bullseyes."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 8.940696716308594e-08, -0.5754928588867188),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.18937940895557404, -0.21903228759765625),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.06162390112876892, 0.26285552978515625),
		},
	}
}