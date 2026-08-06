return {
	Name = "configflag",
	Aliases = {"cflag"},
	Description = "Override a ConfigParam flag on all running servers immediately (bridges ConfigService's slow propagation).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "configFlagKey",
			Name = "key",
			Description = "Config flag to toggle",
		},
		{
			Type = "boolean",
			Name = "value",
			Description = "true or false",
		},
	},
}
