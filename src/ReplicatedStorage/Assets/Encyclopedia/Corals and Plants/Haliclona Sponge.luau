local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Haliclona", -- This is the what you set the _fishId arttibute to!
	Name = "Haliclona Sponge", -- The name of the fish that will show up in the book
	Aliases = { "Haliclona sp." },
	Model = Assets["Haliclona"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Chalinidae",
	Diet = "Plankton",
	Size = "Various",
	Depths = "8-1000 m (26.2-3280 ft)",

    Facts = {
		"Like many other sponges, it is very difficult to identify Haliclona to species level without a microscope to inspect structure.",
		"These sponges are a food source for nudibranch of the Jorunna genus, better known as sea bunnies! ",
		"Haliclona sponges can be found at a variety of depths, with some being found well under 1000 meters!",
    }
}