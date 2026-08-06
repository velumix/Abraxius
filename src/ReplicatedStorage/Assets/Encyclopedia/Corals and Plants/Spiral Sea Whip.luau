local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SpiralWhip", -- This is the what you set the _fishId arttibute to!
	Name = "Spiral Sea Whip", -- The name of the fish that will show up in the book
	Aliases = { "Cirrhipathes spiralis" },
	Model = Assets["Spiral Sea Whip"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Antipathidae",
	Diet = "Filter-feeding",
	Size = "Various",
	Depths = "15-475 m (49.2-1558.4 ft)",

    Facts = {
		"Some fish live their entire lives on whip corals, notably Bryaninops gobies, camouflaged by their small size and transparent nature.",
		"The unique spiral shape of this coral is seen in many different related species. Some whip corals are even straight!",
		"Sea whips are a species of black coral!",
    }
}