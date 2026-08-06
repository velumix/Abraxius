local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "MagnificentAnemone", -- This is the what you set the _fishId arttibute to!
	Name = "Magnificent Anemone", -- The name of the fish that will show up in the book
	Aliases = { "Radianthus magnifica" },
	Model = Assets["Magnificent Anemone"],
	Icon = "rbxassetid://118558202174237",

	Family = "Stichodactylidae",
	Diet = "Plankton, as well as Photosynthesis",
	Size = "Radius of 1 meter (3.28 ft)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-40 m (3.3-131 ft)",

	Facts = {
		"The magnificent anemone hosts 12 different species of anemonefish across its range.",
		"The magnificent anemone is one of the largest anemone species in the world.",
		"Anemones are in the same taxonomic class as the reef-building colonial stony corals. This makes them very closely related.",
		"Much like their coral relatives, tropical anemones have symbiotic zooxanthellae."
	},
}