local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "PugheadMudskipper", -- This is the what you set the _fishId arttibute to!
	Name = "Pug-headed Mudskipper",
	Aliases = { "Periophthalmodon freycineti" },
	Model = Assets["Pug-headed Mudskipper"], -- ReplicatedStorage -> Assets -> FishModels
	Icon = "rbxassetid://117404518476366",

	Family = "Oxudercidae",
	Diet = "Small Invertebrates",
	Size = "25 cm (9.8 in)",
	Depths = "Shoreline",

	Facts = {
		"Mudskippers are land dwelling fish! They roll around in mud to prevent drying out, and, when wet, can breath through their skin.",
		"Mudskippers are one of the only fish capable of blinking.",
		"Mudskippers lay their eggs in mud burrows. Once layed, the male mudskipper typically protects them until hatching.",
		"Some mudskipper species are known to fight over territory or potential mates by opening their jaws and jumping aggressively."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.320068359375, -0.5931529998779297, -0.04149222373962402),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0.12652587890625, -0.21016883850097656, -0.02496582269668579),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.12683868408203125, -0.20504188537597656, -0.13973413407802582),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0005035400390625, 0.03259468078613281, -0.014458522200584412),
		},
	}
}