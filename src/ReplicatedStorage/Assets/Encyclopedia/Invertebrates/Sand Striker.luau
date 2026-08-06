local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SandStriker", -- This is the what you set the _fishId arttibute to!
	Name = "Sand Striker", -- The name of the fish that will show up in the book
	Aliases = { "Eunice aphroditois" },
	Model = Assets["Sand Striker"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://119244603981810",

	Family = "Eunicidae",
    Diet = "Fish",
	Size = "3 m (9.8 ft)",
    Depths = "1-200 m (3-656 ft)",
	
    Facts = {
		"The sand striker is part of a group of marine worms known as the polychaetes, meaning 'many hairs'.",
		"The mandibles, or 'jaws', of this worm can be retracted, and are typically only visible when the worm is poised to feed.",
		"These worms are efficient ambush predators, utilizing their 5 antenna to sense prey swimming by.",
		"Sand strikers sometimes sneak into aquariums through live rocks. Even a large worm can be undetected for some time!",
		"Despite growing to great lengths, these worms do not get much wider than 2.5 cm (1 in)."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.493072509765625, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.006927490234375, 0),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.506927490234375, 0),
		},
	}

}