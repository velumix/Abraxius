local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "YellowBoxfish", -- This is the what you set the _fishId arttibute to!
	Name = "Yellow Boxfish", -- The name of the fish that will show up in the book
	Aliases = { "Ostracion cubicus" },
	Model = Assets["YellowBoxfishAdult"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Ostraciidae",
	Diet = "Invertebrates and Algae",
	Size = "45 cm (17.7 in)",
    Depths = "1-280 m (3-918 ft)",
	
    Facts = {
		"Yellow boxfish recieved their name due to their instantly recognisable yellow and black spotted coloration as juveniles!",
		"As juveniles grow to adults, some individuals lose a majority of their yellow coloration for more blueish tones.",
		"When exposed to high levels of stress, boxfish secrete mucus which contains lethal toxins known as ostracitoxin.",
		"The striking coloration of boxfish is a phenomenon known as aposematism which is used to warn predators of how toxic they are!",
		"Boxfish and their relatives are protected by a hard outer shell called a carapace, just like turtles!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 5.960464477539063e-08, 1.2000045776367188),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0, 0.5000076293945312),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.19999992847442627, 0.30001068115234375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.1999998688697815, -0.8999900817871094),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.3000001907348633, -0.8999900817871094),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, -0.3000001907348633, 0.30001068115234375),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0, -2.384185791015625e-07, 0.5000076293945312),
		},
	}

}