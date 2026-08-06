-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)

local InventoryManager = Mince:Get("InventoryManager")
local PlayerDataManager = Mince:Get("PlayerDataManager")

return function (_, InventoryItemName, Players : {Player})
	local FormatText = ""
	for _,Player : Player in Players do  
		InventoryManager.GiveItem(Player, InventoryItemName)
		
		FormatText ..= Player.Name
	end
	
	return `Gave {FormatText} a '{InventoryItemName}'!`
end