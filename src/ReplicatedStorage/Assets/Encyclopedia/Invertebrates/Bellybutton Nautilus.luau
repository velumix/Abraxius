local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BBNautilus", -- This is the what you set the _fishId arttibute to!
	Name = "Bellybutton Nautilus", -- The name of the fish that will show up in the book
	Aliases = { "Nautilus macromphalus" },
	Model = Assets["Bellybutton Nautilus"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Nautilidae",
    Diet = "Crustaceans and Detritus",
	Size = "Shell 18 cm (7 in)",
    Depths = "2-500 m (6.6-1640 ft)",
	
    Facts = {
		"Nautilus shells contain several chambers. These chambers are used to control bouyancy!",
		"The chambers in their shells limits the depth that nautilus can go. If they go too deep, they will implode.",
		"Nautilus are often called living fossils due to their similar appearance to ammonites. However, true nautilus are much more recent!",
		"Nautilus live in deeper water during the day, and will come to shallow water at night. It is because of this that they are rarely seen.",
		"The eyes of the nautilus are best described as being pinholes. These eyes lack a lens, providing the animal with poor vision.",
		"Nautilus shells are often considered to be the golden ratio in math. However, they do not quite meet this description.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.10932296514511108, 0.113739013671875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.2998870611190796, -0.0253448486328125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.43476253747940063, 0.27233123779296875),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.18397629261016846, 0.5094375610351562),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.17029619216918945, 0.41112518310546875),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, -0.3358239531517029, -0.04151153564453125),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0, -0.4104071855545044, -0.4771270751953125),
		},
	}

}