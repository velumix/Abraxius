local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SpottedParrotfishM", -- This is the what you set the _fishId arttibute to!
	Name = "Spotted Parrotfish (Male)",
	Aliases = { "Cetoscarus ocellatus" },
	Model = Assets["Spotted Parrotfish (M)"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://115849003307780",

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
			["Position"] = Vector3.new(0, 0.07664503157138824, -2.0821614265441895),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.6370272636413574, -1.03253173828125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.16094893217086792, -0.18897272646427155),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.6333016753196716, 0.6818923950195312),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 0.10838092863559723, 1.346873164176941),
		},
	}
}