local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "goldmouthSeaSquirt", -- This is the what you set the _fishId arttibute to!
	Name = "Goldmouth Sea Squirt", -- The name of the fish that will show up in the book
	Aliases = { "Polycarpa aurata" },
	Model = Assets["Goldmouth Sea Squirt"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://133447685139659",
	
	Family = "Styelidae",
	Diet = "Plankton",
	Size = "15 cm (5.9 in)",
	Depths = "3-20 m (9.8-65.6 ft)",

    Facts = {
		"Sea squirts are chordates, the higher taxonomic group that contains vertebrates.",
		"Larval sea squirts are mobile and have a notochord, which is similar to a very primitive spinal chord. Some even swim like fish!",
		"There are many different species of sea squirts, and they are all shapes and sizes. Some are even predators!",
		"Sea squirts gained their name as they will expel water from their siphons when removed from the water.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.2848421633243561, 0.20599365234375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.3311559855937958, 0.1653289794921875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.20359347760677338, -0.2705841064453125),
		},
	}

}