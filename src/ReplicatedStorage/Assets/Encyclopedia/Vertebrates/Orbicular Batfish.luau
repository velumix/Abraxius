local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Orbicular Batfish", -- This is the what you set the _fishId arttibute to!
	Name = "Orbicular Batfish",
	Aliases = { "Platax orbicularis" },
	Model = Assets["Orbicular Batfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://129371511456481",

	Family = "Ephippidae",
	Diet = "Algae, Invertebrates, and Small Fish",
	Size = "60 cm (23.6 in)",
	Depths = "0-30 m (0-98.4 ft)",

	Facts = {
		"While all adult batfish species are round and silver, each species' juveniles differ in coloration and appearance.",
		"Juvenile orbicular batfish are associated with mangroves. They mimic a dead leaf in coloration.",
		"Adult batfish prefer deeper, sandier areas than juveniles, where they form large schools."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, -0.20658588409423828, 1),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 1.0434142351150513, -0.25),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.29184627532958984, -1.5),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, -1.0418462753295898, -0.25),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, -0.20658588409423828, 1.75),
		},
	}
}