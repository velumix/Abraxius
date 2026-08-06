local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "reefManta", -- This is the what you set the _fishId arttibute to!
	Name = "Reef Manta Ray", -- The name of the fish that will show up in the book
	Aliases = { "Mobula alfredi" },
	Model = Assets["Reef Manta Ray"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://106931335922963",

	Family = "Mobulidae",
	Diet = "Plankton",
	Size = "Wingspan 5 m (16.4 ft)",
	Depths = "1-120 m (3-394 ft)",
	
    Facts = {
		"The reef manta is the second largest species of ray in the world, just behind its closest relative, the giant oceanic manta.",
		"Manta rays are completely harmless to humans. They do not have a barb at the base of their tails.",
		"Reef mantas filter feed, consuming planktonic organisms. To help feed, they have two appendages called 'cephalic lobes'.",
		"The cephalic lobes on mantas make them the only vertebrate 'hexapods,' meaning they have three pairs of limbs!",
		"At night, large groups of reef mantas gather near the surface to feed, a behavior known as 'diel vertical migration'.",
		"Manta rays perform an 'underwater ballet,' gracefully twirling and spinning to scoop up large quantities of plankton.",
		"Manta rays are very curious, and have the largest brains of any fish!"
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
			["Position"] = Vector3.new(5.999999523162842, 0, 0),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(8.665138244628906, -3.725290298461914e-09, 0),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0, 6),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-4.76837158203125e-07, 0, -4.999998092651367),
		},
	}

}