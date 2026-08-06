return {
	Name = "giveXp";
	Description = "Give player(s) xp.";
	Group = "GameOwner";
	Args = {
		{
			Type = "string",
			Name = "Category"
		},
		{
			Type = "integer",
			Name = "XP",
			Description = "How much xp you want to give."
		},
		{
			Type = "players";
			Name = "players";
			Description = "The players you would set the level of."; 
		},
	};
}