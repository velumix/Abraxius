local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "RTDolphin", -- This is the what you set the _fishId arttibute to!
	Name = "Rough-toothed Dolphin", -- The name of the fish that will show up in the book
	Aliases = { "Steno bredanensis" },
	Model = Assets["Rough-toothed Dolphin"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Delphinidae",
	Diet = "Fish and Squid",
	Size = "2.8 m (9.2 ft)",
	Depths = "0-70 m (0-229 ft)",
	
    Facts = {
		"These dolphins were named for ridges that are seen on their teeth, something that is not seen in any other dolphin.",
		"These dolphins are found in deeper oceanic waters in groups of up to 20 individuals, though can be found in larger groups.",
		"Rough-toothed dolphins sometimes group with other species such as humpback whales, false killer whales, and even tuna!",	
		"These dolphins have been known to investigate inflated pufferfish. Despite some claims, this is likely just due to curiousity.",
		"Despite what many people think, dolphins are whales! They are a member of the toothed whales.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 5.822456359863281, -0.35037899017333984),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 9,
				[4] = 10,
			},
			["Position"] = Vector3.new(0, 2.9883956909179688, 0.10284531116485596),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 8,
			},
			["Position"] = Vector3.new(0, -0.13085174560546875, 0.25374794006347656),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -2.7726898193359375, 0.007112741470336914),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
				[3] = 7,
			},
			["Position"] = Vector3.new(0, -6.4532470703125, -0.598835825920105),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(-1.5372772216796875, -7.464149475097656, -0.5988351106643677),
		},
		[7] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(1.5454254150390625, -7.451225280761719, -0.5988363027572632),
		},
		[8] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, -1.1363143920898438, 2.4133248329162598),
		},
		[9] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-1.2052459716796875, 1.78753662109375, -1.4612557888031006),
		},
		[10] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(1.1609649658203125, 1.7597122192382812, -1.4612568616867065),
		},
	}
}