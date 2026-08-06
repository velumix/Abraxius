return {
	Name = "TopCustomMaps",
	Aliases = { "tcm" },
	Description = "Lists the top maps ranked by likes.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "integer",
			Name = "count",
			Description = "How many maps to list.",
			Optional = true,
			Default = 10,
		},
	},
}