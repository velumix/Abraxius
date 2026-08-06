local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BSlipperLobster", -- This is the what you set the _fishId arttibute to!
	Name = "Blunt Slipper Lobster", -- The name of the fish that will show up in the book
	Aliases = { "Scyllarides squammosus" },
	Model = Assets["Blunt Slipper Lobster"],
	Icon = "",

	Family = "Scyllaridae",
	Diet = "Mollusks and Sea Urchins",
	Size = "40 cm (15.7 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-71 m (3.3-232.9 ft)",

	Facts = {
		"A strange looking crustacean, slipper lobsters are not a true lobster, instead being closely related to spiny lobsters.",
		"Slipper lobsters do not have claws, so feed on clams by cracking them open with their walking legs.",
		"The scientific name of the family of slipper lobsters, Scyllaridae, comes from the Greek sea monster of legend, Scylla!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.286865234375, -1.0232315063476562, -0.001308441162109375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(-0.01802825927734375, -0.42932891845703125, -0.10711145401000977),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.3116455078125, -1.0214385986328125, -0.0010075569152832031),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(-0.01802825927734375, 0.14775848388671875, -0.007086277008056641),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(-0.01802825927734375, 0.6551055908203125, 0.08173036575317383),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(-0.01802825927734375, 0.9246978759765625, 0.6045422554016113),
		},
	}
}