local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")

local ServerStorage = game:GetService("ServerStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)
local PlayerDataManager = Mince:Get("PlayerDataManager")
local KitService = Mince:Get("KitService")
local ToolService = Mince:Get("ToolService")
local CurrencyService = Mince:Get("CurrencyService")
local StoreItems = Mince.Config.StoreItems

local SpeedBoostService = require(ServerStorage.Modules.Services.SpeedBoostService)

--[[
	@class StoreService
	@server

	Store purchase, equip, and inventory synchronization service.
]]

local StoreService = {
	Name = "StoreService",
}
local RobuxPriceCache = {}

local function resolveSlot(category, itemData, itemName)
	if itemData and itemData.Slot then
		return itemData.Slot
	end

	if category == "Gear" then
		return "DiveMask"
	end

	return itemName
end

local function getAssetId(itemData)
	if not itemData then
		return nil
	end
	return itemData.AssetId or itemData.RobuxAssetId
end

local function getRobuxPrice(itemData)
	if not itemData or not itemData.RobuxAssetId then
		return nil
	end

	local assetId = itemData.RobuxAssetId
	if RobuxPriceCache[assetId] ~= nil then
		return RobuxPriceCache[assetId]
	end

	local success, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId, Enum.InfoType.Asset)
	local price = success and info and info.PriceInRobux or nil
	if price and price > 0 then
		RobuxPriceCache[assetId] = price
	else
		RobuxPriceCache[assetId] = nil
	end

	return RobuxPriceCache[assetId]
end

function StoreService:GrantOwnedAssetItem(player, profile, category, itemName, itemData)
	if not player or not profile or not profile.Data then
		return false
	end
	if category ~= "Cosmetics" and category ~= "Tools" then
		return false
	end

	local assetId = getAssetId(itemData)
	if not assetId then
		return false
	end

	local success, owns = pcall(MarketplaceService.PlayerOwnsAsset, MarketplaceService, player, assetId)
	if not success or not owns then
		return false
	end
	profile.Data.OwnedItems = profile.Data.OwnedItems or {}
	local ownedItems = profile.Data.OwnedItems
	if ownedItems[itemName] and ownedItems[itemName].Owned then
		return true
	end

	ownedItems[itemName] = {
		Owned = true,
		Equipped = false,
		Category = category,
		Slot = resolveSlot(category, itemData, itemName),
		PurchasedAt = os.time(),
		Source = "Robux",
	}

	PlayerDataManager:UpdatePlayer(player, "OwnedItems")
	return true
end

function StoreService:SyncCosmeticAssetOwnership(player, profile)
	if not player or not profile or not profile.Data then
		return false
	end

	local ownedItems = profile.Data.OwnedItems or {}
	local modified = false

	local categories = {
		Cosmetics = StoreItems.Categories and StoreItems.Categories.Cosmetics or {},
		Tools = StoreItems.Categories and StoreItems.Categories.Tools or {},
	}

	for categoryName, items in pairs(categories) do
		for itemName, itemData in pairs(items) do
			local assetId = getAssetId(itemData)
			if assetId then
				local state = ownedItems[itemName]
				if not state or not state.Owned then
					local success, owns = pcall(MarketplaceService.PlayerOwnsAsset, MarketplaceService, player, assetId)
					if success and owns then
						ownedItems[itemName] = {
							Owned = true,
							Equipped = false,
							Category = categoryName,
							Slot = resolveSlot(categoryName, itemData, itemName),
							PurchasedAt = os.time(),
							Source = "Robux",
						}
						modified = true
					end
				end
			end
		end
	end

	if modified then
		profile.Data.OwnedItems = ownedItems
		PlayerDataManager:UpdatePlayer(player, "OwnedItems")
	end

	return modified
end

function StoreService:PreloadCosmeticAssets()
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		warn("Assets folder not found in ReplicatedStorage")
		return
	end

	local cosmeticsFolder = assetsFolder:FindFirstChild("Cosmetics")
	if not cosmeticsFolder then
		cosmeticsFolder = Instance.new("Folder")
		cosmeticsFolder.Name = "Cosmetics"
		cosmeticsFolder.Parent = assetsFolder
	end

	local cosmetics = StoreItems.Categories and StoreItems.Categories.Cosmetics or {}
	for itemName, itemData in pairs(cosmetics) do
		if itemData.Slot == "Tool" or itemData.Slot == "Plushie" then
			continue
		end
		if itemData.RobuxAssetId and not cosmeticsFolder:FindFirstChild(itemName) then
			local assetId = getAssetId(itemData)
			if assetId then
				local success, model = pcall(InsertService.LoadAsset, InsertService, assetId)
				if success and model then
					local accessory = model:FindFirstChildWhichIsA("Accessory", true)
					if accessory then
						accessory.Name = itemName
						accessory.Parent = cosmeticsFolder
						itemData.Object = accessory
					else
						warn("No accessory found in asset", assetId)
					end
					model:Destroy()
				else
					warn("Failed to load cosmetic asset", assetId)
				end
			end
		end
	end
