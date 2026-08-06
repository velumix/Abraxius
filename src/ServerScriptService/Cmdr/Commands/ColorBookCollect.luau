return {
	Name = "ColorBookCollect",
	Description = "Collect a coloring-book part (or 'all' parts of a page) for a player.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "coloringBookPage",
			Name = "Page",
			Description = "Page id, e.g. Page1",
		},
		{
			Type = "coloringBookPart",
			Name = "Part",
			Description = "Part id (e.g. Book1), or 'all' for every part of the page",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Target (defaults to you)",
			Optional = true,
		},
		{
			Type = "mapType",
			Name = "Map",
			Description = "Map name (defaults to the active map)",
			Optional = true,
		},
	},
}
