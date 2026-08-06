local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local ZoneAchievementSystem = {
	Name = "ZoneAchievementSystem"
}

function ZoneAchievementSystem:Setup()
	self.Statistics = Mince:Get("Statistics")
	self.PlayerDataManager = Mince:Get("PlayerDataManager")

	local zoneFolder = Workspace:FindFirstChild("AchievementZones")
	if not zoneFolder then
		warn("Workspace.AchievementZones folder not found. Zone achievements will not work until this folder is created and populated.")
		return
	end

	for _, zone in ipairs(zoneFolder:GetChildren()) do
		if zone:IsA("BasePart") then
			self:BindZone(zone)
		end
	end

	zoneFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			self:BindZone(child)
		end
	end)

end

function ZoneAchievementSystem:BindZone(part)
	local statKey = part:GetAttribute("StatKey")
	local zoneId = part:GetAttribute("ZoneId") or part.Name

	if not statKey then
		warn(`Zone {part.Name} missing 'StatKey' attribute`)
		return
	end

	local debounce = {}

	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		if debounce[player] and (os.time() - debounce[player] < 2) then
			return
		end
		debounce[player] = os.time()

		self:ProcessVisit(player, zoneId, statKey)
	end)
end

function ZoneAchievementSystem:ProcessVisit(player, zoneId, statKey)
	local profile = self.PlayerDataManager:GetProfileData(player)
	if not profile then return end

	profile.ZoneVisits = profile.ZoneVisits or {}

	if profile.ZoneVisits[zoneId] then
		return
	end

	profile.ZoneVisits[zoneId] = true
	self.PlayerDataManager:SchedulePlayerUpdate(player, "ZoneVisits")

	self.Statistics:Record(player, statKey, 1)

end

return ZoneAchievementSystem
