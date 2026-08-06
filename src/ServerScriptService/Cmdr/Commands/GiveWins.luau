return {
	Name = "GiveWins",
	Aliases = { "GiveWin" },
	Description = "Grants wins to a player.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant wins to",
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "How many wins to grant",
		},
	},
}