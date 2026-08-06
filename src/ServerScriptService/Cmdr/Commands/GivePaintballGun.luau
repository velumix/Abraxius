return {
	Name = "GivePaintballGun",
	Aliases = { "PaintballGun", "GivePaintball", "Paintball" },
	Description = "Gives the target player a paintball gun for testing. Defaults to the executor.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to give the paintball gun to (defaults to you)",
			Optional = true,
		},
	},
}
