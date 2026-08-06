local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "AdhesiveAnemone", -- This is the what you set the _fishId arttibute to!
	Name = "Adhesive Anemone", -- The name of the fish that will show up in the book
	Aliases = { "Cryptodendrum adhaesivum" },
	Model = Assets["Adhesive Anemone"],
	Icon = "",

	Family = "Thalassianthidae",
	Diet = "Plankton, as well as Photosynthesis",
	Size = "Radius of 30 cm (11.8 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-40 m (3.3-131 ft)",

	Facts = {
		"The adhesive anemone is also known as the pizza anemone due to the thick, crust-like outer rim!",
		"This anemone is popular in the aquarium trade for the amount of patterns and colors it has, as well as its small size.",
		"There is only one clownfish that uses this species. As such, this anemone may not desirable as a clownfish host!",
	},
}