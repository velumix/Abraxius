--!strict
-- @author Velumix
-- @version 0.0.1
--[=[
	@class BaselineConfig
	@server
	@client
	Version metadata used by baseline releases and persisted profile migrations.
]=]
--[=[
	@prop Version string
	@within BaselineConfig
	Semantic version of the reusable game baseline.
]=]
--[=[
	@prop ProfileSchemaVersion number
	@within BaselineConfig
	Latest ordered persisted-data schema.
]=]
local BaselineConfig = {
	Version = "2.1.0",
	ProfileSchemaVersion = 2,
}

return table.freeze(BaselineConfig)
