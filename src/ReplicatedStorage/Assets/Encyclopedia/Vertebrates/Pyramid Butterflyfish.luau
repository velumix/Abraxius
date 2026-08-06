local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Pyramid_Butterflyfish", -- This is the what you set the _fishId arttibute to!
	Name = "Pyramid Butterflyfish", -- The name of the fish that will show up in the book
	Aliases = { "Hemitaurichthys polylepis" },
	Model = Assets["Pyramid Butterflyfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://134102034267517",
	
	Family = "Chaetodontidae",
	Diet = "Plankton",
	Size = "18 cm (7 in)",
	Depths = "3-60 m (9 - 196ft)",
	
    Facts = {
		"Pyramid butterflyfish are very social, being seen swimming around reefs in large groups.",
		"These fish are found in pairs during their breeding season.",
		"Pyramid butterflyfish prefer the steeper outer slopes of reefs. This is likely due to their planktonic diet.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 2.9802322387695312e-08, -0.25),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -2.9802322387695312e-08, 0.1999969482421875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -5.960464477539063e-08, 0.4647064208984375),
		},
	} 
}
