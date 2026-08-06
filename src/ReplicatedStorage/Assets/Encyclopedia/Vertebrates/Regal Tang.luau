local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "regalTang", -- This is the what you set the _fishId arttibute to!
	Name = "Regal Tang", -- The name of the fish that will show up in the book
	Aliases = { "Paracanthurus hepatus" },
	Model = Assets["Regal Tang"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://122500400789616",
	
	Family = "Acanthuridae",
	Diet = "Plankton",
	Size = "Up to 31 cm",
    Depths = "2-40m (6-131ft)",

    Facts = {
		"The regal tang is also called “blue tang”, but there are multiple other species that share this common name",
		"Rather unusually among surgeonfishes, regal tangs feed primarily on plankton.",
		"This fish's cells do not contain any blue pigment. The color is a result of microscopic interference with visible light."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 4.172325134277344e-07, -0.7979965209960938),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.32412195205688477, -0.22479248046875),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.28431475162506104, -0.232757568359375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, 0.005359292030334473, 0.4434356689453125),
		},
	}

}