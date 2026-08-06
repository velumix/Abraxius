local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "YellowBoxfishJuv", -- This is the what you set the _fishId arttibute to!
	Name = "Yellow Boxfish (Juvenile)", -- The name of the fish that will show up in the book
	Aliases = { "Ostracion cubicus" },
	Model = Assets["YellowBoxfishJuv"], -- ReplicatedStorage -> Assets -> FishModels 
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
			["Position"] = Vector3.new(0, -1.4901161193847656e-08, 0.1999969482421875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -2.2351741790771484e-08, 0.09999847412109375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.049999967217445374, 0.05999755859375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.04999995231628418, -0.14000320434570312),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.040000054985284805, -0.14000320434570312),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, -0.040000058710575104, 0.029994964599609375),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(-0.00018310546875, -0.0003481656312942505, 0.10026931762695312),
		},
	}

}