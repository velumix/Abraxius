-- Modules // Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Utility = require(ReplicatedStorage.Modules.Utility)
local PlayerDataManager = Mince:Get("PlayerDataManager")

local Analytics = Mince:GetEvent("Analytics")
local ReportInterfaceTrackingEvent = Analytics:Extend("ReportInterfaceTrakcing")
local ReportTeleportLocationEvent = Analytics:Extend("ReportTeleportLocationTracking")

-- Constants
local VALID_TELEPORT_LOCATIONS = {
	["Main Observatory"] = true,
	["Lower Observatory"] = true,
	["Dive"] = true,
}

local AnalyticsServer = {
	MaxTimeBetweenEachTrackedDuration = 2,
}

function AnalyticsServer:TrackInterfaceDurations(Player: Player, Key: string, Duration: number)
	if RunService:IsStudio() then
		return
	end

	assert(Utility.AssertTypes(Key, "string"))
	assert(Utility.AssertTypes(Duration, "number"))
	local Profile = PlayerDataManager:GetProfileData(Player)
	local LocalData = PlayerDataManager:GetLocalData(Player)
	local LastTimeOpened = Profile.AnalyticsTracking.InterfaceRecords[Key]
	if LastTimeOpened then
		local TimeSenseLast = os.time() - LastTimeOpened
		if TimeSenseLast < AnalyticsServer.MaxTimeBetweenEachTrackedDuration then
			return
		end
	end

	if LocalData:RateLimit("ReportInterfaceInteraction") then
		return
	end

	Profile.AnalyticsTracking.InterfaceRecords[Key] = os.time()

	AnalyticsService:LogCustomEvent(Player, "InterfaceViewedFor", Duration, {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = Key,
	})
end

function AnalyticsServer:TrackCreatureEvent(status: string, definition)
	if RunService:IsStudio() then
		return
	end

	local eventId = definition and (definition.Identifier or definition.Name) or "Unknown"
	local rarity = definition and (definition.Rarity or "Unknown") or "Unknown"
	local statusValue = status or "Unknown"

	for _, player in ipairs(Players:GetPlayers()) do
		AnalyticsService:LogCustomEvent(player, "CreatureEvent", 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = statusValue,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = rarity,
			[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = eventId,
		})
	end
end

function AnalyticsServer:Setup()
	ReportTeleportLocationEvent.Event:Connect(function(Player: Player, Key)
		if RunService:IsStudio() then
			return
		end

		assert(Utility.AssertTypes(Key, "string"))
		AnalyticsService:LogCustomEvent(Player, "TeleportLocation", 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = Key,
		})
	end)
	ReportInterfaceTrackingEvent.Event:Connect(function(...)
		AnalyticsServer:TrackInterfaceDurations(...)
	end)
end

return AnalyticsServer
