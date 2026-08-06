return {
	Name = "GiveWeapon",
	Aliases = { "GrantWeapon" },
	Description = "Grants a player a weapon skin (or All weapons).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant the weapon to",
		},
		{
			Type = "weaponTypeAll",
			Name = "Weapon",
			Description = "The weapon to grant, or All for every weapon",
		},
	},
}
