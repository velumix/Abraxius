local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)

local AchievementService = {
	Name = "AchievementService",
	TrackerIndex = {},
	PrerequisiteIndex = {},
	State = {},
	PendingSync = {},
}

local DEFAULT_TOAST_COLOR = Color3.fromRGB(255, 230, 120)
local GROUP_ID = 12889407
local RANK_THRESHOLD = 250

local MACRO_CREATURES = {
	"WhaleShark",
	"HumpbackWhale",
	"oceanSunfish",
	"ReefMantaRay",
	"LeatherbackSeaTurtle",
	"GiantGrouper",
	"GiantSquid",
	"SpermWhale",
}

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

function AchievementService:Setup()
	self.PlayerDataManager = Mince:Get("PlayerDataManager")
	self.Notice = Mince:Get("Notice")
	self.CurrencyService = Mince:Get("CurrencyService")

	local config = Mince.Config.Achievements or {}
	self.Definitions = config
	self.Achievements = config.Achievements or {}
	self.Categories = config.Categories or {}

	self.TrackerIndex, self.PrerequisiteIndex = self:BuildIndexes(self.Achievements)

	self.Remote = Mince:GetEvent("Achievements")
	self.ToastEvent = self.Remote:Extend("Toast")
	self.UpdateEvent = self.Remote:Extend("Update")
	self.ClaimEvent = self.Remote:Extend("Claim")

	self.ClaimEvent.Event:Connect(function(player, achievementId)
		self:ClaimAchievement(player, achievementId)
	end)

	self.PlayerDataManager.ProfileLoaded:Connect(function(player, profile)
		self:OnProfileLoaded(player, profile)
	end)

	self.PlayerDataManager.ProfileReleased:Connect(function(player)
		self.State[player] = nil
		self.PendingSync[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		self:CheckDeveloperPresence(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:CheckDeveloperPresence(player)
		end)
	end
end

function AchievementService:CheckDeveloperPresence(player)
	task.spawn(function()
		local success, rank = pcall(function()
			return player:GetRankInGroupAsync(GROUP_ID)
		end)

		if success and rank and rank >= RANK_THRESHOLD then
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer ~= player then
					self:RecordStat(otherPlayer, "MetDeveloper", 1)
				end
			end
		else
			for _, existingPlayer in ipairs(Players:GetPlayers()) do
				if existingPlayer ~= player then
					local s, r = pcall(function()
						return existingPlayer:GetRankInGroupAsync(GROUP_ID)
					end)
					if s and r and r >= RANK_THRESHOLD then
						self:RecordStat(player, "MetDeveloper", 1)
						break
					end
				end
			end
		end
	end)
end

function AchievementService:RecordStat(player, key, amount)
	local Statistics = Mince:Get("Statistics")
	if Statistics then
		Statistics:Record(player, key, amount)
	end
end

function AchievementService:GameStart() end

function AchievementService:BuildIndexes(achievements)
	local trackerIndex = {}
	local prerequisiteIndex = {}

	for id, def in pairs(achievements) do
		local tracker = def.tracker
		if tracker then
			if tracker.type == "stat" and tracker.key then
				trackerIndex.stat = trackerIndex.stat or {}
				trackerIndex.stat[tracker.key] = trackerIndex.stat[tracker.key] or {}
				table.insert(trackerIndex.stat[tracker.key], id)
			else
				trackerIndex[tracker.type] = trackerIndex[tracker.type] or {}
				table.insert(trackerIndex[tracker.type], id)
			end
		end

		if def.prerequisite then
			prerequisiteIndex[def.prerequisite] = prerequisiteIndex[def.prerequisite] or {}
			table.insert(prerequisiteIndex[def.prerequisite], id)
		end
	end

	return trackerIndex, prerequisiteIndex
end

function AchievementService:OnProfileLoaded(player, profile)
	local data = self:EnsureSchema(profile)

	self.State[player] = {
		profile = profile,
		achievements = data,
	}

	self:RefreshAllProgress(player, profile, data)
	self:QueueSync(player)
end

function AchievementService:EnsureSchema(profile)
	profile.Data.Achievements = profile.Data.Achievements or {}
	local achievements = profile.Data.Achievements

	achievements.Progress = achievements.Progress or {}
	achievements.Unlocked = achievements.Unlocked or {}
	achievements.Claimed = achievements.Claimed or {}
	achievements.Points = nil
	achievements.Coins = nil

	return achievements
end

function AchievementService:RefreshAllProgress(player, profile, achievements)
	for id, def in pairs(self.Achievements) do
		local value = self:ComputeTrackerValue(profile, def.tracker, achievements, id)
		self:UpdateAchievement(player, profile, achievements, id, def, value, {
			silent = true,
			deferSync = true,
		})
	end
end

function AchievementService:QueueSync(player)
	if self.PendingSync[player] then
		return
	end

	self.PendingSync[player] = true
	task.defer(function()
		if not self.PendingSync[player] then
			return
		end

		self.PendingSync[player] = nil
		local state = self.State[player]
		if not state then
			return
		end

		self.PlayerDataManager:UpdatePlayer(player, "Achievements")
	end)
end

function AchievementService:GetCategoryColor(categoryId)
	local category = categoryId and self.Categories[categoryId]
	if category and category.Color then
		return category.Color
	end
	return DEFAULT_TOAST_COLOR
end

function AchievementService:BuildToastPayload(id, def, progressEntry)
	local currencyReward = def.rewards and def.rewards.currency or 0

	return {
		id = id,
		name = def.name,
		description = def.description,
		category = def.category,
		icon = def.icon,
		currency = currencyReward,
		progress = {
			value = progressEntry.Value,
			target = progressEntry.Target,
		},
	}
end

function AchievementService:ComputeTrackerValue(profile, tracker, achievements, currentId)
	if not tracker then
		return 0
	end

	local data = profile.Data

	if tracker.type == "stat" then
		local stats = data.Statistics or {}
		return stats[tracker.key] or 0
	elseif tracker.type == "currency_total" then
		local currency = data.Currency or {}
		return currency.TotalEarned or 0
	elseif tracker.type == "playtime" then
		return data.TotalPlayTime or 0
	elseif tracker.type == "discovery_total" then
		return self:GetDiscoveryTotal(data.Discoveries)
	elseif tracker.type == "achievement_count" then
		local unlocked = achievements and achievements.Unlocked or {}
		local excludeMap

		if tracker.exclude then
			excludeMap = {}
			if typeof(tracker.exclude) == "table" then
				for _, excludedId in ipairs(tracker.exclude) do
					excludeMap[excludedId] = true
				end
			else
				excludeMap[tracker.exclude] = true
			end
		end

		if tracker.excludeSelf and currentId then
			excludeMap = excludeMap or {}
			excludeMap[currentId] = true
		end

		local count = 0
		for unlockedId in pairs(unlocked) do
			if not (excludeMap and excludeMap[unlockedId]) then
				count += 1
			end
		end

		return count
	end

	return 0
end

function AchievementService:GetDiscoveryTotal(discoveries)
	if not discoveries then
		return 0
	end

	local seen = {}
	local count = 0

	for _, entries in pairs(discoveries) do
		for _, entry in ipairs(entries) do
			local identifier
			if typeof(entry) == "table" then
				identifier = entry.Data or entry.Id or entry.Name
			else
				identifier = entry
			end

			if identifier and not seen[identifier] then
				seen[identifier] = true
				count += 1
			end
		end
	end

	return count
end

function AchievementService:UpdateAchievement(player, profile, achievements, id, def, value, options)
	options = options or {}
	local tracker = def.tracker
	if not tracker or not tracker.target then
		return
	end

	local target = tracker.target
	local progress = achievements.Progress[id]
	if not progress then
		progress = {}
		achievements.Progress[id] = progress
	end

	local previousValue = progress.Value or 0
	local clampedValue = clamp(value, 0, target)

	local unlockedRecord = achievements.Unlocked[id]
	local wasUnlocked = unlockedRecord ~= nil
	local prerequisitesMet = true

	if def.prerequisite then
		prerequisitesMet = achievements.Unlocked[def.prerequisite] ~= nil
	end

	local unlocking = (not wasUnlocked) and prerequisitesMet and clampedValue >= target

	progress.Value = clampedValue
	progress.Target = target
	progress.Unlocked = wasUnlocked or unlocking
	progress.LastUpdate = os.time()

	achievements.Progress[id] = progress

	if unlocking then
		local now = os.time()
		local rewardCurrency = def.rewards and def.rewards.currency or 0
		achievements.Unlocked[id] = {
			At = now,
			Currency = rewardCurrency,
		}

		if def.badgeId then
			task.spawn(function()
				local success, hasBadge = pcall(function()
					return BadgeService:UserHasBadgeAsync(player.UserId, def.badgeId)
				end)

				if success and not hasBadge then
					pcall(function()
						BadgeService:AwardBadgeAsync(player.UserId, def.badgeId)
					end)
				end
			end)
		end

		if not options.silent then
			self.UpdateEvent:Fire(player, {
				id = id,
				value = clampedValue,
				target = target,
				unlocked = true,
				readyToClaim = true,
			})

			if self.Notice and self.Notice.SendNotice then
				self.Notice.SendNotice(
					player,
					`Achievement Ready: {def.name}`,
					self:GetCategoryColor(def.category),
					4,
					"achievement_ready"
				)
			end
		end

		self:EvaluateDependents(player, profile, achievements, id)
	elseif clampedValue ~= previousValue and not options.silent then
		self.UpdateEvent:Fire(player, {
			id = id,
			value = clampedValue,
			target = target,
			unlocked = progress.Unlocked,
		})
	end

	if not options.deferSync then
		self:QueueSync(player)
	end
end

function AchievementService:EvaluateDependents(player, profile, achievements, id)
	local dependents = self.PrerequisiteIndex[id]
	if not dependents then
		return
	end

	for _, childId in ipairs(dependents) do
		local def = self.Achievements[childId]
		if def then
			local value = self:ComputeTrackerValue(profile, def.tracker, achievements, childId)
			self:UpdateAchievement(player, profile, achievements, childId, def, value)
		end
	end
end

function AchievementService:GetState(player)
	local state = self.State[player]
	if not state then
		local profile = self.PlayerDataManager.Profiles and self.PlayerDataManager.Profiles[player]
		if profile then
			self:OnProfileLoaded(player, profile)
			state = self.State[player]
		end
	end
	if not state then
		return nil
	end
	return state.profile, state.achievements
end

function AchievementService:HandleStatistic(player, key)
	local profile, achievements = self:GetState(player)
	if not profile then
		return
	end

	local trackers = self.TrackerIndex.stat and self.TrackerIndex.stat[key]
	if not trackers then
		return
	end

	local value = (profile.Data.Statistics and profile.Data.Statistics[key]) or 0

	for _, id in ipairs(trackers) do
		local def = self.Achievements[id]
		if def then
			self:UpdateAchievement(player, profile, achievements, id, def, value)
		end
	end
end

function AchievementService:HandleCurrency(player)
	local profile, achievements = self:GetState(player)
	if not profile then
		return
	end

	local trackers = self.TrackerIndex.currency_total
	if not trackers then
		return
	end

	local value = 0
	local currency = profile.Data.Currency
	if currency then
		value = currency.TotalEarned or 0
	end

	for _, id in ipairs(trackers) do
		local def = self.Achievements[id]
		if def then
			self:UpdateAchievement(player, profile, achievements, id, def, value)
		end
	end
end

function AchievementService:HandlePlaytime(player)
	local profile, achievements = self:GetState(player)
	if not profile then
		return
	end

	local trackers = self.TrackerIndex.playtime
	if not trackers then
		return
	end

	local value = profile.Data.TotalPlayTime or 0

	for _, id in ipairs(trackers) do
		local def = self.Achievements[id]
		if def then
			self:UpdateAchievement(player, profile, achievements, id, def, value)
		end
	end
end

function AchievementService:HandleDiscovery(player)
	local profile, achievements = self:GetState(player)
	if not profile then
		return
	end

	local trackers = self.TrackerIndex.discovery_total
	if trackers then
		local value = self:GetDiscoveryTotal(profile.Data.Discoveries)
		for _, id in ipairs(trackers) do
			local def = self.Achievements[id]
			if def then
				self:UpdateAchievement(player, profile, achievements, id, def, value)
			end
		end
	end

	local macroCount = self:GetSpecialDiscoveryCount(profile.Data.Discoveries, MACRO_CREATURES)
	self:RecordStat(player, "MacroDiscoveriesComplete", macroCount)

	local eventCreatures = {}
	local PhenomenonService = Mince:Get("PhenomenonService")
	if PhenomenonService and PhenomenonService.Registry then
		for _, definition in pairs(PhenomenonService.Registry) do
			if definition.ScanId and definition.ScanId ~= "" then
				table.insert(eventCreatures, definition.ScanId)
			end
		end
	end

	local eventCount = self:GetSpecialDiscoveryCount(profile.Data.Discoveries, eventCreatures)
	if eventCount > 0 then
		self:RecordStat(player, "EventCreaturesFound", eventCount)
	end
end

function AchievementService:GetSpecialDiscoveryCount(discoveries, idList)
	if not discoveries then
		return 0
	end

	local count = 0
	local seen = {}
	local targetIds = {}
	for _, id in ipairs(idList) do
		targetIds[id] = true
	end

	for _, entries in pairs(discoveries) do
		for _, entry in ipairs(entries) do
			local identifier = if typeof(entry) == "table" then (entry.Data or entry.Id) else entry
			if identifier and targetIds[identifier] and not seen[identifier] then
				seen[identifier] = true
				count = count + 1
			end
		end
	end

	return count
end

function AchievementService:SendChatAnnouncement(player, achievementName)
	local message = string.format('%s has claimed an achievement: ["%s"]!', player.Name, achievementName)

	local success = pcall(function()
		local textChannels = TextChatService:FindFirstChild("TextChannels")
		if textChannels then
			local generalChannel = textChannels:FindFirstChild("RBXGeneral")
			if generalChannel then
				generalChannel:SendAsync(message)
			end
		end
	end)

	if not success then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = message,
				Color = Color3.fromRGB(255, 230, 120),
				Font = Enum.Font.GothamBold,
				FontSize = Enum.FontSize.Size18,
			})
		end)
	end
end

function AchievementService:ClaimAchievement(player, id)
	local profile, achievements = self:GetState(player)
	if not profile then
		return
	end

	local def = self.Achievements[id]
	if not def then
		return
	end

	local unlockedData = achievements.Unlocked[id]
	if not unlockedData then
		return
	end

	if achievements.Claimed[id] then
		return
	end

	local rewardCurrency = def.rewards and def.rewards.currency or 0
	if rewardCurrency <= 0 and unlockedData then
		rewardCurrency = unlockedData.Currency or unlockedData.Points or 0
	end

	achievements.Claimed[id] = {
		At = os.time(),
		Currency = rewardCurrency,
	}

	if rewardCurrency > 0 then
		self.CurrencyService:GiveCurrency(player, rewardCurrency, "AchievementRewards")
	end

	self.ToastEvent:Fire(player, self:BuildToastPayload(id, def, achievements.Progress[id]))

	if self.Notice and self.Notice.SendNotice then
		self.Notice.SendNotice(
			player,
			`Achievement Claimed: {def.name}`,
			self:GetCategoryColor(def.category),
			4,
			"achievement_claim"
		)
	end

	self:SendChatAnnouncement(player, def.name)

	self:QueueSync(player)
end

return AchievementService
