local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "RStonefish", -- This is the what you set the _fishId arttibute to!
	Name = "Reef Stonefish", -- The name of the fish that will show up in the book
	Aliases = { "Synanceia verrucosa" },
	Model = Assets["Reef Stonefish"],
	Icon = "",

	Family = "Synanceiidae",
	Diet = "Fish and Crustaceans",
	Size = "40 cm (15.7 in)",
	Depths = "0-30 m (0-98.4 ft)",

	Facts = {
		"This is the most venomous fish in the world! Accidental stings are fairly common and incredibly painful, but there is antivenom.",
		"Stonefish are masters of disguise. They can even be colors like pink, orange, or black to help improve their camouflage.",
		"These fish strike their prey with incredible speeds. It is fast enough to need a high speed camera to properly view!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -1.0214385986328125, -0.26871567964553833),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.6275100708007812, 0.3325245678424835),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.07561492919921875, -0.2719777226448059),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.6227874755859375, 0.23160222172737122),
		},
	}
}