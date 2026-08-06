local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "HumpbackGrouper", -- This is the what you set the _fishId arttibute to!
	Name = "Humpback Grouper", -- The name of the fish that will show up in the book
	Aliases = { "Cromileptes altivelis" },
	Model = Assets["Humpback Grouper"],
	Icon = "",

	Family = "Epinephelidae",
	Diet = "Anything Able to Fit in Mouth",
	Size = "70 cm (27.5 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-40 m (3.3-131 ft)",

	Facts = {
		"This grouper is born female, but it can change into a male as it gets older. Many grouper species do this!",
		"The humpback grouper lives in clear lagoon and reef waters, preferring areas with dead coral or silty conditions.",
		"In some regions, the humpback grouper has yellow tipped fins!",
		"This grouper has many other common names, such as the barramundi cod, panther grouper, and polka-dot grouper."
	},
}