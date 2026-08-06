local ReplicatedStorage = game:GetService("ReplicatedStorage")
local clientFolder = script.Parent
local TestService = game:GetService("TestService")

local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))

Knit.AddControllers(clientFolder.Controllers)
Knit.Start():catch(function(err)
	TestService:Warn(false, tostring(err))
end)
