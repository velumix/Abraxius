-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage.Modules.Weave)

local DataManager = Weave.Retrieve("DataManager")
local DataSync = Weave.Retrieve("DataSync")

local InventoryManager = Weave.Retrieve("InventoryManager")

return function (_, InventoryItemName, Players : {Player})
	local FormatText = ""
	for _,Player : Player in Players do  
		InventoryManager.GiveItem(Player, InventoryItemName)
		
		FormatText ..= Player.Name
	end
	
	return `Gave {FormatText} a '{InventoryItemName}'!`
end