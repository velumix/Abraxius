local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SpottedParrotfishF", -- This is the what you set the _fishId arttibute to!
	Name = "Spotted Parrotfish (Female)",
	Aliases = { "Cetoscarus ocellatus" },
	Model = Assets["Spotted Parrotfish (F)"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://81392767821507",

	Family = "Scaridae",
	Diet = "Algae",
	Size = "80 cm (31.5 in)",
	Depths = "0-40 m (0-131 ft)",

	Facts = {
		"Parrotfish utilize their sharp beaks to crunch the limestone skeletons of coral in order to eat the symbiotic algae within.",
		"Parrotfish defecate out coral limestone as fine white sand!",
		"Large male parrotfish in full breeding coloration are referred to as being in terminal phase.",
		"Female parrotfish are refered to as the initial phase, and are grey and yellow in the spotted parrotfish.",
		"Juveniles of spotted parrotfish are very distinct, being white with an orange head.",
		"The spotted parrotfish is also called the bicolour parrotfish. This name is also utilized by a related species in the Red Sea."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.2119879126548767, -1.5691757202148438),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.5131407976150513, -1.041595458984375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.393251895904541, -0.43193817138671875),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.4483758509159088, 0.24903106689453125),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 0.3196631669998169, 0.7313003540039062),
		},
	}
}