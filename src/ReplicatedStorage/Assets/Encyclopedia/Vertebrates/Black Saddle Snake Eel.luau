local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "BlackSaddle", -- This is the what you set the _fishId arttibute to!
	Name = "Black Saddle Snake Eel", -- The name of the fish that will show up in the book
	Aliases = { "Ophichthus cephalozona" },
	Model = Assets["BlacksaddleSnakeEel"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Ophichthidae",
	Diet = "Small Fish and Crustaceans",
	Size = "100 cm (3.2 ft)",
	Depths = "0-30 m (0-98 ft)",
	
    Facts = {
		"This conger is nocturnal, emerging at night to hunt. It has been suggested that it changes to its striped pattern when hunting!",
		"This eel has a broad range, being found from the east coast of Africa to the east coast of Australia.",
		"Congers are a very diverse family of eels, including the massive European conger and the sand-dwelling garden eels!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0023040771484375, 0.4911003112792969, 0.00336456298828125),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
				[4] = 6,
			},
			["Position"] = Vector3.new(-0.0007781982421875, -0.164825439453125, -0.0011272430419921875),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.0066375732421875, -1.4097709655761719, -0.009654998779296875),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.3151092529296875, -0.16610336303710938, -0.03185844421386719),
		},
		[5] = {
			["Links"] = {},
			["Position"] = Vector3.new(0.3151092529296875, -0.16610336303710938, -0.03185844421386719),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.3437042236328125, -0.16344070434570312, 0.03223228454589844),
		},
	}
}