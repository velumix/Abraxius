return {
	Name = "ForceNextMap",
	Aliases = { "ForceMap" },
	Description = "Forces the next round to play the given map, bypassing the vote.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "mapType",
			Name = "MapType",
			Description = "The map to force for the next round.",
		},
	},
}
