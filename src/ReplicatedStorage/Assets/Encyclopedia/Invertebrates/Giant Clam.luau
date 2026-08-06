local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GiantClam", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Clam", -- The name of the fish that will show up in the book
	Aliases = { "Tridacna gigas" },
	Model = Assets["Giant Clam"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://120229460776530",
	
	Family = "Cardiidae",
	Diet = "Plankton",
	Size = "1.37 m (4.5 ft)",
	Depths = "0-35 m (0-115 ft)",

    Facts = {
		"Weighing up to more than 200 kg, this is the largest species of giant clam known.",
		"Giant clams are unfortunately critically endangered due to unsustainable harvest, pollution, and climate change.",
		"Young giant clams are planktonic, drifting around in the current until they find somewhere where they can settle and grow.",
		"Like corals, giant clams are known to have symbiotic algae living within their tissues which carry out photosynthesis."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 1.3436295986175537, -2.033985137939453),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -1.3251090049743652, -0.059703826904296875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 1.0907068252563477, 1.3971023559570312),
		},
	}
}