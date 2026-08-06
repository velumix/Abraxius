-- @author Velumix
-- @version 0.0.1
-- Contract coverage for Nerve's server-only ProfileStore dependency.
return function(t)
	local Nerve = require(game.ReplicatedStorage.Modules.Nerve)
	local ProfileStore = Nerve.GetDependency("ProfileStore")
	local expect = t.expect

	t.test("loads ProfileStore through Nerve", function()
		expect.equal(type(ProfileStore.New), "function")
		expect.equal(type(ProfileStore.SetConstant), "function")
	end)

	t.test("creates an isolated mock-capable store", function()
		local store = ProfileStore.New("ProfileStoreContract_Test", {
			Coins = 0,
		})
		expect.truthy(store.Mock)
		expect.equal(type(store.StartSessionAsync), "function")
		expect.equal(type(store.Mock.StartSessionAsync), "function")
	end)
end
