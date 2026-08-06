local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "humpheadWrasseM", -- This is the what you set the _fishId arttibute to!
	Name = "Humphead Wrasse", -- The name of the fish that will show up in the book
	Aliases = { "Crassilabrus undulatus" },
	Model = Assets["Humphead Wrasse"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://97324293250040",
	
	Family = "Labridae",
	Diet = "Clams",
	Size = "2.29 m (7.5 ft)",
    Depths = "1-100 m (6-328 ft)",

    Facts = {
		"The humphead wrasse is the largest species of wrasse, weighing up to around 190 kilograms (418 lbs)!",
		"Humphead wrasse are also known as Māori wrasse or Napoleonfish.",
		"Male and female humphead wrasse look different from each other in both color and size. Males are much larger.",
		"These fish are born without their distinctive humps, with larger individuals developing them as they grow.",
		"The humphead wrasse is an endangered species. Reasons include unregulated and overfishing, and overcollecting for trade.",
		"An intellegent fish, humpheads have been observed coopertively hunting with groupers, recognizing divers, and using tools!",
		"Humphead wrasse are opportunistic predators, feeding on a large variety of fish and invertebrates, including some toxic ones!",
    },
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 2.5148940086364746, -4.774173736572266),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -1.4985852241516113, -2.8291015625),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 3.0860562324523926, -1.0025787353515625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -1.4355578422546387, 1.3670730590820312),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 1.584094524383545, 2.78350830078125),
		},
	}
}