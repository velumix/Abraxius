local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "pelagicthreshershark", -- This is the what you set the _fishId arttibute to!
	Name = "Pelagic Thresher Shark",
	Aliases = { "Alopias pelagicus" },
	Model = Assets["Pelagic Thresher Shark"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://89980414672312",

	Family = "Alopiidae",
	Diet = "Small Fish and Squid",
	Size = "4.3 m (14.1 ft)",
	Depths = "0-300 m (0-984 ft)",

	Facts = {
		"The pelagic thresher is known for its large whip-like tail, expressive face, and large eyes.",
		"Due to their large eyes, pelagic threshers are often mistaken with bigeye threshers. Bigeyes are typically found deeper.",
		"Threshers hunt using their tail like a whip. The force of this strike can incapacitate prey, making an easy meal!",
		"Pelagic thresher sharks are often seen breaching the surface at high speeds. The reason for this is debated, but still unknown."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.000003814697265625, -6.201290130615234, 0.12566614151000977),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 9,
				[4] = 10,
			},
			["Position"] = Vector3.new(0, -2.036304473876953, 0.0310516357421875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 8,
			},
			["Position"] = Vector3.new(0, 1.0234794616699219, -0.038458824157714844),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 4.29083251953125, -0.11268472671508789),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, 6.854930877685547, -0.17093801498413086),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, 10.869884490966797, -2.5613718032836914),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0.000003814697265625, 17.596332550048828, -5.247098922729492),
		},
		[8] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.9546165466308594, -3.0693163871765137),
		},
		[9] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-3.7856826782226562, -1.9934196472167969, 1.918752670288086),
		},
		[10] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(3.695587158203125, -1.9934196472167969, 1.9187545776367188),
		},
	}
}