local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "MagnificentChromodoris", -- This is the what you set the _fishId arttibute to!
	Name = "Magnificent Chromodoris", -- The name of the fish that will show up in the book
	Aliases = { "Chromodoris magnifica" },
	Model = Assets["Magnificent Nudibranch"],
	Icon = "rbxassetid://91570910346556",

	Family = "Chromodorididae",
	Diet = "Sponges",
	Size = "9 cm (3.5 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-25 m (3.3-80 ft)",

	Facts = {
		"Nudibranches specialize on sponges. Many species only feed on one type.",
		"The bright colors of nudibranches signify unpleasant taste, which derives from the sponges they eat.",
		"The two ear-like strutures at the front of nudibranch are called rhinophores. These are used to detect smells.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.00000762939453125, -0.10565948486328125, 0.0029996298253536224),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.03957366943359375, 0.0027481280267238617),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.13344573974609375, -0.04764422029256821),
		},
	}
}