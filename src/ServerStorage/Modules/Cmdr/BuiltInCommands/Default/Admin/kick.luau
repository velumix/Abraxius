return {
	Name = "givec";
	Aliases = {"boot"};
	Description = "Give currency to a player.";
	Group = "DefaultAdmin";
	Args = {
		{
			Type = "player";
			Name = "player";
			Description = "The players to give to.";
		},
	};
}