end

local function applyToolLoadout(player)
	if ToolService and ToolService.ApplyPlayerTools then
		ToolService:ApplyPlayerTools(player)
	end
end

local function CalculateGearStats(profile)
	local stats = {
		OxygenCapacity = 30,
		OxygenEfficiency = 0.5,
		MaxDepth = 50,
		SwimSpeed = 1.0,
		UnderwaterRegen = false,
	}

	for itemName, itemState in pairs(profile.OwnedItems or {}) do
		if itemState.Equipped then
			for _, items in pairs(StoreItems.Categories) do
				if items[itemName] and items[itemName].Stats then
					local itemStats = items[itemName].Stats
					stats.OxygenCapacity = stats.OxygenCapacity + (itemStats.OxygenCapacity or 0)
					stats.OxygenEfficiency = stats.OxygenEfficiency + (itemStats.OxygenEfficiency or 0)
					stats.MaxDepth = stats.MaxDepth + (itemStats.MaxDepth or 0)
					stats.SwimSpeed = stats.SwimSpeed + (itemStats.SwimSpeed or 0)
					if itemStats.UnderwaterRegen then
						stats.UnderwaterRegen = true
					end
				end
			end
		end
	end

	return stats
end

local function UpdateCharacterStats(player, stats)
	local character = player.Character
	if not character then
		return
	end

	character:SetAttribute("MaxOxygen", stats.OxygenCapacity)

	local currentOxygen = character:GetAttribute("Oxygen") or 0
	if currentOxygen < stats.OxygenCapacity then
		character:SetAttribute("Oxygen", stats.OxygenCapacity)
	else
		character:SetAttribute("Oxygen", math.min(currentOxygen, stats.OxygenCapacity))
	end

	local baseDepletion = 1
	character:SetAttribute("OxygenDepletionRate", baseDepletion / stats.OxygenEfficiency)
	character:SetAttribute("UnderwaterRegen", stats.UnderwaterRegen == true)

	player:SetAttribute("MaxDepth", stats.MaxDepth)
	SpeedBoostService:SetBase(player, stats.SwimSpeed)
end

function StoreService:Setup()
	local storeComm = Mince:GetEvent("StoreEvents")

	self.PurchaseRequest = storeComm:Extend("PurchaseRequest")
	self.PurchaseRequest.Event:Connect(function(player, category, itemName)
		self:HandlePurchase(player, category, itemName)
	end)

	self.EquipRequest = storeComm:Extend("EquipRequest")
	self.EquipRequest.Event:Connect(function(player, category, itemName, slot)
		self:HandleEquip(player, category, itemName, slot)
	end)

	self.UnequipRequest = storeComm:Extend("UnequipRequest")
	self.UnequipRequest.Event:Connect(function(player, itemName)
		self:HandleUnequip(player, itemName)
	end)

	self.RequestInventory = storeComm:Extend("RequestInventory")
	self.RequestInventory.Event:Connect(function(player)
		self:SendInventory(player)
	end)

	self.GiftRequest = storeComm:Extend("GiftRequest")
	self.GiftRequest.Event:Connect(function(player, category, itemName, targetUserId)
		self:HandleGift(player, category, itemName, targetUserId)
	end)

	self.PurchaseResult = storeComm:Extend("PurchaseResult")
	self.EquipResult = storeComm:Extend("EquipResult")
	self.InventorySync = storeComm:Extend("InventorySync")
	self.GearStatsUpdate = storeComm:Extend("GearStatsUpdate")
	self.GiftResult = storeComm:Extend("GiftResult")

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local profile = PlayerDataManager:GetProfile(player)
			if profile and profile.Data then
				local stats = CalculateGearStats(profile.Data)
				profile.Data.GearStats = stats
				UpdateCharacterStats(player, stats)
				KitService:BuildAndEquipKit(player, profile.Data.OwnedItems)
				KitService:ApplyCosmetics(player, profile.Data.OwnedItems)
			else
				return warn("No profile data for", player.Name)
			end
		end)
	end)
end

