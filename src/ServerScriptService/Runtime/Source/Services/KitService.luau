local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local Modules = ReplicatedStorage.Modules
local Assets = ServerStorage.Assets
local Kits = Assets.Kits
local GearAssets = ReplicatedStorage.Assets.Gear

local Mince = require(Modules.Mince)
local StoreItems = require(ReplicatedStorage.Runtime.Config.StoreItems)

local KitService = {
	Name = "KitService",
	Connections = {}
}

local CosmeticAssetCache = {}

local function getToolSpeedMultiplier(itemData)
	local stats = itemData and itemData.Stats
	if not stats then
		return nil
	end

	local multiplier = stats.SwimSpeedMultiplier or stats.SpeedMultiplier
	if typeof(multiplier) == "number" then
		return math.max(multiplier, 0)
	end

	local swimSpeed = stats.SwimSpeed
	if typeof(swimSpeed) == "number" then
		return math.max(1 + swimSpeed, 0)
	end

	return nil
end

local function getCosmeticSource(itemData)
	if not itemData then return nil end
	if itemData.Slot == "Plushie" or itemData.Slot == "Tool" then
		return nil
	end
	if not itemData.RobuxAssetId then
		if itemData.Object and itemData.Object:IsA("Accessory") then
			return itemData.Object
		end
		return nil
	end

	local assetId = itemData.RobuxAssetId

	if CosmeticAssetCache[assetId] then
		return CosmeticAssetCache[assetId]
	end

	local success, model = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not success or not model then
		warn("Failed to load cosmetic asset", assetId)
		return nil
	end

	local accessory = model:FindFirstChildWhichIsA("Accessory", true)
	if accessory then
		accessory.Parent = nil
		CosmeticAssetCache[assetId] = accessory
	end

	model:Destroy()
	return CosmeticAssetCache[assetId]
end

function KitService:GiveKit(Player, KitName)
	local Character = Player.Character
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		local Kit = Kits:FindFirstChild(KitName)
		local Backpack = Player:FindFirstChildOfClass("Backpack") or Player:FindFirstChild("Backpack")

		Character:SetAttribute("Kit", KitName)

		if Kit then
			for _, Item in ipairs(Kit:GetChildren()) do
				local item = Item:Clone()
				if item:IsA("Tool") then
					if Backpack then
						item.Name = Item.Name
						item:SetAttribute("StoreItemName", Item.Name)
						local toolData = StoreItems.Categories.Tools and StoreItems.Categories.Tools[Item.Name]
						local toolMultiplier = getToolSpeedMultiplier(toolData)
						if typeof(toolMultiplier) == "number" then
							item:SetAttribute("ToolSwimSpeedMultiplier", toolMultiplier)
						end
						item.Parent = Backpack
					else
						item:Destroy()
					end
				elseif Humanoid then
					Humanoid:AddAccessory(item)
				end
			end
		end

		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if HumanoidRootPart then
			HumanoidRootPart.Transparency = 1
		end

		print("Equipped Kit", KitName)
	end
end

function KitService:UnequipKit(Player)
	local Character = Player.Character
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		local KitName = Character:GetAttribute("Kit")
		if not KitName then return end

		local Kit = Kits:FindFirstChild(KitName)
		Character:SetAttribute("Kit", nil)

		if Kit then
			for _, Item in ipairs(Kit:GetChildren()) do
				local Accessory = Character:FindFirstChild(Item.Name)
				if Accessory then
					Accessory:Destroy()
				end
			end
		end

		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if HumanoidRootPart then
			HumanoidRootPart.Transparency = 1
		end

		print("Unequipped Kit", KitName)
	end
end

function KitService:Setup()
	local _KitService = Mince:GetEvent("KitService")
	local Players = game:GetService("Players")

	local EquipKit = _KitService:Extend("EquipKit")
	local UnequipKit = _KitService:Extend("UnequipKit")
	local RemoveGear = _KitService:Extend("RemoveGear")
	local ApplyGear = _KitService:Extend("ApplyGear")

	self.Connections["EquipKit"] = EquipKit.Event:Connect(function(Player, KitName)
		KitService:GiveKit(Player, KitName)
	end)

	self.Connections["UnequipKit"] = UnequipKit.Event:Connect(function(Player)
		KitService:UnequipKit(Player)
	end)

	self.Connections["RemoveGear"] = RemoveGear.Event:Connect(function(player)
		KitService:RemoveAllGear(player)
	end)

	self.Connections["ApplyGear"] = ApplyGear.Event:Connect(function(player)
		local PlayerDataManager = Mince:Get("PlayerDataManager")
		local profile = PlayerDataManager:GetProfile(player)
		if profile and profile.Data then
			KitService:BuildAndEquipKit(player, profile.Data.OwnedItems)
		end
	end)
