local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "LeopardSeaCucumber", -- This is the what you set the _fishId arttibute to!
	Name = "Leopard Sea Cucumber", -- The name of the fish that will show up in the book
	Aliases = { "Bohadschia argus" },
	Model = Assets["Leopard Sea Cucumber"],
	Icon = "rbxassetid://110681434140587",

	Family = "Holothuriidae",
	Diet = "Detritus",
	Size = "60 cm (23.6 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-30 m (0-98 ft)",

	Facts = {
		"Some sea cucumbers, like this one, have a strange defense strategy. They release toxic, sticky gut strands from their rear!",
		"Leopard sea cucumbers sometimes have fish, called pearfish, live in their body. One time, 15 fish were found in one cucumber!",
		"Leopard sea cucumbers feed on detritus using black and white mouth tentacles that extend when feeding.",
	},
	
	Skeleton =  {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0, 1.8694381713867188),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0, 0.8419189453125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0, -0.3935089111328125),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0, -1.629608154296875),
		},
	}
}