local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CarnationCoral", -- This is the what you set the _fishId arttibute to!
	Name = "Carnation Coral", -- The name of the fish that will show up in the book
	Aliases = { "Dendronephthya sp." },
	Model = Assets["Carnation Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Nephtheidae",
	Diet = "Filter-feeding",
	Size = "Various",
	Depths = "1-50 m (3-164 ft)",

    Facts = {
		"Carnation corals are an important habitat for many animals. One, the pygmy seahorse, has even adapted to look just like them!",
		"These soft corals do not need light to grow, but are very difficult to keep in an aquarium due to their filter-feeding nature.",
		"There are over 250 species of carnation corals found across the world.",
    }
}