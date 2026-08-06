local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BrainCoral", -- This is the what you set the _fishId arttibute to!
	Name = "Pacific Closed Brain Coral", -- The name of the fish that will show up in the book
	Aliases = { "Leptoria phrygia" },
	Model = Assets["Pacific Closed Brain Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Merulinidae",
	Diet = "Photosynthetic and Filter-feeding",
	Size = "Various",
	Depths = "3-15 m (10-49 ft)",

    Facts = {
		"These corals have their polyps aligned in valleys which give them their brain-like appearance.",
		"These corals are an example of a massive coral, which is a coral that is round or boulder shaped.",
		"Brain corals can come in many different colors, such as yellow, green, or beige.",
    }

}