function StoreService:HandleGift(player, category, itemName, targetUserId)
	if typeof(category) ~= "string" or typeof(itemName) ~= "string" or typeof(targetUserId) ~= "number" then
		self.GiftResult:Fire(player, false, "Invalid gift request")
		return
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		self.GiftResult:Fire(player, false, "Select another online player")
		return
	end

	local itemData = StoreItems.Categories[category] and StoreItems.Categories[category][itemName]
	if not itemData or itemData.Hidden or itemData.Gamepass then
		self.GiftResult:Fire(player, false, "This item cannot be gifted")
		return
	end

	local price = tonumber(itemData.Price) or 0
	if price <= 0 then
		self.GiftResult:Fire(player, false, "This item cannot be gifted")
		return
	end

	local giverProfile = PlayerDataManager:GetProfile(player)
	local targetProfile = PlayerDataManager:GetProfile(target)
	if not giverProfile or not giverProfile.Data or not targetProfile or not targetProfile.Data then
		self.GiftResult:Fire(player, false, "Player data is not ready")
		return
	end

	targetProfile.Data.OwnedItems = targetProfile.Data.OwnedItems or {}
	local existing = targetProfile.Data.OwnedItems[itemName]
	if existing and existing.Owned then
		self.GiftResult:Fire(player, false, target.DisplayName .. " already owns this item")
		return
	end

	local paid
	if category == "Cosmetics" then
		paid = CurrencyService:SpendEcoPoints(player, price, "Gift:" .. itemName)
	else
		paid = CurrencyService:SpendCurrency(player, price, "Gift:" .. itemName)
	end
	if not paid then
		self.GiftResult:Fire(player, false, "Insufficient funds")
		return
	end

	targetProfile.Data.OwnedItems[itemName] = {
		Owned = true,
		Equipped = false,
		Category = category,
		Slot = resolveSlot(category, itemData, itemName),
		PurchasedAt = os.time(),
		Source = "Gift",
		GiftedBy = player.UserId,
	}
	PlayerDataManager:UpdatePlayer(target, "OwnedItems")

	self.GiftResult:Fire(player, true, string.format("Gifted %s to %s", itemName, target.DisplayName))
	self:SendInventory(player)
	self:SendInventory(target)
end

--[[
	Processes item purchase requests and inventory grants.

	@within StoreService
	@param player Player
	@param category string
	@param itemName string
]]
function StoreService:HandlePurchase(player, category, itemName)
	local profile = PlayerDataManager:GetProfile(player)
	if not profile or not profile.Data then
		self.PurchaseResult:Fire(player, false, "Profile not loaded")
		return
	end

	local itemData = StoreItems.Categories[category] and StoreItems.Categories[category][itemName]
	if not itemData then
		self.PurchaseResult:Fire(player, false, "Item not found")
		return
	end

	local assetId = getAssetId(itemData)
	profile.Data.OwnedItems = profile.Data.OwnedItems or {}

	if assetId then
		if self:GrantOwnedAssetItem(player, profile, category, itemName, itemData) then
			self.PurchaseResult:Fire(player, false, "Already owned")
			self:SendInventory(player)
			return
		end
	end

	if profile.Data.OwnedItems[itemName] then
		self.PurchaseResult:Fire(player, false, "Already owned")
		return
	end

	if itemData.Prerequisites then
		for _, prerequisite in ipairs(itemData.Prerequisites) do
			if not profile.Data.OwnedItems[prerequisite] or not profile.Data.OwnedItems[prerequisite].Owned then
				self.PurchaseResult:Fire(player, false, `Requires {prerequisite}`)
				return
			end
		end
	end

	if itemData.Gamepass then
		local passDef = itemData.Gamepass
		if type(passDef) == "string" then
			for _, config in pairs(Mince.Config) do
				if
					type(config) == "table"
					and (config.Key == passDef or config.Name == passDef)
					and config.EntitlementAttribute
				then
					passDef = config
					break
				end
			end
		end

		if type(passDef) == "table" and passDef.EntitlementAttribute then
			if not player:GetAttribute(passDef.EntitlementAttribute) then
				self.PurchaseResult:Fire(player, false, `Requires {passDef.Name or passDef.Key or "Gamepass"}`)
				return
			end
		end
	end

	local price = itemData.Price

	local isCosmetics = category == "Cosmetics"

	if itemData.RobuxAssetId and not isCosmetics then
		local robuxPrice = getRobuxPrice(itemData)
		if robuxPrice then
			price = robuxPrice
		end
	end

	if itemData.Gamepass then
		price = 0
	end

	if isCosmetics then
		if price > 0 and not CurrencyService:SpendEcoPoints(player, price, itemName) then
			self.PurchaseResult:Fire(player, false, "Insufficient funds")
			return
		end
	else
		if price > 0 and not CurrencyService:SpendCurrency(player, price, itemName) then
			self.PurchaseResult:Fire(player, false, "Insufficient funds")
			return
		end
	end

	local slot = resolveSlot(category, itemData, itemName)

	profile.Data.OwnedItems[itemName] = {
		Owned = true,
		Equipped = false,
		Category = category,
		Slot = slot,
		PurchasedAt = os.time(),
	}

	profile.Data.Statistics.PurchasesMade = (profile.Data.Statistics.PurchasesMade or 0) + 1

	PlayerDataManager:UpdatePlayer(player, "OwnedItems")
	PlayerDataManager:UpdatePlayer(player, "Statistics")

	self.PurchaseResult:Fire(player, true, "Purchase successful!", itemName)
	self:SendInventory(player)
