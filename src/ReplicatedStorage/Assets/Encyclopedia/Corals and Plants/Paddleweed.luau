local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Paddleweed", -- This is the what you set the _fishId arttibute to!
	Name = "Paddleweed", -- The name of the fish that will show up in the book
	Aliases = { "Halophila ovalis" },
	Model = Assets["Paddleweed"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Hydrocharitaceae",
	Diet = "Photosynthetic",
	Size = "5 cm (1.9 in)",
	Depths = "0-15 m (0-49 ft)",

    Facts = {
		"Seagrasses are flowering plants! Their flowers even get pollinated by ocean pollinators such as amphipods!",
		"This species of seagrass is common in shallow tropical Indo-Pacific waters, and is identified by its upright oval shaped leaves.",
		"Halophila, the genus of this seagrass, means salt lover. It is commonly eaten by dugongs.",
    }

}