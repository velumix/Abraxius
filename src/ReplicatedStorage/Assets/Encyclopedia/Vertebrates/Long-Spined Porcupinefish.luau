local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "LongspinePorcupine", -- This is the what you set the _fishId arttibute to!
	Name = "Long-Spined Porcupinefish", -- The name of the fish that will show up in the book
	Aliases = { "Diodon holocanthus" },
	Model = Assets["Long-Spined Porcupinefish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://72849788621272",
	
	Family = "Diodontidae",
	Diet = "Molluscs, Urchins, and Crustaceans",
	Size = "50 cm (19.7 in)",
    Depths = "2-100 m (6.5-328 ft)",
	
    Facts = {
		"Porcupinefish are notable for their ability to puff up into a ball by inhaling water into their stomach when threatened.",
		"Porcupinefish are characterized from the related pufferfish by the presence of spines that line their body.",
		"These fish have a poison called tetrodotoxin in their organs. It is one of the most potent natural poisons!",
		"Porcupinefish are poor swimmers. They are relatively common finds washed up on beaches after a stormy day."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -5.960464477539063e-08, -1.291107177734375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -1.1920928955078125e-07, -0.291107177734375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
				[4] = 6,
			},
			["Position"] = Vector3.new(0, -1.1920928955078125e-07, 0.708892822265625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, -1.7881393432617188e-07, 1.2089004516601562),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.4110952615737915, 0.708892822265625),
		},
		[6] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, -0.4469405710697174, 0.708892822265625),
		},
	} 

}