local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SplitfinFlashlightfish", -- This is the what you set the _fishId arttibute to!
	Name = "Splitfin Flashlightfish",
	Aliases = { "Anomalops katoptron" },
	Model = Assets["Splitfin Flashlightfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://136725438421859",

	Family = "Anomalopidae",
	Diet = "Zooplankton",
	Size = "35 cm (13.7 cm)",
	Depths = "2-400 m (6.5-1312 ft)",

	Facts = {
		"The most striking feature of these fish are the bioluminescent spots under their eyes, which they blink to detect food.",
		"The symbiotic bacteria that causes the fish's bioluminesence is a species only found living on splitfin flashlightfish.",
		"Flashlightfish individuals from the twilight zone (under 200 m) show a form that is larger than those in shallower waters."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.6612548828125, -0.023561060428619385),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 6,
			},
			["Position"] = Vector3.new(0, -0.14957427978515625, -0.010316014289855957),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.3442840576171875, 0.00247114896774292),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.7736663818359375, 0.01358756422996521),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 1.1787643432617188, 0.02407824993133545),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, -0.49230194091796875, 0.19965219497680664),
		},
	}
}