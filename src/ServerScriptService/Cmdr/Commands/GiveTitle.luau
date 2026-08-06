return {
	Name = "GiveTitle",
	Aliases = { "GivePlayerTitle" },
	Description = "Grants a nametag Title to a player (equips it by default so it shows above their head).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant the title to",
		},
		{
			Type = "titleType",
			Name = "TitleId",
			Description = "The title to grant (autocompletes from all defined titles)",
		},
		{
			Type = "boolean",
			Name = "Equip",
			Description = "Equip the title immediately so it shows above their head (default true)",
			Optional = true,
		},
	},
}
