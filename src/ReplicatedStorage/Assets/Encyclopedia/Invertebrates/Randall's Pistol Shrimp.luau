local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "RandallsPistolShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Randall's Pistol Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Alpheus randalli" },
	Model = Assets["Randall's Pistol Shrimp"],
	Icon = "rbxassetid://135609213500795",

	Family = "Alpheidae",
	Diet = "Detritus",
	Size = "5 cm (1.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-18 m (3.3-59 ft)",

	Facts = {
		"Pistol shrimps are named for their ability to stun prey with a bubble shot with their large claw!",
		"When in groups, pistol shrimps are so loud that they are capable of interfering with sonar.",
		"Many pistol shrimp species form symbiotic relationships with gobies. The shrimp makes the burrow for them to live in."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, 0, -0.0322265625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0, 0.16788482666015625),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.0229644775390625, 0, -0.12055206298828125),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.02924346923828125, 0, -0.098052978515625),
		},
	} 

}