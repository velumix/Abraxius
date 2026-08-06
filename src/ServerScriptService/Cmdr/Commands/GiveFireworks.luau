return {
	Name = "GiveFireworks",
	Aliases = { "GiveFirework" },
	Description = "Grants a player Fireworks (4th of July event currency).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant fireworks to",
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "How many fireworks to grant",
		},
	},
}
