return {
	Name = "GiveFrozenKnife",
	Aliases = { "FrozenKnife" },
	Description = "Gives a player a Frozen Knife with a guaranteed random mutation.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to give the knife to (defaults to you)",
			Optional = true,
		},
	},
}
