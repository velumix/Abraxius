local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "bottlenosewedge", -- This is the what you set the _fishId arttibute to!
	Name = "Bottlenose Wedgefish", -- The name of the fish that will show up in the book
	Aliases = { "Rhynchobatus australiae" },
	Model = Assets["Bottlenose Wedgefish"], -- ReplicatedStorage -> Assets -> FishModels 
	
	Icon = "",

	Family = "Rhinidae",
	Diet = "Small fish and invertebrates",
	Size = "3 m (10 ft)",
	Depths = "0-60 m (0-197 ft)",

	Facts = {
		"Bottlenose wedgefish are critically endangered. Many other wedgefish are also endangered due to unsustainable fishing.",
		"Despite looking like a strange looking shark, wedgefish are actually a ray!",
		"Wedgefish give birth by a method called ovoviparity. This is where the eggs develop and hatch in the mother, allowing live birth!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.000003814697265625, -4.654571533203125, 0.22551321983337402),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0, -1.7917709350585938, 0.23071694374084473),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(-4.0118865966796875, 0.38269805908203125, 0.32562804222106934),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(3.9740066528320312, 0.5605697631835938, 0.32595014572143555),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 6,
				[5] = 8,
			},
			["Position"] = Vector3.new(0, 4.218536376953125, -0.08081865310668945),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, 8.436172485351562, -0.07315230369567871),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0, 11.394515991210938, -0.0677722692489624),
		},
		[8] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, 5.7114105224609375, -2.9662587642669678),
		},
	}
}