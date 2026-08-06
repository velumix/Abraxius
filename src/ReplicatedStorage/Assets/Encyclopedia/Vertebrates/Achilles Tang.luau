local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "achillesTang", -- This is the what you set the _fishId arttibute to!
	Name = "Achilles Tang", -- The name of the fish that will show up in the book
	Aliases = { "Acanthurus achilles" },
	Model = Assets["Achilles Tang"],
	Icon = "rbxassetid://128881294890332",

	Family = "Acanthuridae",
	Diet = "Algae and Detritus",
	Size = "30 cm (11.8 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-10 m (3.3-33 ft)",

	Facts = {
		"This fish is thought to be named after Achilles, but the reasoning is unknown.",
		"This fish is distinguised by the orange spot near its tail.",
		"Like all other surgeonfish, the achilles tang has a sharp spine near the base of its tail.",
		"These tangs are difficult to keep in home aquaria due to their active nature."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 1.1920928955078125e-07, -0.7096099853515625),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.30167466402053833, -0.25328826904296875),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.25283652544021606, -0.2626800537109375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, -0.02991423010826111, 0.3663787841796875),
		},
	}

}