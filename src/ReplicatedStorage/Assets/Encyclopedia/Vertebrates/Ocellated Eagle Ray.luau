local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "ocellatedEagle", -- This is the what you set the _fishId arttibute to!
	Name = "Ocellated Eagle Ray", -- The name of the fish that will show up in the book
	Aliases = { "Aetobatus ocellatus" },
	Model = Assets["Ocellated Eagle Ray"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = " Aetobatidae",
	Diet = "Molluscs, Crustaceans, and Fish",
	Size = "Wingspan 3 m (9.8 ft)",
	Depths = "1-100 m (3-328 ft)",
	
    Facts = {
		"Occelated eagle rays are notable for their incredibly long tail, which can be nearly 3 times the length of their body!",
		"Occelated eagle rays were once considered to be a single global species, but have since been split into 3 species.",
		"These rays are an endangered species, facing threats from fishing and habitat destruction.",
		"Eagle rays have a stinging barb on near the base of their long tail, used for defense!",
		"These rays sift through sand when feeding, utilizing thier flexible upper lip to dig up crustaceans and mollusks.",
		"Eagle rays can be surprisingly fast and nimble, even being known to jump out of the water!",
	},
	
	Skeleton =  {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.00000762939453125, -6.064949035644531, 0.4806591272354126),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.00000762939453125, -3.6927413940429688, -0.7288005352020264),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 7,
				[4] = 8,
			},
			["Position"] = Vector3.new(0, -0.6861572265625, -0.6067678928375244),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 3.0738601684570312, 0.04045093059539795),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, 7.057075500488281, 0.014899373054504395),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, 13.372451782226562, -0.025623202323913574),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(7.121002197265625, -0.6803741455078125, 0.29438817501068115),
		},
		[8] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-7.3367156982421875, -0.680389404296875, 0.294391393661499),
		},
	}

}