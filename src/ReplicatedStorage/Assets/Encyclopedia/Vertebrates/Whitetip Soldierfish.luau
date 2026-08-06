local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "WhitetipSoldierfish", -- This is the what you set the _fishId arttibute to!
	Name = "Whitetip Soldierfish",
	Aliases = { "Myripristis vittata" },
	Model = Assets["Whitetip Soldierfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://136725438421859",

	Family = "Holocentridae",
	Diet = "Plankton and Small Crustaceans",
	Size = "25 cm (9.8 cm)",
	Depths = "3-80 m (9.8-262.4 ft)",

	Facts = {
		"Soldierfish are nocturnal, taking refuge under overhangs in schools during the day.",
		"Soldierfish are sometimes observed swimming upside down!",
		"Soldierfish being red is perhaps a nocturnal adaptation. Red light dissipates quickly in water, cloaking the fish."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.19739875197410583, 0.11775970458984375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.1973988115787506, -0.42186737060546875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.1542796641588211, 0.11447906494140625),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, -0.15427957475185394, -0.4522895812988281),
		},
	}
}