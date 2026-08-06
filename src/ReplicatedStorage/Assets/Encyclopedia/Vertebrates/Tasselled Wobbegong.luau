local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "tasselledwobbegong", -- This is the what you set the _fishId arttibute to!
	Name = "Tasselled Wobbegong",
	Aliases = { "Eucrossorhinus dasypogon" },
	Model = Assets["Tasselled Wobbegong"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://140655368414060",

	Family = "Orectolobidae",
	Diet = "Small Fish and Invertebrates",
	Size = "125 cm (4.1 ft)",
	Depths = "5-50 m (16-164 ft)",

	Facts = {
		"These sharks exhibit a hunting behavior known as 'caudal luring' where they wave their tails to mimic a fish swimming around.",
		"Wobbegongs belong to a group of sharks known as the carpet sharks, which includes whale, nurse, and zebra sharks!",
		"Tasselled wobbegongs are known to have small home ranges, and will utilize the same resting crevices every day."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.0011653900146484375, 1.9750213623046875, -0.27756595611572266),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 5,
			},
			["Position"] = Vector3.new(-1.0875892639160156, 0.17848968505859375, -0.2224273681640625),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.9671726226806641, 0.13738250732421875, -0.22002029418945312),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(2.023914337158203, -1.0162200927734375, -0.18366193771362305),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-2.151224136352539, -1.00567626953125, -0.1862807273864746),
		},
	}
}