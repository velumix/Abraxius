local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local FishNodes = Mince.Component({
	Tag = "Boid",
})

function FishNodes:Construct()
	self.Node = self.Instance
	self.Attributes = self.Instance:GetAttributes()

	-- Moving school targets are calculated by BoidHybridService and sent as a
	-- compact 5 Hz ByteNet batch. The node remains stationary so Roblox does
	-- not continuously replicate a tweened BasePart position to every client.
end

return FishNodes
