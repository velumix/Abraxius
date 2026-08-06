local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "FloweryFlounder", -- This is the what you set the _fishId arttibute to!
	Name = "Flowery Flounder", -- The name of the fish that will show up in the book
	Aliases = { "Bothus mancus" },
	Model = Assets["Flowery Flounder"],
	Icon = "",

	Family = "Bothidae",
	Diet = "Fish and Crustaceans",
	Size = "39 cm (15.3 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "3-150 m (9.8-492 ft)",

	Facts = {
		" Larval flounders look like a normal fish. As they grow, their eyes shift to one side. The side the eyes goes depends on the species.",
		"Flowery flounders are notable for just how far apart their eyes are, even compared to other flounders!",
		"These fish are masters of camoflauge, and can change their colors to blend in to the background.",
		"These flounders can swim using an up and down motion, but they can also crawl, slowly moving across the seabed.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.1963043212890625, -1.1835250854492188, 0.009936511516571045),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.7289962768554688, 0.11121368408203125, 0.09892193228006363),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.00319671630859375, 1.1835479736328125, 0.1726427972316742),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(-0.6788558959960938, 0.08954620361328125, 0.09745826572179794),
		},
	} 
}