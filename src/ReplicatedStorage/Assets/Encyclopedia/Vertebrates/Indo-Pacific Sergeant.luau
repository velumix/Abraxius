local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "IndoPacificSergeant", -- This is the what you set the _fishId arttibute to!
	Name = "Indo-Pacific Sergeant",
	Aliases = { "Abudefduf vaigiensis" },
	Model = Assets["Indo-Pacific Sergeant"], -- ReplicatedStorage -> Assets -> FishModels
	Icon = "rbxassetid://90518191875305",

	Family = "Pomacentridae",
	Diet = "Plankton and Algae",
	Size = "20 cm (7.9 in)",
	Depths = "0-15 m (0-49 ft)",

	Facts = {
		"Indo-Pacific sergeants get their name from their stripes, resembling a military rank.",
		"These fish heavily resemble their Atlantic relatives, the sergeant major.",
		"Male sergeants defend their eggs, which are layed on the seabed. They also provide care by oxygenating them."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.16329239308834076, -0.33795928955078125),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.12650376558303833, -0.33795928955078125),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, -0.000403672456741333, 0.20311737060546875),
		},
	}
}