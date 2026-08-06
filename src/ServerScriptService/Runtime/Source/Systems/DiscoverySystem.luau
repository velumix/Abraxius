local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)

local Encyclopedia = ReplicatedStorage.Assets.Encyclopedia
local Vertebrates = require(Encyclopedia.Vertebrates)
local Invertebrates = require(Encyclopedia.Invertebrates)
local CoralsAndPlants = require(Encyclopedia["Corals and Plants"])

local DISCOVERY_DATASETS = {
	["Vertebrates"] = Vertebrates,
	["Invertebrates"] = Invertebrates,
	["Corals and Plants"] = CoralsAndPlants
}

local AUTO_UNLOCKED_DISCOVERY_TYPES = {
	["Corals and Plants"] = true
}

local function autoUnlockDiscoveries(self, player, profile, discoveryType)
	if not AUTO_UNLOCKED_DISCOVERY_TYPES[discoveryType] then
		return
	end

	if not profile.Discoveries then
		profile.Discoveries = {}
	end

	local dataset = DISCOVERY_DATASETS[discoveryType]
	if not dataset then
		return
	end

	local discoveryEntries = profile.Discoveries[discoveryType]
	if not discoveryEntries then
		discoveryEntries = {}
		profile.Discoveries[discoveryType] = discoveryEntries
	end

	local owned = {}
	for _, record in ipairs(discoveryEntries) do
		if record.Data then
			owned[record.Data] = true
		end
	end

	local addedEntries = false
	for discoveryId in pairs(dataset) do
		if not owned[discoveryId] then
			table.insert(discoveryEntries, {
				Data = discoveryId,
				Timestamp = os.time()
			})
			addedEntries = true
		end
	end

	if addedEntries and self.PlayerDataManager then
		self.PlayerDataManager:SchedulePlayerUpdate(player, "Discoveries")
	end
end

local DiscoverySystem = {
	Name = "DiscoverySystem"
}

function DiscoverySystem:Setup()
	self.PlayerDataManager = Mince:Get("PlayerDataManager")
	self.CurrencyService = Mince:Get("CurrencyService")
	self.Statistics = Mince:Get("Statistics")
	self.AchievementService = Mince:Get("AchievementService")
	self.ScanCooldowns = {}

	self.DiscoveryEvent = Mince:GetEvent("DiscoverySystem")
	self.RecordDiscovery = self.DiscoveryEvent:Extend("RecordDiscovery")
	self.GetDiscoveries = self.DiscoveryEvent:Extend("GetDiscoveries")
end

function DiscoverySystem:GameStart()
	self.Connections = {
		RecordDiscovery = self.RecordDiscovery.Event:Connect(function(player, discoveryType, discoveryId)

			if not table.find({"Vertebrates", "Invertebrates", "Corals and Plants"}, discoveryType) then
				warn(`Invalid discovery type: {discoveryType}`)
				return false
			end

			local profile = self.PlayerDataManager:GetProfileData(player)
			if not profile then
				warn(`Failed to get profile for player {player.Name}`)
				return false
			end

			local now = os.clock()
			local lastScan = self.ScanCooldowns[player.UserId] or 0
			if now - lastScan < 2 then
				player:Kick("obviously exploiting the scan rate limit!... nice try!")
				return false
			end
			self.ScanCooldowns[player.UserId] = now

			if not profile.Discoveries then
				profile.Discoveries = {}
			end
			if not profile.Discoveries[discoveryType] then
				profile.Discoveries[discoveryType] = {}
			end

			local alreadyDiscovered = false
			for _, discovery in ipairs(profile.Discoveries[discoveryType]) do
				if discovery.Data == discoveryId then
					alreadyDiscovered = true
					break
				end
			end

			local dataset = DISCOVERY_DATASETS[discoveryType]
			local discoveryEntry = dataset and dataset[discoveryId]
			local rewardMultiplier = 1
			if discoveryEntry then
				if typeof(discoveryEntry.ScanRewardMultiplier) == "number" then
					rewardMultiplier = discoveryEntry.ScanRewardMultiplier
				elseif typeof(discoveryEntry.RewardMultiplier) == "number" then
					rewardMultiplier = discoveryEntry.RewardMultiplier
				end
			end

			if self.CurrencyService then
				self.CurrencyService:GiveScanReward(player, rewardMultiplier)
			end
			if self.Statistics then
				self.Statistics:Record(player, "Scanned", 1)
				local totalScanned = self.Statistics:Get(player, "Scanned")
			end

			if alreadyDiscovered then
				return true
			end

			table.insert(profile.Discoveries[discoveryType], {
				Data = discoveryId,
				Timestamp = os.time()
			})

			self.PlayerDataManager:SchedulePlayerUpdate(player, "Discoveries")

			self.AchievementService:HandleDiscovery(player)
			self:CheckEncyclopediaCompletion(player)

			return true
		end),

		GetDiscoveries = self.GetDiscoveries.Event:Connect(function(player, discoveryType)
			if not table.find({"Vertebrates", "Invertebrates", "Corals and Plants"}, discoveryType) then
				warn(`Invalid discovery type: {discoveryType}`)
				self.GetDiscoveries:Fire(player, discoveryType, {})
				return
			end

			local profile = self.PlayerDataManager:GetProfileData(player)
			if not profile then
				warn(`Failed to get profile for player {player.Name}`)
				self.GetDiscoveries:Fire(player, discoveryType, {})
				return
			end

			autoUnlockDiscoveries(self, player, profile, discoveryType)

			if not profile.Discoveries or not profile.Discoveries[discoveryType] then
				self.GetDiscoveries:Fire(player, discoveryType, {})
				return
			end

			local discoveries = {}
			for _, discovery in profile.Discoveries[discoveryType] do
				table.insert(discoveries, discovery.Data)
			end

			self.GetDiscoveries:Fire(player, discoveryType, discoveries)
		end)
	}
end

function DiscoverySystem:CheckEncyclopediaCompletion(player)
	local profile = self.PlayerDataManager:GetProfileData(player)
	if not profile or not profile.Discoveries then
		return
	end

	for discoveryType in pairs(AUTO_UNLOCKED_DISCOVERY_TYPES) do
		autoUnlockDiscoveries(self, player, profile, discoveryType)
	end

	local totalDiscovered = 0
	local discoveries = profile.Discoveries
	local seen = {}
	local trackedTypes = {
		["Vertebrates"] = true,
		["Invertebrates"] = true,
		["Corals and Plants"] = true,
	}

	for discoveryType, entries in pairs(discoveries) do
		if trackedTypes[discoveryType] then
			for _, entry in ipairs(entries) do
				local id = entry and entry.Data
				if id and not seen[id] then
					seen[id] = true
					totalDiscovered += 1
				end
			end
		end
	end

	local function countTableEntries(tbl)
		local count = 0
		for _ in pairs(tbl) do
			count = count + 1
		end
		return count
	end

	local TOTAL_ENCYCLOPEDIA_ENTRIES = countTableEntries(Vertebrates) + 
		countTableEntries(Invertebrates) + 
		countTableEntries(CoralsAndPlants)

	if totalDiscovered >= TOTAL_ENCYCLOPEDIA_ENTRIES then
		self.Statistics:Record(player, "EncyclopediaComplete", 1)
	end
end

return DiscoverySystem

