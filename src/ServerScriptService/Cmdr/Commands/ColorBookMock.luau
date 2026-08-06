return {
	Name = "ColorBookMock",
	Description = "DEV: author a temporary ColoringBook (pages x parts) into the ACTIVE map so the other cb commands are testable before real part placement exists. Runtime only; not saved.",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "integer",
			Name = "Pages",
			Description = "How many pages to create",
		},
		{
			Type = "integer",
			Name = "PartsPerPage",
			Description = "How many parts per page",
		},
	},
}
