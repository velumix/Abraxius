local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "engineerGoby", -- This is the what you set the _fishId arttibute to!
	Name = "Engineer Goby", -- The name of the fish that will show up in the book
	Aliases = { "Pholidichthys leucotaenia" },
	Model = Assets["ConvictBlenny"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Pholidichthyidae",
	Diet = "Small invertebrates and fish",
	Size = "30 cm (12 in)",
	Depths = "3-30 m (9.8-98.4 ft)",
	
    Facts = {
		"The engineer goby is named for its industrious burrowing behavior and bottom-dwelling lifestyle.",
		"Despite its common name, it is not a goby; it's actually more closely related to cichlids and leaffishes.",
		"Juveniles engineer gobies are balck and white, mimicing the appearance of the venomous striped catfish. This protects them!"
	},
	
	Skeleton =  {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.04271582514047623, -0.9594573974609375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.0015813112258911133, -0.6436653137207031),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.0015813112258911133, -0.2118988037109375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.0015813112258911133, 0.19118881225585938),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.0015813112258911133, 0.6038436889648438),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, -0.0015813112258911133, 0.9676399230957031),
		},
	} 
}