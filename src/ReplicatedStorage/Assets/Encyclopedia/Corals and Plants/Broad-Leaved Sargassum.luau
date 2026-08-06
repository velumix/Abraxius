local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Sargassum", -- This is the what you set the _fishId arttibute to!
	Name = "Broad-Leaved Sargassum", -- The name of the fish that will show up in the book
	Aliases = { "Sargassum fluitans" },
	Model = Assets["Broad-Leaved Sargassum"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://122125625561279",
	
	Family = "Sargassaceae",
	Diet = "Photosynthetic",
	Size = "Strand about 45 cm (17.7 in)",
	Depths = "0-1 m (0-3.3 ft)",

    Facts = {
		"Sargassum is a brown algae that is known for creating floating rafts in the open sea. Some never touch the seafloor!",
		"Sargassum rafts provide habitats for a wide variety of organisms, from endemic species to open sea visitors",
		"The Sargasso Sea in the Atlantic Ocean is named for its large quantity of floating sargassum patches.",
		"Sargassum is also known as gulfweed, and can wash up on shore in great quantities.",
		"When macroalgae like sargassum dies, it sinks down to the deepest depths, which is consumed by deep-sea scavengers! "
    }

}