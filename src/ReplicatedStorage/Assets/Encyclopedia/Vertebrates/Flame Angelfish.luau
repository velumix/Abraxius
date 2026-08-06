local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "FlameAngelfish", -- This is the what you set the _fishId arttibute to!
	Name = "Flame Angelfish", -- The name of the fish that will show up in the book
	Aliases = { "Centropyge loriculus" },
	Model = Assets["FlameAngelSolo"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://133479901650207",

	Family = "Pomacanthidae",
    Diet = "Algae and Coral Polyps",
    Size = "15 cm (5.9 in)",
    Depths = "0-60 m (0-197 ft)",

	
    Facts = {
		"The flame angelfish is one of 35 marine angelfish species known collectively as pygmy angels.",
		"The small size and bright colors of these fish have made them a popular choice for many home aquariums.",
		"The shape of the stripes on the flame angelfish depends on region. In some areas, the stripes are completely absent!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.05342420935630798, -0.3382568359375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.053424254059791565, -0.02881622314453125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.11617511510848999, 0.16352081298828125),
		},
	}
}