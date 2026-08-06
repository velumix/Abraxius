local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince) 

Mince:WaitUntilSetup("Server")
Mince:LoadConfig(ReplicatedStorage.Runtime.Config)
Mince:LoadModules(ReplicatedStorage.Runtime.Source)

Mince:Start()



 

