local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local BackpackController = {
	Name = "BackpackController",
}

function BackpackController:GameStart()
	task.spawn(function()
		self.BackpackMain = require(script.Main)
	end)
end

return BackpackController