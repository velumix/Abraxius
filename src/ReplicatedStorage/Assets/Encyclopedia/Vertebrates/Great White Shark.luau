local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GWhiteShark", -- This is the what you set the _fishId arttibute to!
	Name = "Great White Shark",
	Aliases = { "Carcharodon carcharias" },
	Model = Assets["Great White Shark"], -- ReplicatedStorage -> Assets -> FishModels 
	Icon = "",

	Family = "Lamnidae",
	Diet = "Mammals and Large Fish",
	Size = "6.4 m (21 ft)",
	Depths = "0-1280 m (0-1499 ft)",

	Facts = {
		"The great white shark is often considered to be the largest predatory shark!",
		"Great whites can be found worldwide, but are most abundant in areas with seal colonies, as this is their perferred food.",
		"Great whites are noted for their spectacular breaches when ambushing prey, where they hurl their entire body out of the water!",
		"Despite being the most famous of sharks, great whites are classed as vulnerable due to a variety of threats.",
		"While one of the sharks responsible for the most attacks, attacks are uncommon and are usually a simple predatory response.",
		"As of writing, reports of great whites getting over 6.4 meters (21 ft) are false and should not be trusted.",
		"The only active predator of great whites is the orca. In one instance, sharks were reported to flee an area when orcas appeared!",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.16521453857421875, -15.294421195983887, -0.18921279907226562),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 7,
				[4] = 8,
				[5] = 9,
			},
			["Position"] = Vector3.new(0.13915252685546875, -5.886059761047363, -0.2614927291870117),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
			},
			["Position"] = Vector3.new(0.11412811279296875, 3.1739864349365234, -0.33109331130981445),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0.09420013427734375, 10.37816047668457, -0.38643836975097656),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
				[2] = 6,
			},
			["Position"] = Vector3.new(0.08242034912109375, 14.632905960083008, -0.4191298484802246),
		},
		[6] = {
			["Links"] = {
				[1] = 5,
			},
			["Position"] = Vector3.new(-0.043426513671875, 19.240398406982422, 5.792313575744629),
		},
		[7] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(-6.845176696777344, -3.280440330505371, -4.998804569244385),
		},
		[8] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(7.175201416015625, -3.2397146224975586, -4.745301246643066),
		},
		[9] = {
			["Links"] = {
				[1] = 2,
			},
			["Position"] = Vector3.new(0.00775909423828125, -1.0346097946166992, 6.2185821533203125),
		},
	}
}