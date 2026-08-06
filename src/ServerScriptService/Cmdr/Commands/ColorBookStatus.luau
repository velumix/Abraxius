return {
	Name = "ColorBookStatus",
	Description = "Show coloring-book progress for a player on a map.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Whose progress to show (defaults to you)",
			Optional = true,
		},
		{
			Type = "string",
			Name = "Map",
			Description = "Map name (defaults to the active map)",
			Optional = true,
		},
	},
}
