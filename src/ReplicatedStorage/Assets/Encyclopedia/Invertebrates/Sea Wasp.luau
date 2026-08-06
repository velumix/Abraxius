local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SeaWasp", -- This is the what you set the _fishId arttibute to!
	Name = "Sea Wasp", -- The name of the fish that will show up in the book
	Aliases = { "Chironex fleckeri" },
	Model = Assets["Sea Wasp"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Chirodropidae",
    Diet = "Fish and Planktonic Crustaceans",
	Size = "3 m (9.8 ft)",
	Depths = "0-50 m (0-164 ft)",
	
	Facts = {
		"The sea wasp is often called the most venomous animal. It's venom is so potent that it can kill an adult human in 5 minutes!",
		"The sea wasp has many common names, but the most generic name is simply the box jelly. This is a name it shares with its class.",
		"Box jellies are so named for having four distinct corners, where the tentacles originate from.",
		"Box jellies have simple eyes! They have been known to actively avoid obstacles and hunt prey, seemingly using vision.",
		"If swimming in areas with box jellyfish, always wear protective gear and watch warning signs!",
		"Some other box jelly species can inflict a condition called Irukandji syndrome, which increases anxiety and heart rates.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(-0.00543212890625, -3.3344573974609375, 0.05959677696228027),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 6,
			},
			["Position"] = Vector3.new(0.921600341796875, -1.5488357543945312, 0.6793848276138306),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 7,
			},
			["Position"] = Vector3.new(0.9304351806640625, -1.5128173828125, -0.6499580144882202),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
				[2] = 8,
			},
			["Position"] = Vector3.new(-0.9355621337890625, -1.5513229370117188, 0.672551155090332),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
				[2] = 9,
			},
			["Position"] = Vector3.new(-0.930694580078125, -1.5153045654296875, -0.6568050980567932),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
				[2] = 10,
			},
			["Position"] = Vector3.new(0.921600341796875, -1.5488357543945312, 0.6793848276138306),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.923095703125, 3.6008987426757812, -0.511452853679657),
		},
		[8] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(-0.942901611328125, 3.5624008178710938, 0.8110570907592773),
		},
		[9] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(-0.9380645751953125, 3.598419189453125, -0.5183001160621643),
		},
		[10] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0.9142608642578125, 3.5648880004882812, 0.8178898096084595),
		},
	} 
}