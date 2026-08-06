local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PTurtleGrass", -- This is the what you set the _fishId arttibute to!
	Name = "Pacific Turtlegrass", -- The name of the fish that will show up in the book
	Aliases = { "Thalassia hemprichii" },
	Model = Assets["Pacific Turtlegrass"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Hydrocharitaceae",
	Diet = "Photosynthetic",
	Size = "7 cm (2.7 in)",
	Depths = "0-7 m (0-24 ft)",

    Facts = {
		"Seagrass have a system of interconnected underground roots, called rhizomes. This keeps them anchored to the seafloor.",
		"Meadows of this seagrass species are an important food item for green sea turtles.",
		"Seagrasses can store carbon, and are being investigated by several organizations as a way to help carbon emmisions.",
    }

}