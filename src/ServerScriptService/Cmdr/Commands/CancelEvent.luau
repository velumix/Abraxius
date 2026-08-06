return {
	Name = "CancelEvent",
	Aliases = { "StopEvent" },
	Description = "Cancels an active event on this server.",
	Group = "Admin",
	Args = {
		{
			Type = "eventName",
			Name = "event",
			Description = "The event to cancel",
		},
	},
}
