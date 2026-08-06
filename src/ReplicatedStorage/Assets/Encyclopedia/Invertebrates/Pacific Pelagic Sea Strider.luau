local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "pacificPelagicSeaStrider", -- This is the what you set the _fishId arttibute to!
	Name = "Pacific Pelagic Sea Strider", -- The name of the fish that will show up in the book
	Aliases = { "Halobates sericeus" },
	Model = Assets["Pacific Pelagic Sea Strider"],
	Icon = "",

	Family = "Gerridae",
	Diet = "Zooplankton",
	Size = "2 cm (0.7 in)",
	Depths = "Surface",

	Facts = {
		"These are the only known open sea insects! They have special adaptations that allow them to float on the high seas.",
		"These insects cannot swim or fly, so are constantly exposed to sun radiation. As a result, their carapace reflects 99% of the UVs!",
		"These insects are a part of Hemiptera, also known as the true bugs. These are characterized by their piercing mouthparts.",
		"Recently, sea striders have been laying eggs on floating plastics. This is an issue, as the eggs are a food source for other animals.",
		"Sea striders are an important food source for open sea birds and small surface dwelling fish.",
		"Some sea striders are coastal species, and are known to eat dead insects that fall in the water."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.0522613525390625, 0.006917115300893784),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.0798187255859375, -0.05226898193359375, 0.005360711365938187),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.07672119140625, -0.0499114990234375, 0.005391228944063187),
		},
	}  

}