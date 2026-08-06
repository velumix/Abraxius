local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "pacificSardine", -- This is the what you set the _fishId arttibute to!
	Name = "Pacific Sardine", -- The name of the fish that will show up in the book
	Aliases = { "Sardinops sagax" },
	Model = Assets["Pacific Sardine"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://91251082526126",
	
	Family = "Spratelloididae",
	Diet = "Plankton",
	Size = "7 cm (2.8 in)",
	Depths = "0-50 m (0-164 ft)",
	
    Facts = {
		"These small fish are known by a variety of names such as pilchards, sardines, and blue-baits.",
		"Pacific sardines are prey items for many creatures, including humans. Sardines make up a large commercial fishery.",
		"The tendancy of sardine schools to tightly pack and attract larger predators has made the formations known as bait-balls."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 2.000000238418579, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.25, -3.5),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -2.25, -0.25),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, 0.25, 2.75),
		},
	}

}