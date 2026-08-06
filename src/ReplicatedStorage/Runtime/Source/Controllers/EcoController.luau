local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local EcoController = {
	Name = "EcoController",
	ShowTrash = false,
	TrashFolder = nil,
}

function EcoController:Setup()
	task.spawn(function()
		self.TrashFolder = workspace:WaitForChild("OceanDebris", math.huge)
		self:UpdateVisibility()
	end)

	LocalPlayer:GetAttributeChangedSignal("ShowTrash"):Connect(function()
		self:OnSettingChanged()
	end)

	self:OnSettingChanged()
end

function EcoController:OnSettingChanged()
	local val = LocalPlayer:GetAttribute("ShowTrash")
	if val == nil then val = true end

	if self.ShowTrash ~= val then
		self.ShowTrash = val
		self:UpdateVisibility()
	end
end

function EcoController:UpdateVisibility()
	if not self.TrashFolder then return end
	if self.ShowTrash then
		self.TrashFolder.Parent = workspace
	else
		self.TrashFolder.Parent = nil
	end
end

return EcoController
