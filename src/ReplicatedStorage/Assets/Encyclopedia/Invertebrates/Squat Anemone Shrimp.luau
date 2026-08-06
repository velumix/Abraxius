local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SeggzyShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Squat Anemone Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Thor amboinensis" },
	Model = Assets["Squat Anemone Shrimp"],
	Icon = "",

	Family = "Thoridae",
	Diet = "Detritus",
	Size = "1 cm (0.4 in)",
	Depths = "1-60 m (3.3-196.8 ft)",

	Facts = {
		"This shrimp is known for its dancing behavior, where it flicks its abdomen! It has a rather humorous alternate name because of it.",
		"The genus of this shrimp is named after Thor, the norse god of thunder!",
		"This shrimp was once thought to be a cosmopolitan species, but recent research has shown that Atlantic ones are a different one!",
		"This shrimp is almost always found living in or on anemones, as they are commensal residents of them."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0000152587890625, -0.035907745361328125, -0.04738426208496094),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.0000152587890625, -0.02271270751953125, 0.011564254760742188),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0000152587890625, 0.09278488159179688, -0.00370025634765625),
		},
	} 
}