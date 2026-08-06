local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "SilverMoony", -- This is the what you set the _fishId arttibute to!
	Name = "Silver Moony", -- The name of the fish that will show up in the book
	Aliases = { "Monodactylus argenteus" },
	Model = Assets["Silver Moony"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://89017808383108",
	
	Family = "Monodactylidae",
	Diet = "Plankton",
	Size = "25 cm (9.8 in)",
	Depths = "0-12 m (0 - 39 ft)",

    Facts = {
		"The silver moony is notable for its diamond shaped appearance, and is also called the diamondfish.",
		"Moonys are common fish in mangrove and estuary environments across the Indo-Pacific.",
		"Juvenile moonys are much more diamond shaped than adults. They also have two black stripes on their face."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.40198516845703125, 0.01942157745361328),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 5,
			},
			["Position"] = Vector3.new(0, 0.02298736572265625, 0.02401447296142578),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.465484619140625, 0.028805851936340332),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.02628326416015625, -0.28036022186279297),
		},
		[5] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.01914215087890625, 0.37939947843551636),
		},
	}
}