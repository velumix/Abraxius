local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Inventory = require(ReplicatedStorage.Config.Shared.Inventory) 


local Util = require(script.Parent.Parent.Shared.Util)


return function (registry)
	local ItemNames = {} 
	local CurrencyTypes = {"Coins", "Holiday"} 
	for CategoryName, InventoryCategoryItems in Inventory do 
		for InventoryItemName, InventoryItem in InventoryCategoryItems do 
			table.insert(ItemNames, `{CategoryName}.{InventoryItemName}`)
		end
	end

	registry:RegisterType("itemname", registry.Cmdr.Util.MakeEnumType("Item Name", ItemNames))
	registry:RegisterType("currencytype", registry.Cmdr.Util.MakeEnumType("Currency Type", CurrencyTypes))
end
