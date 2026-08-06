local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Lousefish", -- This is the what you set the _fishId arttibute to!
	Name = "Lousefish", -- The name of the fish that will show up in the book
	Aliases = { "Phtheirichthys lineatus" },
	Model = Assets["Lousefish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Echeneidae",
	Diet = "Detritus",
	Size = "76 cm (29.9 in)",
	Depths = "0-50 m (0-164 ft)",
	
    Facts = {
		"This suckerfish species is incredibly rare with little information known about it. It seems to prefer barracudas as hosts.",
		"The strange pad used to latch onto other animals in these fish is actually a modified dorsal fin!",
		"The family, Echeneidae, translates from Greek to 'to hold a ship'. This refers to a creature of legend that was likely one of these!",
		"Some suckerfish are known to attach to humans! Reports describe them attaching as feeling like a strong, but not painful suction.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 0.1543501913547516, -1.6272506713867188),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.1605682373046875, 0.10107439756393433, -1.9361190795898438),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.0009765625, 0.028533518314361572, -2.2261505126953125),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(-0.186553955078125, 0.09242108464241028, -1.93011474609375),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, 0.08404076099395752, -0.13831329345703125),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, 0.03168627619743347, 2.0044403076171875),
		},
	}
}