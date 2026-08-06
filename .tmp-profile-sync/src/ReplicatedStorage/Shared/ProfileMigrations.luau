--!strict
-- @author Velumix
-- @version 0.0.1
-- Ordered, idempotent migrations for profiles created by older baseline versions.
--[=[
	@class ProfileMigrations
	@server
	Applies every missing persisted-data migration in ascending version order.
]=]
local BaselineConfig = require(script.Parent.Parent.Config.BaselineConfig)

local migrations: { [number]: (data: { [any]: any }) -> () } = {
	[1] = function(data)
		data.Inventory = data.Inventory or {}
		data.Settings = data.Settings or {}
		if data.Settings.MusicEnabled == nil then
			data.Settings.MusicEnabled = true
		end
		if data.Settings.SfxEnabled == nil then
			data.Settings.SfxEnabled = true
		end
	end,
}

local ProfileMigrations = {}

--[=[
	Upgrades a profile in place to the current schema. Throws when the profile was
	created by a newer, incompatible server schema.

	@param data {[any]: any}
	@return number -- Previous schema version.
	@return number -- Current schema version after migration.
]=]
function ProfileMigrations.Apply(data: { [any]: any }): (number, number)
	local fromVersion = tonumber(data.DataVersion) or 0
	assert(fromVersion <= BaselineConfig.ProfileSchemaVersion, "profile schema is newer than this server")
	for version = fromVersion + 1, BaselineConfig.ProfileSchemaVersion do
		local migration = migrations[version]
		assert(migration ~= nil, `missing profile migration {version}`)
		migration(data)
		data.DataVersion = version
	end
	return fromVersion, tonumber(data.DataVersion) or 0
end

return table.freeze(ProfileMigrations)
