local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Emperor Angelfish", -- This is the what you set the _fishId arttibute to!
	Name = "Emperor Angelfish",
	Aliases = { "Pomacanthus imperator" },
	Model = Assets["Emperor Angelfish"], -- ReplicatedStorage -> Assets -> FishModels

	Icon = "rbxassetid://122704095219505",

	Family = "Pomacanthidae",
	Diet = "Sponges, Algae, and Small Invertebrates",
	Size = "40 cm (16 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-100 m (3-330 ft)",

	Facts = {
		"Juvenile emperor angelfish look quite different from adults. They are dark blue color with curved blue and white stripes.",
		"Emperor angelfish differ by region. Fish from the Indo-Pacific have a dorsal fin filament, those from the Indian Ocean do not.",
		"While angelfish may look like butterflyfish to some, the main difference is the presence of a spine on the gill in angelfish.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.058477818965911865, -1.0777969360351562),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, 0.05847764015197754, -0.08863067626953125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.05847746133804321, 0.8718490600585938),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.5917971730232239, 0.5936355590820312),
		},
	}
}