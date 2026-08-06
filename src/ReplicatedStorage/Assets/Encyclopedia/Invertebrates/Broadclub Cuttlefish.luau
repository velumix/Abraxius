local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BroadCuttlefish", -- This is the what you set the _fishId arttibute to!
	Name = "Broadclub Cuttlefish", -- The name of the fish that will show up in the book
	Aliases = { "Ascarosepion latimanus" },
	Model = Assets["Broadclub Cuttlefish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Sepiidae",
    Diet = "Fish and Crustaceans",
	Size = "Mantle Length 50 cm (20 in)",
    Depths = "8-55 m (26-180 ft)",
	
    Facts = {
		"Broadclub cuttlefish are the second largest of the cuttlefish species, being up to 10 kg (22 lbs)!",
		"When hunting, broadclub cuttlefish extend their bottom two arms straight out to their sides and flash a passing striped pattern.",
		"Like other cuttlefish, broadclub cuttlefish are masters of disguise and can change their color in an instant!",
		"As of current scientific knowledge, cuttlefish are classified as squid!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, 1.3939743041992188, 0.05549466609954834),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(-1.1108474731445312, 0.15279388427734375, 0.019527792930603027),
		},
		[3] = {
			["Links"] = {
				[1] = 1,
				[2] = 4,
			},
			["Position"] = Vector3.new(1.1115036010742188, 0.15279388427734375, 0.019527792930603027),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 2,
			},
			["Position"] = Vector3.new(0.00083160400390625, -1.52618408203125, -0.029128551483154297),
		},
		[5] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 1.9154052734375, -0.813439667224884),
		},
	}
}