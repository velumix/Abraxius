--!strict
-- @author Velumix
-- @version 0.0.1
-- Don't rename live funnels or steps. Make a new version instead.
export type FunnelDefinition = {
	Kind: "Onboarding" | "Recurring",
	Steps: { [number]: string },
}

export type CustomEventDefinition = {
	CooldownSeconds: number,
}

export type Config = {
	Enabled: boolean,
	LogInStudio: boolean,
	Funnels: { [string]: FunnelDefinition },
	CustomEvents: { [string]: CustomEventDefinition },
	Economy: {
		DefaultSourceTransaction: string,
		DefaultSinkTransaction: string,
		TransactionByReason: { [string]: string },
	},
}

local AnalyticsConfig: Config = {
	Enabled = true,
	LogInStudio = false,
	Economy = {
		DefaultSourceTransaction = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		DefaultSinkTransaction = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		-- Override the transaction type for known mutation reasons here.
		TransactionByReason = {},
	},
	-- Custom events have to be registered here before they can be logged.
	CustomEvents = {},
	Funnels = {
		Onboarding = {
			Kind = "Onboarding",
			Steps = {
				[1] = "Player Joined",
				[2] = "Profile Loaded",
				[3] = "Weapon Equipped",
				[4] = "Weapon Fired",
				[5] = "Target Hit",
			},
		},
	},
}

return table.freeze(AnalyticsConfig)