end

function StoreService:HandleEquip(player, category, itemName, slot)
	local profile = PlayerDataManager:GetProfile(player)
	if not profile or not profile.Data then
		self.EquipResult:Fire(player, false, "Profile not loaded")
		return
	end

	local itemData = StoreItems.Categories[category] and StoreItems.Categories[category][itemName]
	local assetId = getAssetId(itemData)

	profile.Data.OwnedItems = profile.Data.OwnedItems or {}
	local itemState = profile.Data.OwnedItems[itemName]
	if not itemState or not itemState.Owned then
		if assetId and self:GrantOwnedAssetItem(player, profile, category, itemName, itemData) then
			itemState = profile.Data.OwnedItems[itemName]
		end
	end

	if not itemState or not itemState.Owned then
		self.EquipResult:Fire(player, false, "Item not owned")
		return
	end

	if not slot then
		slot = resolveSlot(category, itemData, itemName)
	end

	local isToolLike = slot == "Tool" or slot == "Plushie"
	if not isToolLike and itemData and typeof(itemData.Object) == "Instance" and itemData.Object:IsA("Tool") then
		isToolLike = true
	end
	if slot and not isToolLike then
		for name, state in pairs(profile.Data.OwnedItems) do
			if state.Equipped and state.Slot == slot and name ~= itemName then
				state.Equipped = false
			end
		end
	end

	itemState.Equipped = true
	itemState.Slot = slot

	local stats = CalculateGearStats(profile.Data)
	UpdateCharacterStats(player, stats)

	if itemState.Category == "Gear" then
		KitService:BuildAndEquipKit(player, profile.Data.OwnedItems)
	elseif itemState.Category == "Tools" or itemState.Slot == "Tool" or itemState.Slot == "Plushie" then
		applyToolLoadout(player)
	elseif itemState.Category == "Cosmetics" then
		KitService:ApplyCosmetics(player, profile.Data.OwnedItems)
	end

	profile.Data.Statistics.CosmeticsEquipped = (profile.Data.Statistics.CosmeticsEquipped or 0) + 1

	PlayerDataManager:UpdatePlayer(player, "OwnedItems")
	PlayerDataManager:UpdatePlayer(player, "Statistics")

	self.EquipResult:Fire(player, true, "Item equipped!", itemName, slot)

	self:SendInventory(player)
	self.GearStatsUpdate:Fire(player, stats)
end

function StoreService:HandleUnequip(player, itemName)
	local profile = PlayerDataManager:GetProfile(player)
	if not profile or not profile.Data then
		self.EquipResult:Fire(player, false, "Profile not loaded")
		return
	end

	profile.Data.OwnedItems = profile.Data.OwnedItems or {}
	local itemState = profile.Data.OwnedItems[itemName]

	if itemState and itemState.Equipped then
		itemState.Equipped = false

		if itemState.Category == "Gear" then
			local stats = CalculateGearStats(profile.Data)
			UpdateCharacterStats(player, stats)
			self.GearStatsUpdate:Fire(player, stats)
			KitService:BuildAndEquipKit(player, profile.Data.OwnedItems)
		elseif itemState.Category == "Tools" or itemState.Slot == "Tool" or itemState.Slot == "Plushie" then
			applyToolLoadout(player)
		elseif itemState.Category == "Cosmetics" then
			KitService:ApplyCosmetics(player, profile.Data.OwnedItems)
		end

		PlayerDataManager:UpdatePlayer(player, "OwnedItems")
		self.EquipResult:Fire(player, true, "Item unequipped", itemName)
		self:SendInventory(player)
	end
end

function StoreService:SendInventory(player)
	local profile = PlayerDataManager:GetProfile(player)
	if not profile or not profile.Data then
		return
	end

	self:SyncCosmeticAssetOwnership(player, profile)

	local inventoryData = {
		OwnedItems = profile.Data.OwnedItems or {},
		Balance = profile.Data.Currency.Balance or 0,
		EcoBalance = (profile.Data.EcoPoints and profile.Data.EcoPoints.Balance) or 0,
	}

	self.InventorySync:Fire(player, inventoryData)
end

return StoreService
