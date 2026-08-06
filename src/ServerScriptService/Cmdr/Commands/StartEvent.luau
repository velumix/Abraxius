return {
	Name = "StartEvent",
	Description = "Starts a server event.",
	Group = "Admin",
	Args = {
		{
			Type = "eventName",
			Name = "event",
			Description = "The event to start",
		},
		{
			Type = "eventStartValue",
			Name = "multiplierOrDuration",
			Description = "Duration in minutes, or a multiplier for BoostLuck/SpeedBoost.",
			Optional = true,
		},
		{
			Type = "positiveDuration",
			Name = "duration",
			Description = "Duration in minutes when using an event multiplier.",
			Optional = true,
		},
	},
}