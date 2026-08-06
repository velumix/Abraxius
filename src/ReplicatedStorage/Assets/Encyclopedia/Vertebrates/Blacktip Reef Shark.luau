local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "blacktipreef", -- This is the what you set the _fishId arttibute to!
	Name = "Blacktip Reef Shark", -- The name of the fish that will show up in the book
	Aliases = { "Carcharhinus melanopterus" },
	Model = Assets["Blacktip Reef Shark"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://118337038064411",

	Family = "Carcharhinidae",
	Diet = "Small fish and crustaceans",
	Size = "2 m (6.6 ft)",
	Depths = "0-75 m (0-246 ft)",

	Facts = {
		"These sharks are named for the distinctive black tips on dorsal and caudal fins.",
		"Blacktip reef sharks are known to leap out of water while hunting.",
		"These sharks form small social groups of 4-6 individuals.",
		"Blacktip reef sharks are quick, reaching speeds of 20 mph (32 kmh) when hunting",
		"Blacktip reefs are one of the most common and recognizable sharks throughout the Indo-Pacific region.",
		"Juvenile blacktip reef sharks often live in shallow lagoons."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.003742218017578125, -5.777645111083984, -0.11065292358398438),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 8,
				[4] = 9,
			},
			["Position"] = Vector3.new(-0.01171112060546875, -2.8365478515625, -0.07123935222625732),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 7,
			},
			["Position"] = Vector3.new(-0.0221099853515625, -0.8546371459960938, -0.04467761516571045),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.039882659912109375, 2.5292091369628906, 0.0006663799285888672),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(-0.05190277099609375, 4.821601867675781, 0.031386733055114746),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(-0.06548309326171875, 7.385261535644531, 1.3089333772659302),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.023944854736328125, -0.5439033508300781, 2.172675609588623),
		},
		[8] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(1.7936782836914062, -1.5739555358886719, -1.405539870262146),
		},
		[9] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-1.7991371154785156, -1.5928153991699219, -1.4058609008789062),
		},
	}
}