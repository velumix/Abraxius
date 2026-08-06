local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "MangroveTree", -- This is the what you set the _fishId arttibute to!
	Name = "Spotted Mangrove", -- The name of the fish that will show up in the book
	Aliases = { "Rhizophora stylosa" },
	Model = Assets["Spotted Mangrove"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Rhizophoraceae",
	Diet = "Photosynthetic",
	Size = "15 m (50 ft)",
	Depths = "0-1 m (0-3.3 ft)",

    Facts = {
		"Mangrove seeds are known as propagules, and in some species, start growing before they even drop off the tree!",
		"Some mangroves have roots that stick out of the ground, called pneumatophores. These help them absorb nutrients and oxygen.",
		"Mangroves are specially adapted to their saltwater life, having traits to survive a rapidly changing environment.",
		"Unfortunately, mangrove forests are experiencing a rapid loss due to deforestation around their range.",
		"Mangroves are almost exclusively found in tropical areas around the globe. "
    }

}