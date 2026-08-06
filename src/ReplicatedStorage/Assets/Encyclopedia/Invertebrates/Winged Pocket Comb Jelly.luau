local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "WPocketCombJelly", -- This is the what you set the _fishId arttibute to!
	Name = "Winged Pocket Comb Jelly", -- The name of the fish that will show up in the book
	Aliases = { "Neis cordigera" },
	Model = Assets["Winged Pocket Comb Jelly"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://97129313313178",

	Family = "Beroidae",
    Diet = "Comb Jellies",
	Size = "30 cm (11.8 in)",
	Depths = "Shallow Water (Depth Unknown)",
	
	Facts = {
		"Comb jellies swim by undulating small fine hairs known as cilia. These often display stunning rainbow colors with iridescence.",
		"This species is one of the beroid comb jellies. They are essentially swimming mouths that swallow other comb jellies whole!",
		"This species is one of the largest of the comb jellies, and is distinct in its two tailed appearance.",
		"Although called comb jellies, they are unrelated to true jellies. They are in an whole different group, called Ctenophora!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.25, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.33968353271484375, 0.5, -2.384185791015625e-07),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.33968353271484375, -0.5, -2.384185791015625e-07),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.33966827392578125, -0.5, -2.384185791015625e-07),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 1,
			},
			["Position"] = Vector3.new(0.33966827392578125, 0.5, -4.76837158203125e-07),
		},
	}

}