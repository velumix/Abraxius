-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService('RunService') 

local Weave = require(ReplicatedStorage.Modules.Weave)

local Inventory = require(ReplicatedStorage.Config.Shared.Inventory) 

local DataManager = Weave.Retrieve("DataManager")
local DataSync = Weave.Retrieve("DataSync")

local InventoryManager = Weave.Retrieve("InventoryManager")

return function (_, Players : {Player}) 
	if Weave.Config.ServerSettings.MainGameID == game.PlaceId then 
		return "Disabled in the main game. DO NOT ENABLE!"
	end
	
	local FormatText = ""
	for _,Player : Player in Players do  
		for CategoryName, InventoryCategoryItems in Inventory do 
			for InventoryItemName, InventoryItem in InventoryCategoryItems do 
				InventoryManager.GiveItem(Player, `{CategoryName}.{InventoryItemName}`)
			end
		end


		FormatText ..= Player.Name
	end

	return `Gave {FormatText} all items!`
end