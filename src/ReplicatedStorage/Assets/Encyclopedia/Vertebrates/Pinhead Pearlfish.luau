local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PinheadPearlfish", -- This is the what you set the _fishId arttibute to!
	Name = "Pinhead Pearlfish", -- The name of the fish that will show up in the book
	Aliases = { "Encheliophis boraborensis" },
	Model = Assets["Pinhead Pearlfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Carapidae",
	Diet = "Invertebrates",
	Size = "30 cm (11.8 in)",
	Depths = "0-110 m (0-360.9 ft)",
	
    Facts = {
		"Pearlfish live inside the guts of sea cucumbers. Some species do not harm the cucumber, while others are parasitic to them.",
		"Pinhead pearlfish are known to compete for sea cucumbers with other pearlfish, with some interactions breaking out in fights!",
		"Pearlfish make a wide variety of noises! Some species create a dinging sound, while others knock!",
		"Some pearlfish will enter sea cucumbers tail first, slowly backing into their living home.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0089874267578125, -0.211029052734375, 0.023062586784362793),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.0089874267578125, 0.306915283203125, 0.007742941379547119),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.0089874267578125, 0.9338912963867188, 0.007742762565612793),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.0089874267578125, 1.4613113403320312, 0.002531588077545166),
		},
	}
}