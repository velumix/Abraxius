return {
	Name = "PlaySolo",
	Aliases = { "Solo" },
	Description = "Solo testing: run the match with just you in the given role, and never auto-end. Use Off to disable.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "soloRoleType",
			Name = "Role",
			Description = "Hider, Hunter (seeker), or Off",
		},
	},
}
