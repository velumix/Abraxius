local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "FineStripedSnappingShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Fine-striped Snapping Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Alpheus ochrostriatus" },
	Model = Assets["Fine-Striped Snapping Shrimp"],
	Icon = "",

	Family = "Alpheidae",
	Diet = "Detritus",
	Size = "5 cm (1.9 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-20 m (3.3-65 ft)",

	Facts = {
		"This strikingly yellow pistol shrimp is known to associate itself with many goby species!",
		"There appears to be many different colors and patterns for this shrimp, making identification difficult.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, 0, -0.0322265625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0, 0.16788482666015625),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.0229644775390625, 0, -0.12055206298828125),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.02924346923828125, 0, -0.098052978515625),
		},
	} 

}