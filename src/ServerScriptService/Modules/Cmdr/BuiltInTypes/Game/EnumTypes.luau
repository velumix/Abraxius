local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Inventory = require(ReplicatedStorage.Runtime.Config.Shared.Inventory) 
--local Abilities = require(ReplicatedStorage.Runtime.Config.Shared.Abilities)

local Util = require(script.Parent.Parent.Shared.Util)

return function (registry)
	local ItemNames, AbilityNames = {}, {}  
	local CurrencyTypes = {"Coins", "Holiday"} 
	for CategoryName, InventoryCategoryItems in Inventory do 
		for InventoryItemName, InventoryItem in InventoryCategoryItems do 
			table.insert(ItemNames, `{CategoryName}.{InventoryItemName}`)
		end
	end
	
	--[[for AbilityName, Ability in Abilities do 
		if Ability.Type == "Consumable" then 
			table.insert(AbilityNames, AbilityName)
		end
	end]]

	registry:RegisterType("abilityname", registry.Cmdr.Util.MakeEnumType("Ability Names", AbilityNames))
	registry:RegisterType("itemname", registry.Cmdr.Util.MakeEnumType("Item Name", ItemNames))
	registry:RegisterType("currencytype", registry.Cmdr.Util.MakeEnumType("Currency Type", CurrencyTypes))
end
