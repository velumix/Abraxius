--!strict
-- @author Velumix
-- @version 0.0.1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Modules.Component)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local WeaponComponent = Component.new({
	Tag = WeaponDefinitions.Tag,
	Ancestors = { workspace, Players },
})

WeaponComponent.EquippedChanged = Signal.new()
WeaponComponent.Activated = Signal.new()

function WeaponComponent:Construct()
	self._trove = Trove.new()
	self.Owner = nil :: Player?
end

function WeaponComponent:_resolveOwner(): Player?
	local parent = self.Instance.Parent
	if not parent then
		return nil
	end
	if parent:IsA("Backpack") then
		return parent.Parent :: Player?
	end
	return Players:GetPlayerFromCharacter(parent)
end

function WeaponComponent:Start()
	if not self.Instance:IsA("Tool") then
		warn(`[WeaponComponent] Weapon tag requires a Tool: {self.Instance:GetFullName()}`)
		return
	end
	local tool = self.Instance :: Tool
	self.Owner = self:_resolveOwner()
	self._trove:Add(tool.Equipped:Connect(function()
		self.Owner = self:_resolveOwner()
		WeaponComponent.EquippedChanged:Fire(self, self.Owner, true)
	end))
	self._trove:Add(tool.Unequipped:Connect(function()
		WeaponComponent.EquippedChanged:Fire(self, self.Owner, false)
	end))
	self._trove:Add(tool.Activated:Connect(function()
		local owner = self:_resolveOwner()
		if owner and owner.Character == tool.Parent then
			WeaponComponent.Activated:Fire(self, owner)
		end
	end))
end

function WeaponComponent:Stop()
	self._trove:Destroy()
end

return WeaponComponent
