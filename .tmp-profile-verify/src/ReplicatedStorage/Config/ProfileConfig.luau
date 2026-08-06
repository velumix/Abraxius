-- @author Velumix
-- @version 0.0.1
--[=[
	@class ProfileConfig
	@server
	Shared profile and mutation configuration.
]=]
local ProfileConfig = {}

--[=[
	@prop ExperienceToNextLevel number
	@within ProfileConfig
	Experience consumed per level.
]=]
ProfileConfig.ExperienceToNextLevel = 100
--[=[
	@prop CommitTimeoutSeconds number
	@within ProfileConfig
	Durable mutation timeout.
]=]
ProfileConfig.CommitTimeoutSeconds = 20
--[=[
	@prop CurrencyFields {[string]: boolean}
	@within ProfileConfig
	Fields accepted by `PlayerDataService:AwardCurrency`.
]=]
ProfileConfig.CurrencyFields = table.freeze({
	Coins = true,
	Points = true,
})
--[=[
	@prop AllowedSettings {[string]: string}
	@within ProfileConfig
	Setting names mapped to their required runtime value types.
]=]
ProfileConfig.AllowedSettings = table.freeze({
	MusicEnabled = "boolean",
	SfxEnabled = "boolean",
})

--[=[
	@prop DefaultProfile table
	@within ProfileConfig
	Reconciled profile template used for new and existing players.
]=]
ProfileConfig.DefaultProfile = {
	DataVersion = 1,
	Points = 0,
	Coins = 0,
	Level = 1,
	Experience = 0,
	Inventory = {},
	Settings = {
		MusicEnabled = true,
		SfxEnabled = true,
	},
	Commerce = {
		CommitVersion = 0,
		ProcessedReceipts = {},
		OwnedGamePasses = {},
		Transfers = {
			Requests = {},
			Receipts = {},
		},
	},
}

return ProfileConfig
