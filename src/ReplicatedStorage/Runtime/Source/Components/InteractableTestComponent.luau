-- Modules // Services -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local Mince = require(ReplicatedStorage.Modules.Mince)

local InteractIndicator = Mince:Get("InteractIndicator")

local InteractableComponent = Mince.Component {
	Tag = "InteractableTest",
	Debounce = false,
	CreationParents = { workspace }

}

function InteractableComponent:Construct()
	warn("Creating new!!!1")
	
	self.Instance.Transparency = 1 
	
	
	self.ProximityPrompt = InteractIndicator.new(self.Instance).ProximityPrompt
	self.ProximityPrompt.ObjectText = "Test!"
end

return InteractableComponent

