local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "IOOSweetlips", -- This is the what you set the _fishId arttibute to!
	Name = "Indian Ocean Oriental Sweetlips",
	Aliases = { "Plectorhinchus vittatus" },
	Model = Assets["Indian Ocean Oriental Sweetlips"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://102133129912117",

	Family = "Haemulidae",
	Diet = "Small Invertebrates",
	Size = "72 cm (28.3 in)",
	Depths = "2-25 m (6.5-82 ft)",

	Facts = {
		"Sweetlips are in the grunt family. They get this name by producing grunting noises by grinding teeth in their throat.",
		"These striped fish are similar to a different species, the oblique-banded sweetlips, but differ in stripe direction.",
		"Juvenile oriental sweetlips are more squat and have larger fins than adults, and are dark brown, yellow, orange, and white.",
		"Sweetlips are also known as blubberlips or thicklips."
		
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.25, -1.9716033935546875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.7499999403953552, -0.4716033935546875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 5,
			},
			["Position"] = Vector3.new(0, -5.960464477539063e-08, 1.0283966064453125),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, -0.5000000596046448, -0.4716033935546875),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, -5.960464477539063e-08, 2.0283966064453125),
		},
	}
}