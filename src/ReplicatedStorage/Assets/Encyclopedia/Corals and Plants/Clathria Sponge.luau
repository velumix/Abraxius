local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Clathria", -- This is the what you set the _fishId arttibute to!
	Name = "Clathria Sponge", -- The name of the fish that will show up in the book
	Aliases = { "Clathria sp." },
	Model = Assets["Clathria Sponge"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Microcionidae",
	Diet = "Plankton",
	Size = "Various",
	Depths = "8-100 m (26.2-328 ft)",

    Facts = {
		"Sponges, such as this one, have many different shapes, even within the same species!",
		"Competition occurs even among sessile organisms. Clathria sponges have even been observed to outcompete corals for space! ",
		"Many sponges, such as Clathria, are fouling organsims. This means they build up on structures, often human made ones!",
    }

}