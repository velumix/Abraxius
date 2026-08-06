local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BlueButton", -- This is the what you set the _fishId arttibute to!
	Name = "Blue Button", -- The name of the fish that will show up in the book
	Aliases = { "Porpita porpita" },
	Model = Assets["Blue Button"],
	Icon = "",

	Family = "Porpitidae",
	Diet = "Zooplankton",
	Size = "3 cm (1.1 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "Surface",

	Facts = {
		"These small hydrozoans are a part of a community of animals that float on the ocean surface, known as the neuston!",
		"Blue buttons have quite long tentacles that they use to capture more mobile zooplankton.",
		"The circle structure on top of this animal is known as the float. It controls the animals boyancy and keeps it at the surface!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(-0.004302978515625, -0.011105500161647797, -0.00077056884765625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.3404693603515625, -0.011105496436357498, 0.2020416259765625),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.17303466796875, -0.011105500161647797, 0.353240966796875),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.258331298828125, -0.011105500161647797, -0.17920684814453125),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.196807861328125, -0.011105496436357498, -0.2979278564453125),
		},
	}
}