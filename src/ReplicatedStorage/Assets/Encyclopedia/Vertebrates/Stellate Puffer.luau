local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "StellatePuffer", -- This is the what you set the _fishId arttibute to!
	Name = "Stellate Puffer", -- The name of the fish that will show up in the book
	Aliases = { "Arothron stellatus" },
	Model = Assets["Stellate Puffer"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://82442178783875",
	
	Family = "Tetraodontidae",
	Diet = "Benthic Invertebrates",
	Size = "120 cm (3.9 ft)",
    Depths = "1-61 m (3.1-200 ft)",
	
    Facts = {
		"Stellate puffers are one of the largest of the pufferfish!",
		"Pufferfish are notable for their large beaks that they use to crush hard prey items such as crustaceans and mollusks.",
		"Stellate pufferfish are poisonous and have tetrodotoxin. The toxicity of this poison may vary based on the area the fish is found.",
		"Pufferfish can move their eyes independently from each other, similar to a chameleon."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0009002685546875, -3.0683746337890625, 0.02861332893371582),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0.0006866455078125, -0.17078208923339844, 0.031336307525634766),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.084228515625, 1.3158130645751953, -0.8330150842666626),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0842437744140625, 1.5810661315917969, 1.1152820587158203),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
			},
			["Position"] = Vector3.new(0.0005645751953125, 1.5077781677246094, 0.03291511535644531),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0.000396728515625, 3.757722854614258, 0.0350337028503418),
		},
	}

}