local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PlateCoral", -- This is the what you set the _fishId arttibute to!
	Name = "Plate Coral", -- The name of the fish that will show up in the book
	Aliases = { "Montipora sp." },
	Model = Assets["Plate Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Acroporidae",
	Diet = "Photosynthetic and Filter-feeding",
	Size = "Various",
	Depths = "0-25 m (0-82 ft)",

    Facts = {
		"The polyps of these corals have the smallest corallite, or limestone skeleton, of any coral.",
		"These corals are very colorful, and have been known to be almost any color!",
		"Although being common on reefs in the Indian and Pacific Oceans, these corals are not present in the Atlantic Ocean.",
    }

}