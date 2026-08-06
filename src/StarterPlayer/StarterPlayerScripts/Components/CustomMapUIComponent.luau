
--> Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")


--> Variables
local Packages = ReplicatedStorage.Packages
local Player = Players.LocalPlayer


--> Modules
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local Component = require(Packages.Component)
local Trove = require(Packages.Trove)


--> Setup
local Component = Component.new({ Tag = "CustomMapUI", Ancestors = {Player} })


--> Construction
function Component:Construct()
	self._trove = Trove.new()
end

--> Heartbeat update
--function Component:HeartbeatUpdate()
--end

--> Starter
function Component:Start()
	if not Constants.CUSTOM_MAPS_ENABLED then
		self.Instance:Destroy()
	end
end

--> Stopped
function Component:Stop()
	self._trove:Destroy()
end

return {}