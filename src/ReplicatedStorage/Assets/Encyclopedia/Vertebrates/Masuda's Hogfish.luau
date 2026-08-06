local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "MasudaHogfish", -- This is the what you set the _fishId arttibute to!
	Name = "Masuda's Hogfish", -- The name of the fish that will show up in the book
	Aliases = { "Bodianus masudai" },
	Model = Assets["Masuda's Hogfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://115462556174305",

	Family = "Labridae",
	Diet = "Benthic Invertebrates",
	Size = "15 cm (5.9 in)",
	Depths = "30-112 m (98.4-367.4 ft)",

	Facts = {
		"This small wrasse is known only from deeper mesophotic reefs across the Pacific.",
		"Due to the deep habitat of this fish, it is incredibly rare in the aquarium trade. As such, it is very expensive when it does appear!",
		"This fish is one of many that is named after a scientist that helps discover them!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.05055072903633118, -0.30612945556640625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.04012388736009598, -0.17198944091796875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.0912083089351654, -0.04157257080078125),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.04830664396286011, 0.11138916015625),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 0.08016739785671234, 0.23207855224609375),
		},
	}
}