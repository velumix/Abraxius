-- Modules // Services 
local ReplicatedStorage = game:GetService("ReplicatedStorage") 

local Mince = require(ReplicatedStorage.Modules.Mince)

local PlayerDataManager = Mince:Get("PlayerDataManager")
local SaveSettingsEvent = Mince:GetEvent("SaveSettings")

--[[
	@class Settings
	@server

	Server-side player settings persistence system.

	Settings reads and writes the `Settings` section of PlayerDataManager profile
	data and listens for the `SaveSettings` Mince remote from clients.
]]

local Settings = {} 

--[[
	Gets a specific setting value for a player.

	@within Settings
	@param player Player -- Player whose settings should be read.
	@param settingName string -- Setting key to retrieve.
	@return any
]]
function Settings:getValue(player, settingName)
	if not player then
		warn("[Settings Server] Attempted to get value with nil player")
		return nil
	end

	local success, result = pcall(function()
		local profile = PlayerDataManager:GetProfileData(player)
		if not profile or not profile.Settings then
			return nil
		end
		local value = profile.Settings[settingName]
		return value
	end)

	if not success then
		warn("[Settings Server] Failed to get value:", result)
		return nil
	end

	return result
end

--[[
	Saves a table of setting values for a player.

	@within Settings
	@param player Player -- Player whose settings should be updated.
	@param newSettings table -- Setting values keyed by setting name.
]]
function Settings:saveForPlayer(player, newSettings)
	if not player then
		warn("[Settings Server] Attempted to save settings with nil player")
		return
	end

	if typeof(newSettings) ~= "table" then
		warn("[Settings Server] Attempted to save invalid settings for player:", player.Name)
		return
	end

	local success, result = pcall(function()
		local profile = PlayerDataManager:GetProfileData(player)
		if not profile or not profile.Settings then
			return
		end
		for key, value in pairs(newSettings) do
			profile.Settings[key] = value
		end
	end)

	if not success then
		warn("[Settings Server] Failed to save settings:", result)
	end
end

--[[
	Connects the client save remote to profile settings writes.

	@within Settings
]]
function Settings.Setup()
	SaveSettingsEvent.Event:Connect(function(player, settingsTable)
		Settings:saveForPlayer(player, settingsTable)
	end)
end

return Settings
