local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "reefTrigger", -- This is the what you set the _fishId arttibute to!
	Name = "Reef Triggerfish", -- The name of the fish that will show up in the book
	Aliases = { "Rhinecanthus rectangulus" },
	Model = Assets["Reef Triggerfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://116857337369632",
	
	Family = "Balistidae",
	Diet = "Invertebrates",
	Size = "30 cm (11.8 in)",
    Depths = "10-20 m (33-65 ft)",
	
    Facts = {
		"The reef trigger is the state fish of Hawaii, where it is known as the humuhumunukunukuāpuaʻa.",
		"Humuhumunukunukuāpuaʻa is a Hawaiian word meaning 'triggerfish with a pig-like snout'.",
		"Triggerfish get their name by their dorsal fin spine, which can be flicked like a trigger to wedge themselves into crevices.",
		"Reef triggerfish have sturdy, blocky teeth used for crushing shells.",
		"Triggerfish are territorial towards anything that gets too close, including their own kind! Nesting amplifies territoriality."
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