return {
	Name = "TestKillEffect",
	Aliases = { "TestKE", "PreviewKillEffect" },
	Description = "Spawns dummies in front of you and plays a kill effect for lobby testing. Use All to line up every effect.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "killEffectTypeAll",
			Name = "KillEffect",
			Description = "The kill effect to preview, or All for every effect.",
		},
	},
}
