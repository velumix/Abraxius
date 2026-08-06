local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "FlameSnapper", -- This is the what you set the _fishId arttibute to!
	Name = "Flame Snapper",
	Aliases = { "Etelis coruscans" },
	Model = Assets["Flame Snapper"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Lutjanidae",
	Diet = "Fish and Squid",
	Size = "120 cm (47 in)",
	Depths = "45-400 m (147.6-1312.3 ft)",

	Facts = {
		"This fish usually inhabits waters deeper than 90 m (300 ft). Thus, the one seen here in the observatory is quite shallow!",
		"This fish is commonly targeted in deep-sea fisheries due to its pleasant taste.",
		"Perhaps the most striking feature of this deepwater snapper is its elongated tail fin, with the top lobe being longer than the bottom.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -2.4412765502929688, 0.17819523811340332),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -1.2498054504394531, 0.17558574676513672),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.3321876525878906, 0.1721172332763672),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 2.0554466247558594, 0.16834044456481934),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 4.677547454833984, -1.2987887859344482),
		},
	}
}