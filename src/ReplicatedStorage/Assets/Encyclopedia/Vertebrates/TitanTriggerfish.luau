local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "titanTrigger", -- This is the what you set the _fishId arttibute to!
	Name = "Titan Triggerfish", -- The name of the fish that will show up in the book
	Aliases = { "Balistoides viridescens" },
	Model = Assets["TitanTriggerfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Balistidae",
	Diet = "Invertebrates",
	Size = "75 cm (29.5 in)",
    Depths = "10-60 m (33-196 ft)",
	
    Facts = {
		"Titan triggerfish are notorious for their aggressive behavior, especially during nesting season.",
		"While nesting, they guard a cone-shaped territory and will fiercely chase away any animal that enters it.",
		"Titan triggerfish are also called moustache triggerfish, for the dark band that looks like a moustache above their lip.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, -0.19999313354492188, -1.7999992370605469),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.000008463859558105469, -2.200000762939453),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, -0.39999163150787354, -2.200000762939453),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
				[2] = 5,
				[3] = 7,
			},
			["Position"] = Vector3.new(0, -0.1999969482421875, -0.7999992370605469),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.20000243186950684, 0.6000022888183594),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, -0.20000827312469482, 2.1000022888183594),
		},
		[7] = {
			["Links"] = {
				[1] = 4,
				[2] = 8,
			},
			["Position"] = Vector3.new(0, 0.8000030517578125, -0.7999954223632812),
		},
		[8] = {
			["Links"] = {
				[1] = 7,
			},
			["Position"] = Vector3.new(0, 1.4000022411346436, -0.5999870300292969),
		},
	}

}