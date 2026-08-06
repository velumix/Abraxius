local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "UrnSeaSquirt", -- This is the what you set the _fishId arttibute to!
	Name = "Green Barrel Sea Squirt", -- The name of the fish that will show up in the book
	Aliases = { "Didemnum molle" },
	Model = Assets["Green Urn Ascidian"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Didemnidae",
	Diet = "Plankton",
	Size = "10 cm (3.9 in)",
	Depths = "0-15 m (0-49.2 ft)",

    Facts = {
		"This sea squirt, like many other sessile animals, does not have one defined shape. Some are orb shaped, while some are long!",
		"This sea squirt can reproduce by budding, simply sprouting a new individual which drops off and becomes a new individual.",
		"The green color of this animal comes from the blue-green algae that lives in its tissues!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.31540971994400024, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.3154253363609314, 0),
		},
	}
}