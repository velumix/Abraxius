local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "ZebraSharkJUV", -- This is the what you set the _fishId arttibute to!
	Name = "Zebra Shark (Juvenile)",
	Aliases = { "Stegostoma tigrinum" },
	Model = Assets["ZebraShark"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Stegostomatidae",
	Diet = "Small Fish and Invertebrates",
	Size = "250 cm (8.2 ft)",
	Depths = "1-90 m (3-295 ft)",

	Facts = {
		"Zebra sharks get their names from their stripey zebra-like patterns as pups.",
		"Female zebra sharks are able to reproduce asexually via a process known as parthenogenesis",
		"Just like other members of the carpet shark family, zebra sharks lay large egg cases."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.1558837890625, -1.999969482421875, -0.000004410743713378906),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.28733062744140625, -1.4405975341796875, -0.1992238163948059),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.41187286376953125, -0.956573486328125, 0.15245550870895386),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.411865234375, -0.4257049560546875, -0.18394380807876587),
		},
	}
}