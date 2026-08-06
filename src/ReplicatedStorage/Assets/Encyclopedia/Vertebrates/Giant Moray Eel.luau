local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "giantmorayEel", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Moray Eel", -- The name of the fish that will show up in the book
	Aliases = { "Gymnothorax javanicus" },
	Model = Assets["Giant Moray Eel"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://94292513288752",
	
	Family = "Muraenidae",
	Diet = "Fish",
	Size = "3 m (9.8 ft)",
	Depths = "0-50 m (0-164 ft)",
	
    Facts = {
		"The giant moray is one of the largest members of the moray eel family. It can weigh 30 kg (66 lbs).",
		"Giant morays are known to hunt cooperatively with coral groupers. They can chase out prey the groupers can not reach.",
		"Giant morays are widespread throughout the tropical Indo-Pacific, and are frequently encountered in outer parts of reefs",
		"Morays have a set of pharyngeal jaws, a “second set” of jaws located within its throat to help handle prey."
    },

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.000011444091796875, 2.9236392974853516, 0.27267730236053467),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.00002288818359375, 1.9189510345458984, 0.5927159786224365),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.000011444091796875, 1.3246936798095703, -0.048050880432128906),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.000011444091796875, 2.0287208557128906, -0.5483478307723999),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0.0000152587890625, 3.0049819946289062, -0.2654457092285156),
		},
	}
}