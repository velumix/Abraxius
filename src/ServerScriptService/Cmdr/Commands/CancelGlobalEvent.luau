return {
	Name = "CancelGlobalEvent",
	Aliases = { "StopGlobalEvent", "CGE" },
	Description = "Cancels an active event across all servers. If no event is provided, cancels every active global event.",
	Group = "Admin",
	Args = {
		{
			Type = "eventName",
			Name = "event",
			Description = "The event to cancel globally",
			Optional = true,
		},
	},
}
