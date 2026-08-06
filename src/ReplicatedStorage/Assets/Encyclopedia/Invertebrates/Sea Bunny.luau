local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SeaBunny", -- This is the what you set the _fishId arttibute to!
	Name = "Sea Bunny", -- The name of the fish that will show up in the book
	Aliases = { "Jorunna parva" },
	Model = Assets["SeaBunny"],
	Icon = "",

	Family = "Discodorididae",
	Diet = "Sponges",
	Size = "2.5 cm (0.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-30 m (3.3-98 ft)",

	Facts = {
		"The sea bunny is instantly recognisable for its cute, bunny-like shape, which gives it a comical appearance.",
		"Sea bunnies appear in a range of colours, influenced by the sponges they feed on.",
		"Like other members of the genus Jorunna, sea bunnies mainly eat toxic sponges and become toxic themselves as a result."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0, -0.0638580322265625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.029022216796875, 0.025259405374526978, -0.0638580322265625),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.023193359375, 0.024666637182235718, -0.0638580322265625),
		},
	}
}