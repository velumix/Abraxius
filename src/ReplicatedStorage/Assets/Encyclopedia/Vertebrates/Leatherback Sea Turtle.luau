local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "LeatherbackSeaTurtle", -- This is the what you set the _fishId arttibute to!
	Name = "Leatherback Sea Turtle", -- The name of the fish that will show up in the book
	Aliases = { "Dermochelys coriacea" },
	Model = Assets["Leatherback Sea Turtle"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://73826431620553",

	Family = "Dermochelyidae",
	Diet = "Jellyfish",
	Size = "2.7 m (8.8 ft)",
	Depths = "0-1250 m (0-4101 ft)",
	
    Facts = {
		"The leatherback is the largest sea turtle, and is the largest non-crocodilian reptile. It can weigh up to 500 kg (1100 lbs)!",
		"Leatherbacks have distinct spined throats to help them keep their gelatinous meals from escaping.",
		"These turtles can withstand colder waters than other sea turtles and are often seen in temperate regions.",
		"Leatherbacks are the fastest moving and deepest diving of the sea turtles.",
		"Pacific leatherback populations are highly endangered, but some conservation efforts are helping them recover."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -7.008717060089111, -0.24542951583862305),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 6,
				[5] = 7,
			},
			["Position"] = Vector3.new(0, -3.629793167114258, -0.10498619079589844),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(-3.9117660522460938, -1.4437923431396484, -0.014125823974609375),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(3.7930450439453125, -1.43994140625, -0.013967514038085938),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 7.608162879943848, 0.04166603088378906),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-5.068962097167969, -3.7019824981689453, 1.631837248802185),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(5.5349884033203125, -3.694927215576172, 1.6126796007156372),
		},
	}
}