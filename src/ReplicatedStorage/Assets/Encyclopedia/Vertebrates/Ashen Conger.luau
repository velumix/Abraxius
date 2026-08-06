local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "AshenConger", -- This is the what you set the _fishId arttibute to!
	Name = "Ashen Conger", -- The name of the fish that will show up in the book
	Aliases = { "Conger cinereus" },
	Model = Assets["Ashen Conger"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Congridae",
	Diet = "Fish and Crustaceans",
	Size = "140 cm (4.5 ft)",
	Depths = "0-80 m (0-262 ft)",
	
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
			["Position"] = Vector3.new(0, -0.9186897277832031, 0.015680015087127686),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 4,
			},
			["Position"] = Vector3.new(0, -0.06871414184570312, -0.18062466382980347),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.2906036376953125, -0.057697296142578125, 0.13671308755874634),
		},
		[4] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-0.293060302734375, -0.057697296142578125, 0.13671287894248962),
		},
	}
}