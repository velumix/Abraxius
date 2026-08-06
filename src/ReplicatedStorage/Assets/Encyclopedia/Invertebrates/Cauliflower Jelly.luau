local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "CauliflowerJelly", -- This is the what you set the _fishId arttibute to!
	Name = "Cauliflower Jelly", -- The name of the fish that will show up in the book
	Aliases = { "Cephea cephea" },
	Model = Assets["Cauliflower Jelly"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Cepheidae",
    Diet = "Zooplankton",
	Size = "Diameter 60 cm (1.96 ft)",
	Depths = "0-914 m (0-3000 ft)",
	
	Facts = {
		"The most distinct feature of this jelly is the crown of protrusions coming out of the bell. The use for these is uncertain.",
		"Not much is known about this jelly, but records in captivity have shown that it is a fast growing species!",
		"This species of jelly is edible and is considered a delicacy in some countries of south-east Asia.",
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
			["Position"] = Vector3.new(-0.025054931640625, -0.49839329719543457, -0.00006103515625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.7034378051757812, -1.5517089366912842, -0.0001678466796875),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-1.0251083374023438, -1.5517160892486572, -0.0001373291015625),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.0250701904296875, -1.5517079830169678, 0.99993896484375),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.02507781982421875, -1.5517098903656006, -1.000030517578125),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.02507781982421875, 0.9981107711791992, -1.450958251953125),
		},
		[7] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-1.6551132202148438, 0.9981038570404053, -0.000091552734375),
		},
		[8] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.02510833740234375, 0.9981014728546143, 1.4508056640625),
		},
		[9] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(1.60491943359375, 0.9981162548065186, -0.0000762939453125),
		},
	}
}