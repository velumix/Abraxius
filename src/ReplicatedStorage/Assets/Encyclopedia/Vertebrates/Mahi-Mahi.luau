local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "Mahi", -- This is the what you set the _fishId arttibute to!
	Name = "Mahi-Mahi", -- The name of the fish that will show up in the book
	Aliases = { "Coryphaena hippurus" },
	Model = Assets["Mahi-Mahi"],
	Icon = "rbxassetid://121968185679390",

	Family = "Coryphaenidae",
	Diet = "Cephalopods and Fish",
	Size = "2.1 m (6.9 feet)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-85 m (3.3-265.7 ft)",

	Facts = {
		"Mahi-mahi are very popular sportfish. They are targeted for their speed, size, beauty, and fighting power!",
		"Mahi-mahi can change colors when excited or stressed, switching from silver, blue, green, and yellow in the blink of an eye!",
		"Mature male mahi-mahi have a distinct, large forehead, while females and young individuals have a round head.",
		"Very young mahi-mahi are brown with stripes. This likely helps them blend in with sargassum mats, where they are often found.",
		"These fish are also known as dolphinfish or simply just dolphin, despite having no relation to the mammals of the same name.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 7,
			},
			["Position"] = Vector3.new(-0.00042724609375, -4.856117248535156, -0.8033349514007568),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 7,
			},
			["Position"] = Vector3.new(-0.0001678466796875, -2.2395172119140625, 0.03830885887145996),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.0000152587890625, 0.885589599609375, -0.016058683395385742),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
				[3] = 6,
			},
			["Position"] = Vector3.new(0.0002899169921875, 5.303581237792969, -0.0929255485534668),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0.0003204345703125, 7.080780029296875, -1.894972562789917),
		},
		[6] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0.0005950927734375, 7.217742919921875, 1.67169988155365),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
				[2] = 1,
			},
			["Position"] = Vector3.new(-0.0002899169921875, -4.745277404785156, 1.1919578313827515),
		},
	}
}