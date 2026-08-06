local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "whitemarginStargazer", -- This is the what you set the _fishId arttibute to!
	Name = "Whitemargin Stargazer", -- The name of the fish that will show up in the book
	Aliases = { "Uranoscopus sulphureus" },
	Model = Assets["Whitemargin Stargazer"],
	Icon = "rbxassetid://92819374186168",

	Family = "Uranoscopidae",
	Diet = "Fishes",
	Size = "45 cm (17.7 in)",
	Depths = "5-350 m (16.4-1148 ft)",

	Facts = {
		"Stargazers are capable of producing an electric shock! This is done with an electric organ on the head.",
		"Stargazers do not have electroreceptors, and thus do not use electricity to locate food as other electric fish do.",
		"Along with being electric, stargazers are also venomous. They can inject vemon using the spines above their pectoral fins!",
		"The teeth-like projections on the lips of a stargazer are actually hair-like structures, and help keep sand out of their mouth.",
		"Whitemargin stargazers utilize a specialized lure that sticks out of their mouth like a worm to draw in unsuspecting prey!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.7769317626953125, -0.16765114665031433),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.132354736328125, -0.54608154296875, -0.1824342906475067),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.123382568359375, -0.5442352294921875, -0.1825558841228485),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, -0.198272705078125, 0.071867436170578),
		},
	}
}