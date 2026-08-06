return {
	Name = "BoostLuck",
	Description = "Starts a server luck boost.",
	Group = "Admin",
	Args = {
		{
			Type = "boostType",
			Name = "multiplier",
			Description = "Luck multiplier: 1, 2, 3, 4, 5, and so on.",
			Optional = true,
		},
		{
			Type = "positiveDuration",
			Name = "time",
			Description = "Duration in minutes.",
			Optional = true,
		},
	},
}