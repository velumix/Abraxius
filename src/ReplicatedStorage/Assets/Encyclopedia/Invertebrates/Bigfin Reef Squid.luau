local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BigfinReefSquid", -- This is the what you set the _fishId arttibute to!
	Name = "Bigfin Reef Squid", -- The name of the fish that will show up in the book
	Aliases = { "Sepioteuthis lessoniana" },
	Model = Assets["Bigfin Reef Squid"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://124877768488857",

	Family = "Loliginidae",
    Diet = "Fish, Mollusks, and Crustaceans",
	Size = "Mantle Length 41 cm (16.1 in)",
    Depths = "0-100 m (0-328 ft)",
	
    Facts = {
        "Bigfin reef squid are notable for their ability to rapidly change color, even being known to become semi-transparent!",
		"The bigfin reef squid is known to form schools of several sized individuals, and are known for their social behavior.",
		"Bigfin reef squid show a strong response to light, being known to move toward it when presented.",
		"This squid is one of tthe most commonly kept squids in aquariums. This is due to its reef dwelling nature."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 0, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.6457366943359375, 0, -1),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.00437164306640625, -8.940696716308594e-08, -1.73834228515625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(-0.7456283569335938, -1.1920928955078125e-07, -0.98834228515625),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, -2.9802322387695312e-08, 1.5),
		},
	}

}