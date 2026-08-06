local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UI = require(Modules.UI)
local Trove = require(Modules.Trove)
local Mince = require(Modules.Mince)

local GearVisibilityController = {
	Name = "GearVisibilityController",
	Trove = nil,
	ShowGearSetting = nil,
	SetShowGearRequest = nil,
}

function GearVisibilityController:UpdatePlayerAttribute()
	if not self.ShowGearSetting or not self.SetShowGearRequest then return end

	local value = self.ShowGearSetting.Value
	self.SetShowGearRequest:Fire(value)
end

function GearVisibilityController:GameStart()
	self.Trove = Trove.new()

	local gearComm = Mince:GetEvent("GearVisibilityEvents")
	self.SetShowGearRequest = gearComm:Extend("SetShowGearRequest")

	if UI.Settings and UI.Settings.WaitUntilLoaded then
		task.spawn(function()
			UI.Settings:WaitUntilLoaded()
			self.ShowGearSetting = UI.Settings:GetSetting("ShowGearInObservatory")

			if self.ShowGearSetting then
				self:UpdatePlayerAttribute()

				if self.ShowGearSetting.Changed then
					self.Trove:Connect(self.ShowGearSetting.Changed, function()
						self:UpdatePlayerAttribute()
					end)
				end
			end
		end)
	end
end

function GearVisibilityController:Cleanup()
	if self.Trove then
		self.Trove:Destroy()
		self.Trove = nil
	end
	self.ShowGearSetting = nil
end

return GearVisibilityController
