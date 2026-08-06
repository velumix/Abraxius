local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "MauveStinger", -- This is the what you set the _fishId arttibute to!
	Name = "Mauve Stinger", -- The name of the fish that will show up in the book
	Aliases = { "Pelagia noctiluca" },
	Model = Assets["Mauve Stinger"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Pelagiidae",
    Diet = "Plankton",
	Size = "12 cm (4.7 in)",
	Depths = "0-1600 m (0-5249 ft)",
	
	Facts = {
		"This jelly is bioluminescent! It flashes a dim light when disturbed by wave action.",
		"There are records of a glowing jelly dating back to writings from the Roman Empire, likely referring to this species!",
		"The distribution of the true mauve stinger is unclear, as it is likely there are many similar species of jelly around the globe!",
		"The mauve stinger is one of the most studied jellies, as it is known to cause huge swarms that disrupt tourism and fish farms.",
		"This jelly is known by a variety of names, from the night-light jelly to the purple people eater!",
	},
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0, -0.2709076404571533, -0.0037689208984375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.2211456298828125, 0.8907591700553894, -0.0037841796875),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.253875732421875, 0.8938109278678894, -0.00377655029296875),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.9390990138053894, 0.2238922119140625),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.9275862574577332, -0.2276611328125),
		},
	} 
}