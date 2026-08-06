local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local UnderwaterVisionController = {
	Name = "UnderwaterVisionController",
	BlurEffect = nil,
	IsSwimming = false,
	HasDiveMask = false,
	CurrentBlurSize = 0,
	TargetBlurSize = 0,
}

local BLUR_SIZE_NO_MASK = 15
local BLUR_SIZE_WITH_MASK = 0
local BLUR_TRANSITION_TIME = 0.5

function UnderwaterVisionController:Setup()
	self:CreateBlurEffect()
	self:SetupEquipmentTracking()
	self:SetupSwimmingTracking()
end

function UnderwaterVisionController:CreateBlurEffect()
	self.BlurEffect = Lighting:FindFirstChild("UnderwaterBlur")
	if not self.BlurEffect then
		self.BlurEffect = Instance.new("BlurEffect")
		self.BlurEffect.Name = "UnderwaterBlur"
		self.BlurEffect.Size = 0
		self.BlurEffect.Parent = Lighting
	end
	self.BlurEffect.Size = 0
end

function UnderwaterVisionController:SetupEquipmentTracking()
	local storeComm = Mince:GetEvent("StoreEvents")
	local inventorySync = storeComm:Extend("InventorySync")
	inventorySync.Event:Connect(function(inventoryData)
		self:UpdateEquipment(inventoryData)
	end)
	local requestInventory = storeComm:Extend("RequestInventory")
	requestInventory:Fire()
end

function UnderwaterVisionController:UpdateEquipment(inventoryData)
	local ownedItems = inventoryData.OwnedItems or {}
	self.HasDiveMask = false

	for _, itemState in pairs(ownedItems) do
		if itemState and itemState.Equipped then
			local slot = itemState.Slot or itemState.slot
			if slot and string.lower(slot) == "divemask" then
				self.HasDiveMask = true
				break
			end
		end
	end
	self:UpdateBlur()
end

function UnderwaterVisionController:SetupSwimmingTracking()
	Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		self.IsSwimming = Player:GetAttribute("Swimming") or false
		self:UpdateBlur()
	end)
	self.IsSwimming = Player:GetAttribute("Swimming") or false
	if self.IsSwimming then
		self:UpdateBlur()
	end
end

function UnderwaterVisionController:UpdateBlur()
	if self.IsSwimming and not self.HasDiveMask then
		self.TargetBlurSize = BLUR_SIZE_NO_MASK
	else
		self.TargetBlurSize = BLUR_SIZE_WITH_MASK
	end
	self:AnimateBlur()
end

function UnderwaterVisionController:AnimateBlur()
	if not self.BlurEffect then return end
	local tween = TweenService:Create(
		self.BlurEffect,
		TweenInfo.new(BLUR_TRANSITION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Size = self.TargetBlurSize }
	)
	tween:Play()
end

return UnderwaterVisionController
