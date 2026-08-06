local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "LunartailBigeye", -- This is the what you set the _fishId arttibute to!
	Name = "Lunartail Bigeye",
	Aliases = { "Priacanthus hamrur" },
	Model = Assets["Lunartail Bigeye"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Priacanthidae",
	Diet = "Small Fish and Invertebrates",
	Size = "40 cm (15.7 cm)",
	Depths = "0-250 m (0-820.2 ft)",

	Facts = {
		"This species of bigeye can change color, from red to silver. It can even be silver with red stripes!",
		"Most bigeye species are some shade of red, likely due to their nocturnal nature.",
		"This bigeye species is similar to other species in its range, but can be distinguished by its more crecent-shaped tail."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.06254065036773682, -1.0605850219726562),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.380977988243103, -0.20731353759765625),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.12274563312530518, 0.50738525390625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, -0.19105970859527588, -0.2358551025390625),
		},
	}
}