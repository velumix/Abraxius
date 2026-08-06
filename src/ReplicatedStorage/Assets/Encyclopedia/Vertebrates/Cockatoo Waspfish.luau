local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "TooWaspfish", -- This is the what you set the _fishId arttibute to!
	Name = "Cockatoo Waspfish", -- The name of the fish that will show up in the book
	Aliases = { "Ablabys taenianotus" },
	Model = Assets["Cockatoo Waspfish"],
	Icon = "",

	Family = "Synanceiidae",
	Diet = "Small Crustaceans",
	Size = "15 cm (5.9 in)",
	Depths = "1-78 m (3.3-255.9 ft)",

	Facts = {
		"This fish is known to sit on the bottom, swaying back and forth. This is likely to mimic a leaf!",
		"True to the wasp part of the name, these fish are venomous and can inflict a painful sting.",
		"These fish are nocturnal and emerge at night to hunt small crustaceans and fish."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.44712066650390625, -0.2289365977048874),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.19365692138671875, -0.128228560090065),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.14281463623046875, 0.015005722641944885),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.35294342041015625, 0.0802217647433281),
		},
	}
}