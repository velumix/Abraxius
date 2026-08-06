local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets.FishModels

return {
	_id = "GreatBarracuda", -- This is the what you set the _fishId arttibute to!
	Name = "Great Barracuda", -- The name of the fish that will show up in the book
	Aliases = { "Sphyraena barracuda" },
	Model = Assets["Great Barracuda"],
	Icon = "rbxassetid://98314985663989",

	Family = "Sphyraenidae",
	Diet = "Cephalopods and Fish",
	Size = "2 m (6.5 feet)",
	Time = "Day", -- Time of day the fish is active
	Depths = "1-100 m (3.3-328 ft)",

	Facts = {
		"Great barracuda are ambush predators. They can strike prey with bursts of speed up to 58 kmh (36 mph)!",
		"Barracuda are known to follow snorkelers. They are thought to mistake them for a predator that they can scavenge scraps from.",
		"Barracuda bites on humans are very rare, and most cases are likely due to bad visibilty or a shiny object confusing the fish.",
		"While large adult great barracuda are solitary, juveniles will form large schools in open water.",
	},
	
	Skeleton = {
		[1] = {
			["Links"] = {
				[1] = 2,
				[2] = 6,
			},
			["Position"] = Vector3.new(0, -0.4030876159667969, -5.755372047424316),
		},
		[2] = {
			["Links"] = {
				[1] = 1,
				[2] = 3,
				[3] = 6,
			},
			["Position"] = Vector3.new(0, -0.6474908590316772, -2.84375),
		},
		[3] = {
			["Links"] = {
				[1] = 2,
				[2] = 4,
				[3] = 6,
			},
			["Position"] = Vector3.new(0, 0.03590714931488037, -0.9886064529418945),
		},
		[4] = {
			["Links"] = {
				[1] = 3,
				[2] = 5,
			},
			["Position"] = Vector3.new(0, 0.03590714931488037, 2.0815601348876953),
		},
		[5] = {
			["Links"] = {
				[1] = 4,
			},
			["Position"] = Vector3.new(0, 0.03590714931488037, 4.478193283081055),
		},
		[6] = {
			["Links"] = {
				[1] = 1,
				[2] = 2,
				[3] = 3,
			},
			["Position"] = Vector3.new(0, 0.453920841217041, -2.84725284576416),
		},
	}
}