local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "oceanSunfish", -- This is the what you set the _fishId arttibute to!
	Name = "Ocean Sunfish",
	Aliases = { "Mola mola" },
	Model = Assets["Ocean Sunfish"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "rbxassetid://86019946673810",

	Family = "Molidae",
	Diet = "Small Fish, Mollusks, and Jellyfish",
	Size = "3.3 m (10.8 ft)",
	Depths = "0-1515 m (0-4970 ft)",

	Facts = {
		"The ocean sunfish is one of the largest and heaviest bony fish in the world.",
		"Ocean sunfish get their name by their behavior of basking on their side at the waters surface, soaking in the suns heat.",
		"Once thought to be slow animals, it is now known that sunfish can be quite fast, and are even known to breach!",
		"Larval ocean sunfish resemble small spiky balls! They gain their iconic shape as they grow.",
		"Ocean sunfish produce large quantities of eggs. One individual can produce up to 300 million!"
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, -10.975677490234375, 0.028669357299804688),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, 5.127288818359375, -0.21143531799316406),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 5.246063232421875, 7.752834320068359),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, 5.03125, -6.654447555541992),
		},
		[5] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(0, 7.706871032714844, 14.411645889282227),
		},
		[6] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 7.1296234130859375, -14.307657241821289),
		},
	}
}