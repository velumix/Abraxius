local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Antipathes", -- This is the what you set the _fishId arttibute to!
	Name = "Branching Black Coral", -- The name of the fish that will show up in the book
	Aliases = { "Antipathes sp." },
	Model = Assets["Antipathes Black Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Antipathidae",
	Diet = "Filter-feeding",
	Size = "Various",
	Depths = "18-300 m (59-984 ft)",

    Facts = {
		"These corals are known as black corals for the color of their skeleton. The actual polyps can be red, white, yellow, or brown!",
		"While Antipathes itself is relatively shallow, black corals can be found in all zones of the ocean!",
		"The skeleton of black corals are often used in jewelry making.",
    }
}