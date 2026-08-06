local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Unify = require(ReplicatedStorage.Modules.Unify)

local PlayerDataManager = Mince:Get("PlayerDataManager")

local Statistics = {
	Name = "Statistics",
	TimeElapsed = 0,
	UpdateRate = 10,
	TimeBeforeCompounding = 300
}

function Statistics:Record(Player,Record,Value)
	local AchievementService = Mince:Get("AchievementService")
	local Profile = PlayerDataManager:GetProfileData(Player)
	if not Profile then
		return
	end
	Profile.Statistics = Profile.Statistics or {}
	Profile.Statistics[Record] = Profile.Statistics[Record] or 0
	Profile.Statistics[Record] += Value

	if AchievementService then
		AchievementService:HandleStatistic(Player, Record)
	else
		warn("Record - AchievementService is nil")
	end

	PlayerDataManager:SchedulePlayerUpdate(Player,"Statistics")
	PlayerDataManager:SchedulePlayerUpdate(Player,"Achievements")

	local Leaderboards = Mince:Get("Leaderboards")
	if Leaderboards then
		if Record == "Scanned" then
			Leaderboards:UpdateLeaderboard(Player, "FishScanned", Profile.Statistics.Scanned)
		elseif Record == "DiveCount" then
			Leaderboards:UpdateLeaderboard(Player, "DiveCount", Profile.Statistics.DiveCount)
		end
	end
end

function Statistics:Get(Player, Record)
	local Profile = PlayerDataManager:GetProfileData(Player)
	if not Profile then
		return 0
	end
	return Profile.Statistics[Record] or 0
end

function Statistics.Update(DeltaTime)
	Statistics.TimeElapsed += DeltaTime
	if Statistics.TimeElapsed > Statistics.UpdateRate then
		Statistics.TimeElapsed = 0

		for _,Player : Player in Players:GetPlayers() do 
			local PlayerData = PlayerDataManager:GetLocalData(Player)
			local ProfileData = PlayerDataManager:GetProfileData(Player) 

			if PlayerData and ProfileData then
				local SessionLength = Unify.GetServerTimeFrom(PlayerData.CountedOn)
				if SessionLength > Statistics.TimeBeforeCompounding then 
					PlayerData.CountedOn = Unify.GetServerTime() 
					ProfileData.TotalPlayTime += SessionLength
					local AchievementService = Mince:Get("AchievementService")
					if AchievementService then
						AchievementService:HandlePlaytime(Player)
					end
				end
			end

			if ProfileData then
				PlayerDataManager:PartialUpdate(Player, "Statistics")
				PlayerDataManager:Capture(Player, "Statistics")
			end
		end
	end
end

function Statistics.Setup()
	RunService.Heartbeat:Connect(Statistics.Update)
end

return Statistics