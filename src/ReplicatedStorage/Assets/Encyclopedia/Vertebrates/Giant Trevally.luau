local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GiantTrevally", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Trevally", -- The name of the fish that will show up in the book
	Aliases = { "Caranx ignobilis" },
	Model = Assets["GiantTrevallySolo"],
	Icon = "rbxassetid://85391400714234",

	Family = "Carangidae",
	Diet = "Crustaceans and Fish",
	Size = "1.7 m (5.57 feet)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-188 m (3.3-616 ft)",

	Facts = {
		"Giant trevally have been documented jumping out of the water to feed on young seabirds attempting to learn to fly.",
		"There is a lake in the Philippines that is home to a freshwater adapted population of giant trevally!",
		"Adult male giant trevally are dark colored to black, while females are more silver-grey.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, -0.7760149240493774, -5.308074951171875),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, 1.2877943515777588, -3.5119590759277344),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, 1.2877936363220215, 0.456390380859375),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.09587836265563965, 2.685413360595703),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 1,
			},
			["Position"] = Vector3.new(0, -1.162522315979004, 0.46166229248046875),
		},
	}
}