return {
	Name = "CustomMapStats",
	Aliases = { "cmstats" },
	Description = "Shows likes, dislikes, and load count for a map.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "string",
			Name = "mapId",
			Description = "The unique ID of the map.",
		},
	},
}