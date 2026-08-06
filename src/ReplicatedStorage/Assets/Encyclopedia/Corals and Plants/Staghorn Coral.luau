local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "StaghornCoral", -- This is the what you set the _fishId arttibute to!
	Name = "Staghorn Coral", -- The name of the fish that will show up in the book
	Aliases = { "Acropora sp." },
	Model = Assets["Staghorn Coral"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Acroporidae",
	Diet = "Photosynthetic and Filter-feeding",
	Size = "Various",
	Depths = "5-30 m (16-98 ft)",

    Facts = {
		"At over 180 species, there are more staghorn coral species than any other hard coral! These species are difficult to identify.",
		"These corals grow quite fast for a hard coral. They are often used in reef restoration.",
		"Many fish species are specially adapted to living within the branches of staghorn corals.",
    }

}