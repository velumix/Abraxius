return {
	Name = "HugeSize",
	Aliases = { "Huge" },
	Description = "Grows all in-round players or a specific player.",
	Group = "DefaultAdmin",
	Args = {
		{ Type = "number", Name = "Scale", Default = 2, Description = "Size multiplier (0.5 - 5)" },
		{ Type = "string", Name = "PlayerName", Default = "", Description = "Optional: scale only this player" },
	},
}
