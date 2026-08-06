local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "ScrollCoral", -- This is the what you set the _fishId arttibute to!
	Name = "Scroll Coral", -- The name of the fish that will show up in the book
	Aliases = { "Turbinaria sp." },
	Model = Assets["Scroll Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Dendrophylliidae",
	Diet = "Photosynthetic and Filter-feeding",
	Size = "Various",
	Depths = "0-15 m (0-49 ft)",

    Facts = {
		"These corals have many common names, such as scroll, disc, cup, or vase coral.",
		"Several species of scroll coral are listed as vulnerable to extinction, due to climate change and ocean acidification.",
		"These corals are one of many known as hermatypic corals. This means they are hard corals that build reefs!",
    }

}