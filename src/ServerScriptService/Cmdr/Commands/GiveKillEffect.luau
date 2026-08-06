return {
	Name = "GiveKillEffect",
	Aliases = { "GrantKillEffect" },
	Description = "Grants a player a kill effect (or All kill effects).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant the kill effect to",
		},
		{
			Type = "killEffectTypeAll",
			Name = "KillEffect",
			Description = "The kill effect to grant, or All for every kill effect",
		},
	},
}
