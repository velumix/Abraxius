return {
	Name = "GiveCash",
	Aliases = { "GiveCoins", "GiveMoney" },
	Description = "Grants a player coins.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant coins to",
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "How many coins to grant",
		},
	},
}