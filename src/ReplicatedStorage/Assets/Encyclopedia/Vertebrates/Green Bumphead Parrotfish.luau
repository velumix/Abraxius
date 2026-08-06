local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GreenBumpParrot", -- This is the what you set the _fishId arttibute to!
	Name = "Green Bumphead Parrotfish",
	Aliases = { "Bolbometopon muricatum" },
	Model = Assets["Green Bumphead Parrotfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Scaridae",
	Diet = "Corals and Algae",
	Size = "1.5 m (4.9 ft)",
	Depths = "0-40 m (0-131 ft)",

	Facts = {
		"These parrotfish are important for reef health. Their feeding habit has them function as a bioeroder, creating sand!",
		"When feeding, bumphead parrotfish are known to headbutt corals to help break them down.",
		"A single adult bumphead parrotfish may eat up to 5 tonnes of coral a year, creating as much sand via defecation in the process!",
		"Green bumphead parrotfish are the largest of the parrotfish, growing up to 46 kg (101 lbs).",
		"These parrotfish are known to sleep, taking shelter in shipwrecks, outcrops, and caves at night.",
		"This species is unfortunately classified as vulnerable to extinction due to pressure from overfishing.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.38645121455192566, -3.518198251724243),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.6661163568496704, -3.518198251724243),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.6294403076171875, -1.5196852684020996),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.8871604800224304, 0.16976359486579895),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.32702240347862244, 2.3029379844665527),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, 0.446270614862442, 3.7655887603759766),
		},
		[7] = {
			["Links"] = {
				[1] = 6,
			},
			["Position"] = Vector3.new(0, -0.1408083438873291, 4.85891056060791),
		},
	}
}