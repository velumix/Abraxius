return {
	Name = "OpenCrate",
	Aliases = { "Unbox" },
	Description = "Opens a crate for yourself (rolls + grants a knife with the unbox animation).",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "crateType",
			Name = "CrateType",
			Description = "The crate to open",
		},
		{
			Type = "integer",
			Name = "Amount",
			Description = "How many crates to open (1-3)",
			Optional = true,
		},
	},
}
