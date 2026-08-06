return {
	Name = "GivePose",
	Aliases = { "GrantPose" },
	Description = "Grants a player a pose (or All poses).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to grant the pose to",
		},
		{
			Type = "poseTypeAll",
			Name = "Pose",
			Description = "The pose to grant, or All for every pose",
		},
	},
}
