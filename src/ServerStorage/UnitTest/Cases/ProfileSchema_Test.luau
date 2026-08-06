-- @author Velumix
-- @version 0.0.1
-- Contract tests for safe profile snapshots, paths, and patches.
return function(t)
	local ProfileSchema = require(game.ReplicatedStorage.Shared.ProfileSchema)
	local expect = t.expect

	-- Client snapshots include allow-listed fields and exclude receipt data.
	t.test("snapshot excludes private profile roots", function()
		local source = {
			Coins = 10,
			Inventory = { Sword = 1 },
			Commerce = { ProcessedReceipts = { secret = true } },
		}
		local snapshot = ProfileSchema.ClientSnapshot(source)
		expect.equal(snapshot.Coins, 10)
		expect.falsy(snapshot.Commerce)
		snapshot.Inventory.Sword = 99
		expect.equal(source.Inventory.Sword, 1)
	end)

	-- Valid paths are bounded identifiers and must start at a visible root.
	t.test("validates client-readable paths", function()
		expect.truthy(ProfileSchema.IsValidRemotePath("Inventory.Sword"))
		expect.truthy(ProfileSchema.IsClientVisible("Inventory.Sword"))
		expect.falsy(ProfileSchema.IsClientVisible("Commerce.ProcessedReceipts"))
		expect.falsy(ProfileSchema.IsValidRemotePath("Inventory..Sword"))
	end)

	-- Applying a patch updates only its selected path.
	t.test("applies changed-value patches", function()
		local data = { Coins = 1, Settings = { MusicEnabled = true } }
		ProfileSchema.ApplyPatch(data, ProfileSchema.MakePatch("Coins", 5))
		expect.equal(data.Coins, 5)
		expect.truthy(data.Settings.MusicEnabled)
	end)

	-- Removal patches represent nil without relying on a missing table field.
	t.test("applies removal patches", function()
		local data = { Inventory = { Sword = 1 } }
		ProfileSchema.ApplyPatch(data, ProfileSchema.MakePatch("Inventory.Sword", nil))
		expect.falsy(data.Inventory.Sword)
	end)
end
