local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "FlamboyantCuttlefish", -- This is the what you set the _fishId arttibute to!
	Name = "Flamboyant Cuttlefish", -- The name of the fish that will show up in the book
	Aliases = { "Ascarosepion pfefferi" },
	Model = Assets["Flamboyant Cuttlefish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://95877002904842",

	Family = "Sepiidae",
    Diet = "Small Fish and Crustaceans",
	Size = "Mantle Length 8 cm (3.1 in)",
    Depths = "3-86 m (10-282 ft)",
	
    Facts = {
        "Flamboyant cuttlefish are one of three known poisonous cephalopods.",
		"These cuttlefish walk across the seabed with their bottom arms. It is one of only two cuttlefish known to do this!",
		"Cuttlefish have a hard, chambered internal structure known as a cuttlebone. They use this for buoyancy control.",
		"The shape of the cuttlebone in the flamboyant cuttlefish does not allow it to float for long. This is why it walks!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.177734375, 0.004560232162475586),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.1069488525390625, -0.0027441978454589844),
		},
	}

}