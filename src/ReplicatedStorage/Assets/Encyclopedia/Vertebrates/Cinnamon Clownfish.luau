local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CinnamonClownfish", -- This is the what you set the _fishId arttibute to!
	Name = "Cinnamon Clownfish",
	Aliases = { "Amphiprion melanopus" },
	Model = Assets["Cinnamon Clownfish"], -- ReplicatedStorage -> Assets -> FishModels
	Icon = "",

	Family = "Pomacentridae",
	Diet = "Algae, Plankton, and Small Invertebrates",
	Size = "12 cm (4.7 in)",
	Depths = "1-20 m (3-65 ft)",

	Facts = {
		"This species of clownfish is most often seen using bubbletip anemones in the wild.",
		"The Fiji anemonefish, a separate species, was long thought to simply be a color morph of the cinnamon clownfish.",
		"When the dominant female clownfish in an anemone dies, the next largest male will turn to female!",
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