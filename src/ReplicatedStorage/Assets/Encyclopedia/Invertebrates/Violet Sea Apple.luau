local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "VioletApple", -- This is the what you set the _fishId arttibute to!
	Name = "Violet Sea Apple", -- The name of the fish that will show up in the book
	Aliases = { "Pseudocolochirus violaceus" },
	Model = Assets["VioletSeaApple"],
	Icon = "",

	Family = "Cucumariidae",
	Diet = "Detritus",
	Size = "20 cm (7.8 in)",
	Depths = "0-30 m (0-98 ft)",

	Facts = {
		"There are 4 species of sea apples, all striking in coloration. This  as well as their small size, makes them popular for aquariums.",
		"Sea apples are often seen sitting upright, with their feeding tentacles shoving passerby plankton into their mouths.",
		"Sea apples are a species of sea cucumber! Like other sea cucumbers, they have tube feet to help them move around.",
	},
	
	Skeleton =  {

		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.459408700466156, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.15851569175720215, 0),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.3000030517578125, -0.1414843201637268, 0),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.441484272480011, 0),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(-0.3000030517578125, -0.14148426055908203, 0),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(0, 0.15851575136184692, 0),
		},

	}
}