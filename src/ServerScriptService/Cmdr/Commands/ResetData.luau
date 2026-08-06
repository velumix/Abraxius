return {
	Name = "ResetData",
	Aliases = { "ResetStarterPack" },
	Description = "Resets a player's starter pack purchase/timer data.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player whose starter pack data to reset (defaults to you)",
			Optional = true,
		},
	},
}
