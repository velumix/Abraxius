local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TestService = game:GetService("TestService")

local Knit = require(ReplicatedStorage.Modules.Knit)
local EnvironmentConfig = require(ReplicatedStorage.Config.EnvironmentConfig)

Knit.AddServices(ServerScriptService.Services)

local environment = EnvironmentConfig.Resolve()
print(`[Bootstrap] Environment={environment.Name} Store={environment.StoreName} MockData={environment.UseMockData}`)
Knit.Start():catch(function(err)
	TestService:Warn(false, tostring(err))
end)
