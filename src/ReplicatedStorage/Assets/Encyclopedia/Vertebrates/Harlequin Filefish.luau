local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "harlequinFile", -- This is the what you set the _fishId arttibute to!
	Name = "Harlequin Filefish", -- The name of the fish that will show up in the book
	Aliases = { "Oxymonacanthus longirostris" },
	Model = Assets["Harlequinfilefish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Monacanthidae",
	Diet = "Acropora polyps",
	Size = "12 cm (4.7 in)",
	Depths = "0-30 m (0-98 ft)",
	
    Facts = {
		"The vibrant coloration of the harlequin filefish helps to serve as camouflage among the coral where it inhabits.",
		"On average, the harlequin filefish reaches about 10 cm (around 4 inches) in length.",
		"The harlequin filefish has a retractable dorsal spine that it can use to wedge itself in crevices, helping it escape from threats.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.039274781942367554, -0.36107635498046875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, -0.03927481174468994, -0.18304443359375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.08004623651504517, -0.18304443359375),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.03927485644817352, 0.072509765625),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, -0.039274901151657104, 0.3473548889160156),
		},
	}
}