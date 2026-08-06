return {
	Name = "givecash",
	Aliases = {"cash"},
	Description = "Gives cash to a player",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "The player to give cash to"
		},
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "Amount of cash to give"
		}
	}
}
