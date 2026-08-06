return {
	Name = "ColorBookReset",
	Description = "Reset a player's coloring-book progress for a map (or all maps).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Target (defaults to you)",
			Optional = true,
		},
		{
			Type = "string",
			Name = "Map",
			Description = "Map to reset (omit to reset ALL maps)",
			Optional = true,
		},
	},
}
