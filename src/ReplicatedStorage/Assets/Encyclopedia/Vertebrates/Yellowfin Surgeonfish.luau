local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "yellowfinSurgeon", -- This is the what you set the _fishId arttibute to!
	Name = "Yellowfin Surgeonfish", -- The name of the fish that will show up in the book
	Aliases = { "Acanthurus xanthopterus" },
	Model = Assets["Yellowfin Surgeonfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://122272792018382",

	Family = "Acanthuridae",
	Diet = "Algae and Detritus",
	Size = "70 cm (27.5 in)",
	Depths = "1-120 m (3.3-394 ft)",

	Facts = {
		"This species is one of the largest of the surgeonfish.",
		"This surgeonfish is notable for being known to take baited hooks of fishermen, which is uncommon for surgeonfish to do.",
		"Larval surgeonfish take up a more pelagic lifestyle than adults. This larval stage, called an acronurus, is transparent."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 3.5762786865234375e-07, -2.4622344970703125),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.8558632135391235, -0.8952407836914062),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.7768808603286743, -0.90374755859375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, -0.04954928159713745, 0.83251953125),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, -0.04954946041107178, 1.7181625366210938),
		},
	}
}