local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local UI = require(Modules.UI)

local GearNotificationController = {
	OwnedItems = {},
	HasNotifiedThisSession = {},
}

local GEAR_RECOMMENDATIONS = {
	{
		slot = "Harness",
		message = "⚠️ No diving set! You'll run out of air quickly.",
		priority = 1,
		alwaysWarn = true,
	},
	{
		slot = "DiveMask",
		message = "⚠️ No dive mask equipped! Your vision will be blurry underwater.",
		priority = 2,
		alwaysWarn = true,
	},
	{
		slot = "Fins",
		message = "💡 Fins would help you swim faster!",
		priority = 3,
		alwaysWarn = true,
	},
}

function GearNotificationController:GameStart()
	self:SetupInventoryTracking()
	self:SetupSwimmingTracking()
end

function GearNotificationController:SetupInventoryTracking()
	local storeComm = Mince:GetEvent("StoreEvents")
	local inventorySync = storeComm:Extend("InventorySync")

	inventorySync.Event:Connect(function(inventoryData)
		self:UpdateInventory(inventoryData)
	end)

	local requestInventory = storeComm:Extend("RequestInventory")
	requestInventory:Fire()
end

function GearNotificationController:UpdateInventory(inventoryData)
	self.OwnedItems = inventoryData.OwnedItems or {}
	self.EquippedSlots = {}
	for itemName, itemData in self.OwnedItems do
		if itemData.Equipped and itemData.Slot then
			self.EquippedSlots[itemData.Slot] = true
		end
	end
end

function GearNotificationController:SetupSwimmingTracking()
	Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		local isSwimming = Player:GetAttribute("Swimming") or false

		if isSwimming then
			self:CheckGearAndNotify()
		end
	end)

	local currentSwimming = Player:GetAttribute("Swimming") or false
	if currentSwimming then
		self:CheckGearAndNotify()
	end
end

function GearNotificationController:CheckGearAndNotify()
	for _, gear in ipairs(GEAR_RECOMMENDATIONS) do
		local shouldCheck = true

		if gear.requiresSlot then
			if not self.EquippedSlots[gear.requiresSlot] then
				shouldCheck = false
			end
		end

		if shouldCheck then
			local isEquipped = self.EquippedSlots[gear.slot]

			if not isEquipped then
				local shouldNotify = gear.alwaysWarn or not self.HasNotifiedThisSession[gear.slot]
				if shouldNotify then
					self:ShowNotification(gear)
					if not gear.alwaysWarn then
						self.HasNotifiedThisSession[gear.slot] = true
					end
					break
				end
			end
		end
	end
end

function GearNotificationController:ShowNotification(gear)
	local notifType = "Info"
	if gear.priority == 1 or gear.priority == 2 then
		notifType = "Warning"
	end
	UI.Notify(gear.message, notifType, 6)
end

return GearNotificationController
