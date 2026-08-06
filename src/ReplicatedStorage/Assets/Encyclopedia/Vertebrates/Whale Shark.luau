local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "WhaleShark", -- This is the what you set the _fishId arttibute to!
	Name = "Whale Shark",
	Aliases = { "Rhincodon typus" },
	Model = Assets["Whale Shark"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://139474200524018",

	Family = "Rhincodontidae",
	Diet = "Plankton",
	Size = "18 m (59 ft)",
	Depths = "0-1928 m (0- 6325 ft)",

	Facts = {
		"The whale shark is the largest fish in the world, reaching lengths of up to 18 meters (59 feet).",
		"Despite their size, whale sharks are completely harmless to humans. They feed on small fish and planktonic organisms.",
		"Whale sharks are not whales. They are sharks, which are cartilaginous fish. Shark skeletons are made of flexible cartilage!",
		"Whale shark populations are often segregated by age and gender, likely due to differences in diet and habitat preferences.",
		"Individual whale sharks are distinguished by their spot patterns. Each shark has a unique one!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0000152587890625, -33.66667938232422, -2.049703598022461),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 8,
				[4] = 9,
				[5] = 10,
			},
			["Position"] = Vector3.new(-0.000011444091796875, -20.708084106445312, -1.995265007019043),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 7,
			},
			["Position"] = Vector3.new(-0.00000762939453125, 2.4384541511535645, -0.7798805236816406),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.000003814697265625, 16.224483489990234, -0.7219715118408203),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, 27.80028533935547, -0.673344612121582),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0.000003814697265625, 37.78428268432617, -14.483819007873535),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.000019073486328125, 4.667437553405762, -10.746939659118652),
		},
		[8] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-12.050186157226562, -15.224668502807617, 4.69527006149292),
		},
		[9] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(12.350639343261719, -15.224674224853516, 4.695278167724609),
		},
		[10] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.000030517578125, -33.53736114501953, 1.982351303100586),
		},
	}
}