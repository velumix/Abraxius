local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "RegalAngel", -- This is the what you set the _fishId arttibute to!
	Name = "Regal Angelfish",
	Aliases = { "Pygoplites diacanthus" },
	Model = Assets["Regal Angelfish"], -- ReplicatedStorage -> Assets -> FishModels
	Icon = "",

	Family = "Pomacanthidae",
	Diet = "Sponges and Tunicates",
	Size = "25 cm (9.8 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-110 m (3-360 ft)",

	Facts = {
		"Regal angels are generally solitary fish, preferring to live alone or in bonded pairs.",
		"The regal angelfish is a picky eater, feeding almost entirely on sponges and tunicates. It is not a good aquarium fish as a result.",
		"These angels are often seen swimming near caves or crevices, with juveniles specifically often using them as shelter.",
	},
}