local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Glaucus", -- This is the what you set the _fishId arttibute to!
	Name = "Blue Glaucus Sea Slug", -- The name of the fish that will show up in the book
	Aliases = { "Glaucus atlanticus" },
	Model = Assets["Blue Glaucus Sea Slug"],
	Icon = "",

	Family = "Glaucidae",
	Diet = "Flaoting cnidarians",
	Size = "3 cm (1.1 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "Surface",

	Facts = {
		"The blue glaucus is a bizarre nudibranch. The wing-like appendages act like gills, and the animal floats upside down!",
		"This slug feeds near exclusively on surface dwelling cnidarians such as blue buttons and man-o-war!",
		"Due to their diet, this nudibranch often inherets the venomous nature of its prey. It is advised to never touch one!",
		"Despite the scientific name of atlanticus, this species can be found in waters around the globe.",
		"The otherworldly look of these animals have given them several fitting names, such as the blue dragon, blue angel, or sea swallow!",
	},

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.073944091796875, 0.0014499872922897339),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.073944091796875, 0.0014499872922897339),
		},
	}
}