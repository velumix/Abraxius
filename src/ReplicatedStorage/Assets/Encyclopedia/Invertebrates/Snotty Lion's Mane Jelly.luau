local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SnottyJelly", -- This is the what you set the _fishId arttibute to!
	Name = "Snotty Lion's Mane Jelly", -- The name of the fish that will show up in the book
	Aliases = { "Cyanea barkeri" },
	Model = Assets["Snotty Lions Mane Jelly"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Cyaneidae",
    Diet = "Fish and Zooplankton",
	Size = "150 cm (4.9 ft)",
	Depths = "0-85 m (0-278 ft)",
	
	Facts = {
		"Most lion's mane jelly species occur in colder waters. This species is one of the few found exclusively in tropical areas!",
		"Other species of lions mane are the largest jellies in the world, having a width of up to 2 meters (6.5 ft) and length of 30 m (120 ft)!",
		"The true size of the snotty lions mane is unclear. Some report that they can get up to a meter (3.2 ft) wide.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
				[5] = 6,
				[6] = 7,
				[7] = 8,
				[8] = 9,
			},
			["Position"] = Vector3.new(0.0001220703125, 5.486622333526611, -0.1685791015625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-1.8264312744140625, 4.417327404022217, 1.5123672485351562),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(2.0311126708984375, 4.262519359588623, -1.9431495666503906),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-1.8503875732421875, 4.283544063568115, -1.8935317993164062),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(1.8866424560546875, 4.348669528961182, 1.5958747863769531),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.944854736328125, 1.0322823524475098, -0.1685791015625),
		},
		[7] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-1.0961456298828125, 1.0580658912658691, -0.1685791015625),
		},
		[8] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.0002593994140625, 1.2360148429870605, 0.80743408203125),
		},
		[9] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.000244140625, 1.3728032112121582, -1.1946830749511719),
		},
	}

}