return {
	Name = "SpawnBoss",
	Aliases = { "Boss" },
	Description = "Spawns a boss on the active map.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "bossName",
			Name = "BossName",
			Description = "The boss to spawn",
		},
	},
}
