local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PacCleanerShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Pacific Cleaner Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Lysmata amboinensis" },
	Model = Assets["Pacific Cleaner Shrimp"],
	Icon = "",

	Family = "Lysmatidae",
	Diet = "Detritus",
	Size = "6 cm (2.3 in)",
	Depths = "5-40 m (16-131.2 ft)",

	Facts = {
		"There are several species of shrimp that act as cleaners! It is thought that a large portion of their food comes from cleaning clients.",
		"Cleaner shrimp sway side to side to a potential signal to a client that they are open for cleaning.",
		"Cleaner shrimp are known to offer their cleaning services to divers!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(-0.0000152587890625, -0.082977294921875, 0.01659393310546875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.0128326416015625, 0.01494598388671875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0000152587890625, 0.185455322265625, -0.037326812744140625),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.2428741455078125, -0.49030303955078125, -0.0717010498046875),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.2254638671875, -0.4833221435546875, -0.07019424438476562),
		},
	} 
}