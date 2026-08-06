local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local Flashlight = require(Modules.Flashlight)

local TopbarPlusReference = ReplicatedStorage:FindFirstChild("TopbarPlusReference")
local Icon
if TopbarPlusReference then
	Icon = require(TopbarPlusReference.Value)
else
	Icon = require(Modules.Topbar)
end

local FlashlightController = {
	Name = "FlashlightController",
	Character = nil,
	Humanoid = nil,
	HumanoidRootPart = nil,
	ActiveFlashlight = nil,
	TopbarButton = nil,
	Enabled = false,
	Connections = {},
}

local FLASHLIGHT_TOOL_NAME = "Flashlight"

function FlashlightController:RemoveFlashlightTool()
	local character = self.Character
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")

	if character then
		local tool = character:FindFirstChild(FLASHLIGHT_TOOL_NAME)
		if tool and tool:IsA("Tool") then
			tool:Destroy()
		end
	end

	if backpack then
		local tool = backpack:FindFirstChild(FLASHLIGHT_TOOL_NAME)
		if tool and tool:IsA("Tool") then
			tool:Destroy()
		end
	end
end

function FlashlightController:Setup()
	LocalPlayer.CharacterAdded:Connect(function(character)
		self.Character = character
		self.Humanoid = character:WaitForChild("Humanoid")
		self.HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
		if self.ActiveFlashlight then
			self.ActiveFlashlight:Destroy()
			self.ActiveFlashlight = nil
		end
		self:RemoveFlashlightTool()
		self:CreateFlashlight()
		self:UpdateTopbarVisibility()
	end)

	if not self.Connections.SwimmingChanged then
		self.Connections.SwimmingChanged = LocalPlayer:GetAttributeChangedSignal("Swimming"):Connect(function()
			self:UpdateTopbarVisibility()
		end)
	end

	if not self.Connections.InputBegan then
		self.Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == Enum.KeyCode.F then
				self:ToggleFromKey()
			end
		end)
	end
end

function FlashlightController:GameStart()
	self.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	self.HumanoidRootPart = self.Character:WaitForChild("HumanoidRootPart")
	self:RemoveFlashlightTool()
	self:CreateFlashlight()
	self:CreateTopbarButton()
	self:UpdateTopbarVisibility()
	self.Enabled = false
end

function FlashlightController:CreateFlashlight()
	if self.ActiveFlashlight then
		self.ActiveFlashlight:Destroy()
		self.ActiveFlashlight = nil
	end

	if self.Character then
		self.ActiveFlashlight = Flashlight.new(self.Character)
		self.ActiveFlashlight:SetEnabled(false)
	end
end

function FlashlightController:CreateTopbarButton()
	if self.TopbarButton then
		return
	end

	self.TopbarButton = Icon.new()
	self.TopbarButton:setLabel("🔦")
	self.TopbarButton:setAlignment("Left")
	self.TopbarButton:setOrder(10)

	self.TopbarButton:modifyTheme({
		{"IconLabel", "TextSize", 20},
	})

	self.TopbarButton.selected:Connect(function()
		self:SetEnabled(true, true)
	end)

	self.TopbarButton.deselected:Connect(function()
		self:SetEnabled(false, true)
	end)

	self.TopbarButton:setEnabled(true)
end

function FlashlightController:ToggleFromKey()
	if not self.TopbarButton or not self.TopbarButton.isEnabled then
		return
	end

	if self.TopbarButton.isSelected then
		self.TopbarButton:deselect()
	else
		self.TopbarButton:select()
	end
end

function FlashlightController:UpdateTopbarVisibility()
	local isSwimming = LocalPlayer:GetAttribute("Swimming")
	if self.TopbarButton then
		self.TopbarButton:setEnabled(isSwimming == true)
		if not isSwimming then
			self.TopbarButton:deselect()
			self:SetEnabled(false)
		end
	end
end

function FlashlightController:GetFlashlight()
	return self.ActiveFlashlight
end

function FlashlightController:SetEnabled(enabled, fromButton)
	self.Enabled = enabled
	if self.ActiveFlashlight then
		self.ActiveFlashlight:SetEnabled(enabled)
	end
	if self.TopbarButton and not fromButton then
		if enabled then
			self.TopbarButton:select()
		else
			self.TopbarButton:deselect()
		end
	end
end

function FlashlightController:SetBrightness(brightness)
	if self.ActiveFlashlight then
		self.ActiveFlashlight:SetBrightness(brightness)
	end
end

function FlashlightController:SetRange(range)
	if self.ActiveFlashlight then
		self.ActiveFlashlight:SetRange(range)
	end
end

function FlashlightController:SetColor(color)
	if self.ActiveFlashlight then
		self.ActiveFlashlight:SetColor(color)
	end
end

return FlashlightController