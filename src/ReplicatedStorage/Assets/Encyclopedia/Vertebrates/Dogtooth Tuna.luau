local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "DogtoothTuna", -- This is the what you set the _fishId arttibute to!
	Name = "Dogtooth Tuna",
	Aliases = { "Gymnosarda unicolor" },
	Model = Assets["Dogtooth Tuna"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Scombridae",
	Diet = "Fish and Squid",
	Size = "2.48 m (8.1 ft)",
	Depths = "1-250 m (3.3-820 ft)",

	Facts = {
		"Dogtooth tuna are not true tuna. They are a part of a smaller but closely related group called the bonitos.",
		"Dogtooth tuna are the largest species of the tuna family that commonly lives in and around reefs!",
		"The species name of this fish, unicolor, refers to the fact it is very boring and quite monotonous in color.",
		"This fish is a popular sportfish across its range, notable for its fighting power.",
	},

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0000152587890625, -6.643657684326172, -0.13771319389343262),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.6436557769775391, -0.13771319389343262),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 7.063102722167969, -0.13771319389343262),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 8.224727630615234, -2.230003595352173),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 8.224727630615234, 2.373504638671875),
		},
	}
}