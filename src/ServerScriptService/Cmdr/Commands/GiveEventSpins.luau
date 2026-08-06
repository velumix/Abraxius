return {
	Name = "GiveEventSpins",
	Aliases = { "GiveFireworkSpins", "GiveJulySpins" },
	Description = "Grants a player 4th of July event crate spins.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant event spins to",
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "How many event crate spins to grant",
		},
	},
}
