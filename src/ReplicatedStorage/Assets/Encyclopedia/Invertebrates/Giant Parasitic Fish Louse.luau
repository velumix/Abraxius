local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "AbhorrentParasiticLoach", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Fish Louse", -- The name of the fish that will show up in the book
	Aliases = { "Anilocra gigantea" },
	Model = Assets["Giant Fish Louse"],
	Icon = "",

	Family = "Cymothoidae",
	Diet = "Fish",
	Size = "10 cm (3.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "45-400 m (147.6-1312.3 ft)",

	Facts = {
		"Some fish lice species specialize feeding only on one specific species of fish! This species perfers deepwater snappers as hosts.",
		"Fish lice are a species of isopod, a group that includes the common terrestrial animal known as roly-poly, woodlouse, or pill bug!",
		"Some species of parasitic isopod will crawl into the gills and replace their fish hosts tongue! This species likely does not do this.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.2163543701171875, -0.040747642517089844),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.012691497802734375, -0.06794166564941406),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.24346160888671875, 0.018045425415039062),
		},
	}
}