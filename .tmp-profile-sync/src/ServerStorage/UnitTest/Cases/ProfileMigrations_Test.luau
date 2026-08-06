-- @author Velumix
-- @version 0.0.1
-- Contract tests for ordered and idempotent profile migrations.
return function(t)
	local ProfileMigrations = require(game.ReplicatedStorage.Shared.ProfileMigrations)
	local expect = t.expect

	-- Legacy profiles receive the current version and required defaults.
	t.test("upgrades a legacy profile", function()
		local data = { Coins = 5 }
		local fromVersion, toVersion = ProfileMigrations.Apply(data)
		expect.equal(fromVersion, 0)
		expect.equal(toVersion, 1)
		expect.equal(data.DataVersion, 1)
		expect.truthy(data.Settings.MusicEnabled)
	end)

	-- Applying migrations repeatedly does not change current data.
	t.test("is idempotent for current profiles", function()
		local data = { DataVersion = 1, Settings = { MusicEnabled = false, SfxEnabled = true }, Inventory = {} }
		local fromVersion, toVersion = ProfileMigrations.Apply(data)
		expect.equal(fromVersion, 1)
		expect.equal(toVersion, 1)
		expect.falsy(data.Settings.MusicEnabled)
	end)

	-- A server refuses to load data created by a newer incompatible schema.
	t.test("rejects profiles from a newer schema", function()
		expect.throws(function()
			ProfileMigrations.Apply({ DataVersion = 999 })
		end)
	end)
end
