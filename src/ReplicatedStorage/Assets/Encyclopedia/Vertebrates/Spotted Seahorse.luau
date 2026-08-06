local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SpottedSeahorse", -- This is the what you set the _fishId arttibute to!
	Name = "Spotted Seahorse", -- The name of the fish that will show up in the book
	Aliases = { "Hippocampus kuda" },
	Model = Assets["Spotted Seahorse"],
	Icon = "rbxassetid://103975312003423",

	Family = "Syngnathidae",
	Diet = "Zooplankton",
	Size = "30 cm (11 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-122 m (0-223 ft)",

	Facts = {
		"Spotted seahorse come in a variety of colors, including red, brown, grey, yellow, and orange!",
		"This species is also known as the estuary, yellow, or common seahorse. Many of these names also refer to other species.",
		"Male seahorses raise their eggs in a special pouch under the tail, known as the brood pouch.",
		"Seahorses do not have a stomach, and as such constantly feed throughout the day.",
		"Spotted seahorses are known to be associated with sargassum patches floating up to 20 km from shore.",
		"The spotted seahorse is listed as a vulnerable species due to threats such as the traditional medicine and aquarium trade."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.00225830078125, -0.24217605590820312, -0.19268035888671875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0.00167083740234375, -0.4902181625366211, 0.0938720703125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.00217437744140625, -0.2789421081542969, 0.18961334228515625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.00060272216796875, 0.121246337890625, 0.03717803955078125),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(-0.00171661376953125, 0.5376796722412109, 0.03891754150390625),
		},
	}
}