return {
	Name = "giveItem";
	Description = "Give player(s) items.";
	Group = "GameOwner";
	Args = {
		{
			Type = "itemname",
			Name = "Item", 
			Description = "The name of the item you would like to give!."; 
		},
		{
			Type = "players";
			Name = "players";
			Description = "The players you want to give the item to!."; 
		},
	};
}