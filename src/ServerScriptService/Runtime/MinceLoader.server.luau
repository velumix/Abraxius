local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(game.ReplicatedStorage.Modules.Mince)

Mince:LoadConfig(ReplicatedStorage.Runtime.Config)
Mince:LoadConfig(ServerScriptService.Runtime.Config)
Mince:LoadModules(ServerScriptService.Runtime.Source)

Mince:Start()







