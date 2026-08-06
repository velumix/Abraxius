local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PurpleQueen", -- This is the what you set the _fishId arttibute to!
	Name = "Purple Queen Anthias", -- The name of the fish that will show up in the book
	Aliases = { "Mirolabrichthys tuka" },
	Model = Assets["Purple Queen Anthias"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Anthiadidae",
	Diet = "Zooplankton",
	Size = "12 cm (4.7 in)",
	Depths = "7-40 m (22.9 - 131.2 ft)",

    Facts = {
		"The elongated beak-like snout on this fish is a feature only seen in males! Females have similar coloration, but lack the beak.",
		"Anthias are one of many fish that can change from female to male, with each group of females having one dominant male.",
		"Anthias are in the same family as the groupers!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.00827518105506897, -0.34427642822265625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.00827518105506897, -0.08345794677734375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.15736263990402222, 0.1627044677734375),
		},
	}
}