local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Favia", -- This is the what you set the _fishId arttibute to!
	Name = "Favia Coral", -- The name of the fish that will show up in the book
	Aliases = { "Dipsastraea favus" },
	Model = Assets["Favia Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Merulinidae",
	Diet = "Photosynthetic and Filter-feeding",
	Size = "Various",
	Depths = "0-50 m (0-164 ft)",

    Facts = {
		"Favia are known to be agressive, stinging and even killing other corals growing too close to ensure they have enough space!",
		"Favia have sweeper tentacles, which are longer tentacles that extend farther from the polyps than their typical tentacles.",
		"The classification of this coral is debated. Some sources put it in the Favia genus, while others use Dipsastrea.",
    }

}