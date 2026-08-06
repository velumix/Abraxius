return {
	Name = "announce",
	Aliases = { "message", "broadcast" },
	Description = "Show an admin announcement toast (ADMIN style) to players, formatted as you: message. server = this server, global = all servers.",
	Group = "DefaultAdmin",
	Args = {
		{ Type = "announcementType", Name = "Scope", Description = "server (this server) or global (all servers)" },
		{ Type = "string", Name = "Message", Description = "The announcement text (quote it if it has spaces)" },
	},
}
