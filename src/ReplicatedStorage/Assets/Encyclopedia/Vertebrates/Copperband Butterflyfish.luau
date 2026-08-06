local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CopperbandButterfly", -- This is the what you set the _fishId arttibute to!
	Name = "Copperband Butterflyfish", -- The name of the fish that will show up in the book
	Aliases = { "Chelmon rostratus" },
	Model = Assets["Copperband Butterflyfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://131225051190009",

	Family = "Chaetodontidae",
	Diet = "Small Benthic Invertebrates",
	Size = "20 cm (7.9 in)",
	Depths = "1-25 m (3-82 ft)",

    Facts = {
		"Copperband butterflyfish are territorial and are usually found in groups of no more than two individuals.",
		"The long snout of the copperband is used to reach into crevices where other fish might not be able to reach.",
		"Copperband butterflyfish display an eyespot on the rear of their dorsal fin, thought to fool predators on the fish's orientation."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.09355983138084412, -0.5074462890625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.09355992078781128, -0.01146697998046875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.3283698856830597, 0.2712554931640625),
		},
	}
}