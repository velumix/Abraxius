return {
	Name = "SpawnHiddenAdmins",
	Aliases = { "HiddenAdmins", "DevHiders" },
	Description = "Spawns mini dev-team NPCs around the map (local = this server, global = all servers). Amount defaults to 5.",
	Group = "DefaultAdmin",
	Args = {
		{ Type = "scope", Name = "Scope", Description = "local (this server) or global (all servers)" },
		{ Type = "integer", Name = "Amount", Optional = true },
	},
}
