return {
	Name = "ForcePlay",
	Aliases = { "Play" },
	Description = "Forces the next round to a specific game mode + map (and optional solo role), bypassing the vote.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "gameModeType",
			Name = "GameMode",
			Description = "Game mode id (e.g. hideandseek, reverserace).",
		},
		{
			Type = "mapType",
			Name = "MapName",
			Description = "The map to force for the next round.",
		},
		{
			Type = "soloRoleType",
			Name = "Role",
			Description = "Hider, Hunter, or Off (solo testing; default Off).",
			Optional = true,
		},
	},
}
