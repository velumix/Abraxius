local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GiantTriton", -- This is the what you set the _fishId arttibute to!
	Name = "Giant Triton", -- The name of the fish that will show up in the book
	Aliases = { "Charonia tritonis" },
	Model = Assets["Giant Triton"],
	Icon = "rbxassetid://70954935686786",

	Family = "Charoniidae",
	Diet = "Echinoderms",
	Size = "Shell 50 cm (19.6 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-40 m (3.3-131 ft)",

	Facts = {
		"Giant tritons are a predatory snail and are one of the largest extant sea snails.",
		"Giant tritons are notable for being one of the few animals to eat the venomous crown-of-thorns starfish",
		"Tritons have been suggested as a control method for crown-of-thorns, which have huge population booms that threaten reefs.",
		"While protected in some areas, the large, distinct shells of the triton are prized collectables for some shell collectors."
	},
	
	Skeleton =  {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -1.2334365844726562, 0.7500045299530029),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(-0.7052764892578125, 0.5165481567382812, 0.750036358833313),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(-0.2053070068359375, 1.7665863037109375, -0.24998915195465088),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 1,
			},
			["Position"] = Vector3.new(0.794677734375, 0.2666168212890625, 0.5000160932540894),
		},
	}

}