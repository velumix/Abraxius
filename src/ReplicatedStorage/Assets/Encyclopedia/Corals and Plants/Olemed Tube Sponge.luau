local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "TubeSponge", -- This is the what you set the _fishId arttibute to!
	Name = "Olemed Tube Sponge", -- The name of the fish that will show up in the book
	Aliases = { "Niphates olemda" },
	Model = Assets["Olemed Tube Sponge"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Niphatidae",
	Diet = "Plankton",
	Size = "Various",
	Depths = "8-25 m (26.2-82 ft)",

    Facts = {
		"Sponges have a free swimming larval stage that resembles a ball. They become sessile once a place to settle is found.",
		"Sponges are built up of small glass-like structures known as spicules. These are often used to identified them to species level!",
		"This sponge is found in the Indo-Pacific region, and is often grey and tubelike in shape and structure.",
    }

}