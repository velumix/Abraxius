local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "blueAssessor", -- This is the what you set the _fishId arttibute to!
	Name = "Blue Assessor", -- The name of the fish that will show up in the book
	Aliases = { "Assessor macneilli" },
	Model = Assets["Blue Assessor"],
	Icon = "",

	Family = "Plesiopidae",
	Diet = "Zooplankton",
	Size = "6 cm (2.3 in)",
	Depths = "1-20 m (3.3-66 ft)",

	Facts = {
		"The blue assessor is a cave dwelling fish, and is often seen swimming upside down to orient itself with the cave roof!",
		"Assessors are in a group also known as the roundheads. Most are cave or crevice dwellers that hide during the day!",
		"These fish are mouthbrooders, with males incubating eggs in their mouth over a period of 2 weeks.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0, 0.018965434283018112, -0.17034912109375),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
			},
			["Position"] = Vector3.new(0, 0.01896560564637184, 0.13809585571289062),
		},
	} 
}