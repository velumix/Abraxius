local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "RoyalSpoonbill", -- This is the what you set the _fishId arttibute to!
	Name = "Royal Spoonbill", -- The name of the fish that will show up in the book
	Aliases = { "Platalea regia" },
	Model = Assets["Royal Spoonbill"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://134387168594192",
	
	Family = "Threskiornithidae",
	Diet = "Small Animals",
	Size = "81 cm (2.6 ft)",
    Depths = "Shoreline",
	
    Facts = {
		"Royal spoonbills utilize coastal wetland environments such as mangroves and salt marshes for hunting and nesting.",
		"The bill of the spoonbill is swept back and forth in water until a prey item is detected, where it is then snapped up.",
		"Spoonbill nostrils are located high on the bill to allow them to breath when foraging with the end of the bill in water.",
		"Royal spoonbills gain a large head crest, yellow eyebrows, red eyes, and a white striped bill in the breeding season.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.7909640073776245, -1.421957015991211),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 1.414047360420227, -0.6674041748046875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 1.2183343172073364, -0.4084625244140625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.6965821981430054, -0.6943588256835938),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, 0.7755352258682251, -0.2531394958496094),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, 0.4219423532485962, 0.2819938659667969),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
				[2] = 8,
			},
			["Position"] = Vector3.new(0, 0.14921796321868896, 0.7821178436279297),
		},
		[8] = {
			["Links"] = {
				[1] = 7,
			},
			["Position"] = Vector3.new(0, -0.37107300758361816, 1.4210071563720703),
		},
	}
}