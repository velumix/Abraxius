return {
	Name = "StartAdminSeeker",
	Aliases = { "AdminSeeker" },
	Description = "Gives one seeker admin abilities for a duration (local = this server, global = all servers).",
	Group = "DefaultAdmin",
	Args = {
		{ Type = "scope", Name = "Scope", Description = "local (this server) or global (all servers)" },
		{ Type = "integer", Name = "Duration", Optional = true },
	},
}