end

function KitService:BuildAndEquipKit(player, ownedItems)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	for _, child in pairs(character:GetChildren()) do
		if child:GetAttribute("GearItem") then
			child:Destroy()
		end
	end

	local autoEquipItems = {}

	for itemName, itemState in pairs(ownedItems or {}) do
		if itemState.Equipped and itemState.Category == "Gear" then
			local itemData = StoreItems.Categories.Gear[itemName]
			if itemData then
				if itemData.AutoEquips then
					for _, autoItemName in ipairs(itemData.AutoEquips) do
						autoEquipItems[autoItemName] = true
					end
				end

				if itemData.Object then
					KitService:EquipGearItem(humanoid, itemData.Object, itemName, itemData)
				end
			end
		end
	end

	for autoItemName in pairs(autoEquipItems) do
		local autoItemData = StoreItems.Categories.Gear[autoItemName]
		if autoItemData and autoItemData.Object then
			KitService:EquipGearItem(humanoid, autoItemData.Object, autoItemName, autoItemData)
		end
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.Transparency = 1
	end
end

function KitService:RemoveCosmetics(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	for _, accessory in pairs(humanoid:GetAccessories()) do
		if accessory:GetAttribute("CosmeticItem") then
			accessory:Destroy()
		end
	end
end

function KitService:EquipCosmeticItem(humanoid, itemData, itemName)
	local source = getCosmeticSource(itemData)
	if not source then
		return false
	end

	local accessory = source:Clone()
	if not accessory:IsA("Accessory") then
		return false
	end
	accessory:SetAttribute("CosmeticItem", true)
	accessory:SetAttribute("ItemName", itemName)
	humanoid:AddAccessory(accessory)
	return true
end

function KitService:ApplyCosmetics(player, ownedItems)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	self:RemoveCosmetics(player)

	local cosmetics = StoreItems.Categories and StoreItems.Categories.Cosmetics or {}
	for itemName, itemState in pairs(ownedItems or {}) do
		if itemState.Equipped and itemState.Category == "Cosmetics" then
			local itemData = cosmetics[itemName]
			local isToolLike = itemState.Slot == "Plushie" or itemState.Slot == "Tool"
			if itemData and not isToolLike then
				self:EquipCosmeticItem(humanoid, itemData, itemName)
			end
		end
	end
end

local function applyHiddenOnEquip(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

function KitService:EquipGearItem(humanoid, gearModel, itemName, itemData)
	local player = game.Players:GetPlayerFromCharacter(humanoid.Parent)
	local hideOnEquip = itemData and itemData.HideOnEquip == true

	if typeof(gearModel) == "table" then
		for side, accessoryModel in pairs(gearModel) do
			if typeof(accessoryModel) == "Instance" and accessoryModel:IsA("Accessory") then
				local accessory = accessoryModel:Clone()
				accessory:SetAttribute("GearItem", true)
				accessory:SetAttribute("ItemName", itemName)
				if hideOnEquip then
					applyHiddenOnEquip(accessory)
					accessory:SetAttribute("HiddenOnEquip", true)
				end
				humanoid:AddAccessory(accessory)
			elseif typeof(accessoryModel) == "table" then
				for _, nestedModel in pairs(accessoryModel) do
					if typeof(nestedModel) == "Instance" and nestedModel:IsA("Accessory") then
						local accessory = nestedModel:Clone()
						accessory:SetAttribute("GearItem", true)
						accessory:SetAttribute("ItemName", itemName)
						if hideOnEquip then
							applyHiddenOnEquip(accessory)
							accessory:SetAttribute("HiddenOnEquip", true)
						end
						humanoid:AddAccessory(accessory)
					end
				end
			end
		end
	elseif typeof(gearModel) == "Instance" and gearModel:IsA("Accessory") then
		local accessory = gearModel:Clone()
		accessory:SetAttribute("GearItem", true)
		accessory:SetAttribute("ItemName", itemName)
		if hideOnEquip then
			applyHiddenOnEquip(accessory)
			accessory:SetAttribute("HiddenOnEquip", true)
		end
		humanoid:AddAccessory(accessory)
	elseif typeof(gearModel) == "Instance" and gearModel:IsA("Model") then
		local model = gearModel:Clone()
		model:SetAttribute("GearItem", true)
		model:SetAttribute("ItemName", itemName)
		if hideOnEquip then
			applyHiddenOnEquip(model)
			model:SetAttribute("HiddenOnEquip", true)
		end
		model.Parent = humanoid.Parent
	end

end

function KitService:RemoveAllGear(player)
	local character = player.Character
	if not character then return end

	for _, child in pairs(character:GetChildren()) do
		if child:GetAttribute("GearItem") then
			child:Destroy()
		end
	end

end

return KitService