return {
	Name = "TestPose",
	Aliases = { "TestPose", "PreviewPose" },
	Description = "Spawns dummies in front of you and holds a pose for lobby testing. Use All to line up every pose.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "poseTypeAll",
			Name = "Pose",
			Description = "The pose to preview, or All for every pose.",
		},
	},
}
