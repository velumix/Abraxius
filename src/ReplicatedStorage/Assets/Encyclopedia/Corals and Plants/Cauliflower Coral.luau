local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CauliCoral", -- This is the what you set the _fishId arttibute to!
	Name = "Cauliflower Coral", -- The name of the fish that will show up in the book
	Aliases = { "Pocillopora sp." },
	Model = Assets["Cauliflower Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Pocilloporidae",
	Diet = "Photosynthetic and Filter-feeding",
	Size = "Up to 30 cm (11.8 in) tall",
	Depths = "3-20 m (10-66 ft)",

    Facts = {
		"These corals are quite popular in the aquarium trade, as they are one of the easier corals to care for.",
		"Much like other corals, the polyps of this coral are often retracted during the day, emerging at night to feed.",
		"These corals are quite common in many shallow water environments, being found from reefs to mangroves, and even wharfs!",
    }

}