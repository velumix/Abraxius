local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Squarespot", -- This is the what you set the _fishId arttibute to!
	Name = "Squarespot Anthias", -- The name of the fish that will show up in the book
	Aliases = { "Pseudanthias pleurotaenia" },
	Model = Assets["Squarespotanthias"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Anthiadidae",
	Diet = "Zooplankton",
	Size = "20 cm (7.8 in)",
	Depths = "0-25 m (0 - 82 ft)",

    Facts = {
		"These small, vibrant fish earned their name from the distinctive square-shaped pink or purple spot found on their side.",
		"They are social fish, living in small groups usually consisting of one male and several females.",
		"Rather than hunting, they will hover near the reef and snack on tiny organisms like zooplankton drifting in the current!",
		"Males are typically more vibrant and colorful than females; they use their bright colors to stand out and attract partners."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.07829239964485168, -0.49921417236328125),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.07717025279998779, -0.2306671142578125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.07717013359069824, 0.00688934326171875),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.06288167834281921, 0.00688934326171875),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.06288152933120728, -0.281097412109375),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, 0.07699999958276749, -0.23100000619888306),
		},
	}
}