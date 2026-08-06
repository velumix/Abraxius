local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BandedCoralShrimp", -- This is the what you set the _fishId arttibute to!
	Name = "Banded Coral Shrimp", -- The name of the fish that will show up in the book
	Aliases = { "Stenopus hispidus" },
	Model = Assets["Banded Coral Shrimp"],
	Icon = "",

	Family = "Stenopodidae",
	Diet = "Small Invertebrates and Detritus",
	Size = "6 cm (2.3 in)",
	Depths = "1-200 m (3-656 ft)",

	Facts = {
		"This shrimp may be able to recognise specific individuals of their own species! This ability is thought to be rare in invertebrates.",
		"Many invertebrates, such as these, have small territories. This species has a max territory of 2 meters (6 ft) in diameter.",
		"This species is one of many cleaner 'shrimp', and signals potential clients by waving its long antennae!",
		"Despite the name and appearance, banded coral shrimp are not true shrimp. They are distinguished by their three pairs of claws.",
		"These shrimp are sometimes known as boxer shrimp, as the large, third pair of claws looks like boxing gloves in some species.",
		"This species is found worldwide in tropical waters, being known from both the tropical Pacific, Indian and Atlantic Oceans."
	},
}