local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "unicornLeatherjacket", -- This is the what you set the _fishId arttibute to!
	Name = "Unicorn Leatherjacket", -- The name of the fish that will show up in the book
	Aliases = { "Aluterus monoceros" },
	Model = Assets["Unicorn Leatherjacket"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",
	
	Family = "Monacanthidae",
	Diet = "Benthic Invertebrates",
	Size = "75 cm (2.4 ft)",
    Depths = "1-120 m (3-393.7 ft)",
	
    Facts = {
		"Unicorn leatherjackets are named for their large dorsal spine. While also on all other leatherjackets, the one on these is quite long!",
		"Leatherjackets are in the family of fish more broadly known as filefish, and are closely related to triggerfish.",
		"Unicorn leatherjacket juveniles are tan with large brown spotted patterning. They like to group under floating objects!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.0000762939453125, -1.9995346069335938, -0.09039592742919922),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 5,
				[4] = 6,
			},
			["Position"] = Vector3.new(0.0000457763671875, -1.0041275024414062, -0.6502749919891357),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 7,
			},
			["Position"] = Vector3.new(0, 1.1884613037109375, -0.014507293701171875),
		},
		[4] = {
			["Links"] = {
				[1] = 1,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.000030517578125, -1.7338218688964844, 0.41879987716674805),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 2,
			},
			["Position"] = Vector3.new(0, 0.06029510498046875, 0.59122633934021),
		},
		[6] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.0000457763671875, -0.4834251403808594, -0.7338500022888184),
		},
		[7] = {
			["Links"] = {
				[1] = 3,
			},
			["Position"] = Vector3.new(-0.000030517578125, 2.3215370178222656, 0.057465314865112305),
		},
	}
}