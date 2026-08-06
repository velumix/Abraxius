-- Modules // Services -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local Mince = require(ReplicatedStorage.Modules.Mince)

local InteractableHandler = Mince:Get("InteractableHandler")

local InteractableComponent = Mince.Component {
	Tag = "Interactable",
	Debounce = false,
	CreationParents = { workspace }

}

function InteractableComponent:Construct()
	self.Interactable = InteractableHandler.newInteractable("Test!", self.Instance) 
	self.Interactable:Control("Interact", function(Finish)  
		warn("Interacting....")
		
		Finish() 
	end) 
end

return InteractableComponent

