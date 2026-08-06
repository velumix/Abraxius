local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icon = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Icon"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local settingsGui = playerGui:WaitForChild("Settings")
local openEvent = settingsGui:WaitForChild("OpenSettings")
local closeEvent = settingsGui:WaitForChild("CloseSettings")

local SETTINGS_ICON = "rbxassetid://125593982294278"
local syncing = false

local settingsIcon = Icon.new()
settingsIcon:setImage(SETTINGS_ICON)
settingsIcon:setOrder(1)
settingsIcon:align("right")

local function openSettings()
	openEvent:Fire()
end

local function closeSettings()
	closeEvent:Fire()
end

settingsIcon:bindEvent("selected", function()
	if syncing then return end
	openSettings()
end)

settingsIcon:bindEvent("deselected", function()
	if syncing then return end
	closeSettings()
end)

settingsGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if syncing then return end
	syncing = true
	if settingsGui.Enabled then
		if not settingsIcon.isSelected then
			settingsIcon:select("External", settingsIcon)
		end
	else
		if settingsIcon.isSelected then
			settingsIcon:deselect("External", settingsIcon)
		end
	end
	syncing = false
end)
