return {
	Name = "banId";
	Description = "Bans player(s) for a duration of time.";
	Group = "GameBanPermission";
	Args = {
		{
			Type = "string",
			Name = "Reason",
			Description = "The reason for the ban."
		},
		{
			Type = "duration",
			Name = "Duration",
			Description = "The duration of the ban. (-1: Forever)"
		},
		{
			Type = "number";
			Name = "PlayerID";
			Description = "The PlayerID of the player to ban."; 
		},
	};
}