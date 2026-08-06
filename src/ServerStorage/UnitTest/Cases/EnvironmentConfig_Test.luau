-- @author Velumix
-- @version 0.0.1
-- Contract tests for Studio data isolation.
return function(t)
	local EnvironmentConfig = require(game.ReplicatedStorage.Config.EnvironmentConfig)
	local expect = t.expect

	-- Studio defaults to mock profiles and never selects the production store.
	t.test("defaults Studio to isolated mock data", function()
		local previous = game:GetAttribute("UseStudioLiveData")
		game:SetAttribute("UseStudioLiveData", false)
		local environment = EnvironmentConfig.Resolve()
		game:SetAttribute("UseStudioLiveData", previous)
		expect.equal(environment.Name, "StudioMock")
		expect.truthy(environment.UseMockData)
		expect.falsy(string.find(environment.StoreName, "Production", 1, true) ~= nil)
	end)

	-- Explicit Studio persistence uses the development store, not production.
	t.test("uses development store for Studio live-data tests", function()
		local previous = game:GetAttribute("UseStudioLiveData")
		game:SetAttribute("UseStudioLiveData", true)
		local environment = EnvironmentConfig.Resolve()
		game:SetAttribute("UseStudioLiveData", previous)
		expect.equal(environment.Name, "StudioDevelopment")
		expect.falsy(environment.UseMockData)
		expect.truthy(string.find(environment.StoreName, "Development", 1, true) ~= nil)
	end)
end
