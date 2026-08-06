local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "bluestreakCleanerWrasse", -- This is the what you set the _fishId arttibute to!
	Name = "Bluestreak Cleaner Wrasse", -- The name of the fish that will show up in the book
	Aliases = { "Labroides dimidiatus" },
	Model = Assets["CleanerWrasseSolo"],
	Icon = "rbxassetid://112220430655968",

	Family = "Labridae",
	Diet = "Parasites and Fish Mucus",
	Size = "14 cm (5.5 in)",
	Time = "Day", -- Time of day the fish is active
	Depths = "0-100 m (0-328 ft)",

	Facts = {
		"Cleaner wrasse advertise their cleaning services by performing a dance, flicking their tail fin in the air several times.",
		"The black stripe down the side of the fish potentially acts as an identification signal for organisms looking to be cleaned.",
		"Cleaner wrasse may 'cheat' clients by directly biting or eating their mucus. This can cause the client to leave or retaliate.",
		"Male and female pairs of cleaner wrasse work together to clean fish.",
		"Female cleaner wrasse are suggested to know when the male can see them, and will not 'cheat' clients when being watched.",
		"Cleaner wrasse have been suggested to recognize themselves in a mirror, though this is not without debate."
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -0.3856201171875, -0.05274486541748047),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
			},
			["Position"] = Vector3.new(0, -0.22110748291015625, 0.029363274574279785),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0, -0.057220458984375, -0.0764167308807373),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.09818267822265625, 0.03517782688140869),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 0.25502777099609375, -0.03910672664642334),
		},
	}
}