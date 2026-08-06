local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "OrangeClownfish", -- This is the what you set the _fishId arttibute to!
	Name = "Orange Clownfish",
	Aliases = { "Amphiprion percula" },
	Model = Assets["Orange Clownfish"], -- ReplicatedStorage -> Assets -> FishModels
	Icon = "rbxassetid://106080295025129",

	Family = "Pomacentridae",
	Diet = "Algae, Plankton, and Small Invertebrates",
	Size = "11 cm (4.7 in)",
	Depths = "1-15 m (3-49 ft)",

	Facts = {
		"The orange clownfish is very similar to the related occelaris clownfish, but has thicker black striping on the fins.",
		"Clownfish groups have a social hierarchy, with the females being the largest, and the second largest is the dominant male.",
		"Orange clownfish are symbiotically associated with several species of anemones, which provide them protection.",
		"There are several different captive bred morphs of these clownfish, making their patterning vary significantly."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.00016021728515625, -0.157073974609375, 0.04587574303150177),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.0002288818359375, -0.15836334228515625, -0.07594279944896698),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 1,
			},
			["Position"] = Vector3.new(0.00014495849609375, 0.1746826171875, -0.015342548489570618),
		},
	}
}