return {
	Name = "giveCurrency";
	Description = "Give player(s) currency.";
	Group = "GameOwner";
	Args = {
		{
			Type = "currencytype",
			Name = "Category"
		},
		{
			Type = "integer",
			Name = "Currency",
			Description = "How much currency you want to give."
		},
		{
			Type = "players";
			Name = "players";
			Description = "The players you would set the level of."; 
		},
	};
}