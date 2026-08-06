local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BarrelSponge", -- This is the what you set the _fishId arttibute to!
	Name = "Indo-Pacific Giant Barrel Sponge", -- The name of the fish that will show up in the book
	Aliases = { "Xestospongia testudinaria" },
	Model = Assets["Indo-Pacific Giant Barrel Sponge"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Petrosiidae",
	Diet = "Plankton",
	Size = "100 cm (39.3 in)",
	Depths = "2-50 m (6-165 ft)",

    Facts = {
		"Barrel sponges are one of the largest sponges, and can live over 2000 years!",
		"Barrel sponges are important to reefs. They filter a lot of water while feeding over their long lives, which improves water quality.",
		"Sponges such as the barrel sponge can be affected from bleaching, much like corals. Despite this, they are not related.",
    }

}