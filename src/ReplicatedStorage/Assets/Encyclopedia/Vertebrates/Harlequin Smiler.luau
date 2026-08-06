local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "harlequinSmiler", -- This is the what you set the _fishId arttibute to!
	Name = "Harlequin Smiler", -- The name of the fish that will show up in the book
	Aliases = { "Opistognathus eximius" },
	Model = Assets["HarlequinSmiler"],
	Icon = "rbxassetid://94475562788525",

	Family = "Opistognathidae",
	Diet = "Small Invertebrates and Plankton",
	Size = "28 cm (11 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "6-35 m (19-115 ft)",

	Facts = {
		"Harlequin smilers are an incredibly colorful species of jawfish. Jawfish excavate sand burrows with their mouths.",
		"Jawfish are mouthbrooders, caring for and incubating their eggs in their mouths. They leave the eggs in the burrow when feeding.",
		"Some jawfish are known to confront threats by either retreating into their burrow or by spitting objects at intruders!"
	},

	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.4741058349609375, -0.1018604040145874),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, -0.15364456176757812, -0.03882956504821777),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.48465728759765625, 0.10409951210021973),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.19951629638671875, -0.05004727840423584),
		},
	}
}