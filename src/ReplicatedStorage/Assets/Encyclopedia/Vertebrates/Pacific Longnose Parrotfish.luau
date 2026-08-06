local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PLNParrot", -- This is the what you set the _fishId arttibute to!
	Name = "Pacific Longnose Parrotfish",
	Aliases = { "Hipposcarus longiceps" },
	Model = Assets["Pacific Longnose Parrotfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Scaridae",
	Diet = "Algae",
	Size = "60 cm (23.6 in)",
	Depths = "0-40 m (0-131 ft)",

	Facts = {
		"The scientific name of this fish roughly translates from Latin to horse parrotfish with a long head!",
		"Female Pacific longnose parrotfish are white to grey with bright yellow tails and pink dorsal fins. Males are the color seen here.",
		"Juvenile Pacific longnose parrotfish are grey and have a vivid orange stripe going down the length of their body.",
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