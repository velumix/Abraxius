local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SpanishDancer", -- This is the what you set the _fishId arttibute to!
	Name = "Decumbent Spanish Dancer", -- The name of the fish that will show up in the book
	Aliases = { "Hexabranchus lacer" },
	Model = Assets["Decumbent Spanish Dancer"],
	Icon = "",

	Family = "Hexabranchidae",
	Diet = "Sponges",
	Size = "40 cm (15.7 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-30 m (3.3-98.4 ft)",

	Facts = {
		"Spanish dancers get their name from their red color and swimming habit, resembling a flamenco dancer!",
		"Spanish dancers are one of the largest nudibranches. One unconfirmed report of one claims to be up to 70 cm (27 in)!",
		"Like many sea slugs, dancers can show multiple drastically different colors across the same species, making identification difficult.",
		"Previously there was thought to be only 2 species of spanish dancer. With new research, there are currently six!",
		"Spanish dancers can sometimes be found with smaller animals living on them, like emperor shrimp!",
		"Spanish dancers are toxic due to gainign toxins from their diet of sponges."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, -0.8382568359375, -0.03815308213233948),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.00670623779296875, 0.014385044574737549),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
				[3] = 7,
				[4] = 8,
				[5] = 9,
				[6] = 10,
				[7] = 11,
				[8] = 12,
			},
			["Position"] = Vector3.new(0, 0.8279342651367188, 0.06711381673812866),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0.25276947021484375, -0.8209991455078125, -0.31127068400382996),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(-0.2208099365234375, -0.8209991455078125, -0.31127265095710754),
		},
		[6] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.8488922119140625, -0.26462194323539734),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.6968460083007812, -0.4521922767162323),
		},
		[8] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.6921463012695312, -0.14170438051223755),
		},
		[9] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.8488922119140625, -0.26462194323539734),
		},
		[10] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0.211334228515625, 0.6989822387695312, -0.27408984303474426),
		},
		[11] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.19521331787109375, 0.6989822387695312, -0.2740914523601532),
		},
		[12] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 0.42697906494140625, -0.29127249121665955),
		},
	}
}