local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "stripedMarlin", -- This is the what you set the _fishId arttibute to!
	Name = "Striped Marlin",
	Aliases = { "Kajikia audax" },
	Model = Assets["Striped Marlin"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://75334894553406",

	Family = "Istiophoridae",
	Diet = "Fish and Squid",
	Size = "4.2 m (13.7 ft)",
	Depths = "0-200 m (0-656 ft)",

	Facts = {
		"Striped marlin can change colors when excited, flaring their stripes from a dark blue to a vivid white!",
		"These fish are known to exhibit dial migration, staying deep during the day and surfacing at night.",
		"The long bill of the striped marlin is utilized in hunting, slashing at prey. They do not stab prey.",
		"Marlin are among the fastest fish, but the reported top speeds they can reach are highly exaggerated."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -12.98353099822998, 0.48749494552612305),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 9,
			},
			["Position"] = Vector3.new(0, -6.265801429748535, 0.3002963066101074),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 9,
			},
			["Position"] = Vector3.new(0, -1.7480669021606445, 0.17440509796142578),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 2.420259475708008, 0.05824756622314453),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, 6.531848907470703, -0.05632448196411133),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
				[3] = 8,
			},
			["Position"] = Vector3.new(0, 9.745018005371094, -0.14586448669433594),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0, 12.932497024536133, -3.7291059494018555),
		},
		[8] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0, 12.735586166381836, 4.481444358825684),
		},
		[9] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -3.39013671875, -3.9088354110717773),
		},
	}
}