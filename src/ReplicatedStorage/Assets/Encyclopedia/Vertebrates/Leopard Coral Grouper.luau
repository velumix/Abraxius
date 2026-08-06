local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "LeopardSpottedGrouper", -- This is the what you set the _fishId arttibute to!
	Name = "Leopard Coral Grouper", -- The name of the fish that will show up in the book
	Aliases = { "Plectropomus leopardus" },
	Model = Assets["Leopard Coral Grouper"],
	Icon = "",

	Family = "Epinephelidae",
	Diet = "Fish, Crustaceans, and Molluscks",
	Size = "120 cm (3.9 feet)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-100 m (3.3-328 ft)",

	Facts = {
		"These fish are known to cooperatively hunt with humphead wrasse, giant moray, and day octopus!",
		"When cooperatively hunting, these fish will attempt to signal to a partner by pointing to prey with a headstand.",
		"In Australia, leopard coral groupers are called coral trouts, likely due to their spots resembling those of a trout.",
		"Leopard coral groupers can live to be 16 years old.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0013580322265625, -2.9321441650390625, -0.05183899402618408),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 6,
				[4] = 7,
			},
			["Position"] = Vector3.new(0.00067138671875, -1.4570693969726562, -0.023903846740722656),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.000579833984375, -0.4387969970703125, -0.817294716835022),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.00026702880859375, 1.49224853515625, -0.8749865293502808),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(-0.0010986328125, 1.539764404296875, 0.8791490197181702),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 2,
			},
			["Position"] = Vector3.new(-0.000152587890625, -0.5059661865234375, 0.8404048681259155),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.000885009765625, -2.5476531982421875, 0.6432545781135559),
		},
	}
}