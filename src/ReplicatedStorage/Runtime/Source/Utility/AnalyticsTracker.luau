-- Modules // Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage.Modules.UI)
local Mince = require(ReplicatedStorage.Modules.Mince)
local Unify = require(ReplicatedStorage.Modules.Unify)
local Utility = require(ReplicatedStorage.Modules.Utility)

local InterfaceHandler = Mince:Get("InterfaceHandler")


local Analytics = Mince:GetEvent("Analytics")
local ReportInterfaceTrackingEvent = Analytics:Extend("ReportInterfaceTrakcing")

local AnalyticsTracker = {
	TimeOpened = {}, 
	LocalMemoryRecords = {},
	CooldownRecords = {
		["OpenInterfaceTime"] = 30,
	}
} 

function AnalyticsTracker:InterfaceOpened(InterfaceName, IsOpen)
	-- Is currently active
	if AnalyticsTracker.TimeOpened[InterfaceName] and not IsOpen then 
		local TimeSpentOpen = os.clock() - AnalyticsTracker.TimeOpened[InterfaceName]
		AnalyticsTracker.TimeOpened[InterfaceName] = nil 
		
		ReportInterfaceTrackingEvent:Fire(InterfaceName, TimeSpentOpen)
		return 
	end 


	AnalyticsTracker.TimeOpened[InterfaceName] = os.clock()
end

function AnalyticsTracker:OpenInterfaceSignal(InterfaceName)
	if not AnalyticsTracker:TrackThisRecord(`OpenInterface_{InterfaceName}`, "OpenInterfaceTime") then 
		return
	end 
end

-- Cooldowns for any analytics key, (this is to prevent throttling on certain keys)
function AnalyticsTracker:TrackThisRecord(RecordName, ManualDelay)
	assert(Utility.AssertTypes(RecordName, "string")) 

	local IsReady, TimeRemaining  
	local RecordDuration =  AnalyticsTracker.CooldownRecords[RecordName] or AnalyticsTracker.CooldownRecords[ManualDelay] or ManualDelay or 10
	local LastAccessed = AnalyticsTracker.LocalMemoryRecords[RecordName] 
	if not LastAccessed then 
		IsReady = true 
		AnalyticsTracker.LocalMemoryRecords[RecordName] = os.time() + RecordDuration
	else 
		TimeRemaining = LastAccessed - os.time()

		if TimeRemaining  < 0 then 
			IsReady = true 
			AnalyticsTracker.LocalMemoryRecords[RecordName] = os.time() + RecordDuration
		end 
	end

	return IsReady, TimeRemaining
end

function AnalyticsTracker.Setup()
	UI.ScreenShown:Connect(function(...) 
		AnalyticsTracker:InterfaceOpened(...)
	end)
	InterfaceHandler.ScreenShown:Connect(function(...)
		AnalyticsTracker:InterfaceOpened(...)
	end)
end

return AnalyticsTracker