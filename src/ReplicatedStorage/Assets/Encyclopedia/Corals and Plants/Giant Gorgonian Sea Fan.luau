local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SeaFan", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Gorgonian Sea Fan", -- The name of the fish that will show up in the book
	Aliases = { "Annella mollis" },
	Model = Assets["Giant Gorgonian Sea Fan"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Subergorgiidae",
	Diet = "Photosynthetic and Filter-feeding",
	Size = "2 m (6 ft)",
	Depths = "10-40 m (32.8-131.2 ft)",

    Facts = {
		"This species is a gorgonian, which is a type of soft coral. These differ from hard corals as they do not form hard limestone reefs.",
		"Polyps of gorgonians and soft corals have eight tentacles. This is where their class, Octocorallia, get their name.",
		"Gorgonians form their structure using a compound different than hard corals. This compound is called gorgonin.",
    }
}