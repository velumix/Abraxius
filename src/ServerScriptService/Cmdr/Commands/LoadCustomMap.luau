return {
	Name = "LoadCustomMap",
	Aliases = { "lcm" },
	Description = "Loads a custom map.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "string",
			Name = "mapId",
			Description = "The map to load",
		},
	},
}
