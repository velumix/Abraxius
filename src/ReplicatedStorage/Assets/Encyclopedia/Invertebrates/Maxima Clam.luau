local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "maximaClam", -- This is the what you set the _fishId arttibute to!
	Name = "Maxima Clam", -- The name of the fish that will show up in the book
	Aliases = { "Tridacna maxima" },
	Model = Assets["Maxima Clam"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://119702879642179",
	
	Family = "Cardiidae",
	Diet = "Plankton",
	Size = "40 cm (15.7 in)",
	Depths = "0-35 m (0-115 ft)",

    Facts = {
		"The maxima clam is known for its striking color variety, including brown, teal, and bright blue!",
		"This clam is popular in the aquarium trade due to its small size and coloration.",
		"This species of giant clam is one of several that have ridges on the side of its shell."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.5811174511909485, 0),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 0.08669698238372803, -0.913818359375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 0.41837602853775024, -0.1210479736328125),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, 0.11734682321548462, 0.8789520263671875),
		},
	}

}