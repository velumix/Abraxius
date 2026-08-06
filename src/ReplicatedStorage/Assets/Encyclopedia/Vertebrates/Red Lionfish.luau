local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "RedLionfish", -- This is the what you set the _fishId arttibute to!
	Name = "Red Lionfish", -- The name of the fish that will show up in the book
	Aliases = { "Pterois volitans" },
	Model = Assets["Red Lionfish"],
	Icon = "rbxassetid://88088833330956",

	Family = "Scorpaenidae",
	Diet = "Fish and Crustaceans",
	Size = "45 cm (17.7 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "2-55 m (6.5-180.4 ft)",

	Facts = {
		"Lionfish are very venomous, having dorsal spines that contain neurotoxic venom glands at their base.",
		"The species name of the red lionfish, Pterois volitans, roughly means winged flyer, likely due to their large, wing-like fins",
		"Juvenile red lionfish have notable antenna-like protrusions above their eyes, which help to further break up their outline.",
		"Red lionfish are infamous for being an invasive species in the Atlantic, where their voracious nature is devastating to native fish.",
		"Despite being invasive in the Atlantic, these fish are native to the Indo-Pacific, and pose no threat to the ecosystem there.",
		"There are several species of lionfish, and many look very similar. They are even known to hybridize with each other!",
		"The striking fins of the lionfish are thought to help them in hunting, as they can use them to block off the escape paths of prey.",
		"Lionfish are known to use their fins to signal other lionfish to help them hunt!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.8878593444824219, 0.14047282934188843),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 5,
				[4] = 6,
				[5] = 7,
			},
			["Position"] = Vector3.new(0, -0.6436882019042969, 0.13882291316986084),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.11308670043945312, 0.018291234970092773),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.7449150085449219, 0.046691179275512695),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.0526123046875, -0.6559920907020569),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.4323883056640625, -0.3839263916015625, 0.237856924533844),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.5002288818359375, -0.47454833984375, 0.14642465114593506),
		},
	}
}