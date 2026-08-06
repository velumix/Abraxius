local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "AqueoreaA", -- This is the what you set the _fishId arttibute to!
	Name = "Southern Crystal Jelly", -- The name of the fish that will show up in the book
	Aliases = { "Aequorea australis" },
	Model = Assets["Southern Crystal Jelly"],
	Icon = "",

	Family = "Aequoreidae",
	Diet = "Zooplankton",
	Size = "2.5 cm (0.9 in)",
	Depths = "0-150 m (0-492 ft) ",

	Facts = {
		"This species is not a true jelly! It is actually more closely related to species such as the man o' war and blue button.",
		"Some crystal jelly species have green bioluminescence around the rim of their bells.",
		"Occasionally, pelagic amphipods and lobster larvae will ride and parasitize crystal jellies!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.06948263943195343, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, -0.06866523623466492, 0),
		},
	}
}