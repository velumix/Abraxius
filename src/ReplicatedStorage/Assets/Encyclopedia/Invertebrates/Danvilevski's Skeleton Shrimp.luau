local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SkeletonShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Danilevski's Skeleton Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Caprella danilevskii" },
	Model = Assets["Weedy Skeleton Shrimp"],
	Icon = "rbxassetid://74885182052314",

	Family = "Caprellidae",
	Diet = "Plankton",
	Size = "2 cm (0.7 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-15 m (0-49 ft)",

	Facts = {
		"This bizarre creature is a very strangely adapted member of a diverse group of crustaceans called amphipods.",
		"Many species of skeleton shrimp are carnivores, acting similar to a praying mantis by snatching prey with their front limbs.",
		"Skeleton shrimp are masters of camouflage, and are typically found on foliage or reef building organisms.",
		"This species does not have a common name. The one used here is based on its scientific name, as it is named after someone!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.02539825439453125, 0, -0.0113525390625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.00250244140625, 0, -0.0057220458984375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.05907440185546875, 0, -0.00002288818359375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.094146728515625, 0, 0.02825927734375),
		},
	}

}