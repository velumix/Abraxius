return {
	Name = "WipeData",
	Aliases = { "ResetPlayerData" },
	Description = "Fully resets a player's DataService profile (coins, inventory, levels, etc.).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player whose data to wipe (defaults to you)",
			Optional = true,
		},
	},
}
