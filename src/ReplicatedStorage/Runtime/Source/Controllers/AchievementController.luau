local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Mince = require(Modules:WaitForChild("Mince"))
local UI = require(Modules:WaitForChild("UI"))

local UserProfile = require(ReplicatedStorage.Runtime.Source.UserProfile)
local AchievementConfig = require(ReplicatedStorage.Runtime.Config.Shared.Achievements)

local AchievementController = {
	Name = "AchievementController",
	_isVisible = false,
	_needsRender = true,
	Panel = nil,
	_currencyConnection = nil,
}

function AchievementController:Setup()
	self.Player = Players.LocalPlayer
	self.AchievementData = {}
	self.Achievements = AchievementConfig.Achievements or {}
	self.Categories = AchievementConfig.Categories or {}
	self.CurrencyController = Mince:Get("CurrencyController")

	self.Remote = Mince:GetEvent("Achievements")
	self.ToastEvent = self.Remote:Extend("Toast")
	self.UpdateEvent = self.Remote:Extend("Update")
	self.ClaimEvent = self.Remote:Extend("Claim")
end

function AchievementController:GameStart()
	self.PlayerGui = self.Player:WaitForChild("PlayerGui")

	self.Panel = UI.Achievements.new(self.PlayerGui, {
		OnClose = function()
			self:Hide()
		end,
	}, self)

	self:ConnectProfile()
	self:ConnectRemotes()
	self:ConnectCurrency()

	self:RenderList()
	self:RefreshBalanceDisplay()
end

function AchievementController:ConnectRemotes()
	self.ToastEvent.Event:Connect(function(payload)
		self:OnToast(payload)
	end)

	self.UpdateEvent.Event:Connect(function(payload)
		self:OnProgressUpdate(payload)
	end)
end

function AchievementController:ConnectProfile()
	UserProfile:Upon("Achievements", function(data)
		self:OnProfileSync(data)
	end)
end

function AchievementController:ConnectCurrency()
	if not self.CurrencyController or not self.CurrencyController.CurrencyUpdated then
		return
	end

	if self._currencyConnection then
		self._currencyConnection:Disconnect()
		self._currencyConnection = nil
	end

	self._currencyConnection = self.CurrencyController.CurrencyUpdated:Connect(function(balance)
		if self.Panel then
			self.Panel:SetCoins(balance)
		end
	end)

	task.defer(function()
		self:RefreshBalanceDisplay()
	end)
end

function AchievementController:RefreshBalanceDisplay()
	if not self.Panel then
		return
	end

	local balance = 0
	if self.CurrencyController and self.CurrencyController.GetBalance then
		balance = self.CurrencyController:GetBalance()
	end

	self.Panel:SetCoins(balance)
end

function AchievementController:OnToast(payload)
	if not payload then
		return
	end

	local lines = {}
	table.insert(lines, string.format("Achievement: %s", payload.name or payload.id or "Achievement"))

	if payload.description and payload.description ~= "" then
		table.insert(lines, payload.description)
	end

	local rewards = {}
	if payload.currency and payload.currency > 0 then
		table.insert(rewards, string.format("+%d coins", payload.currency))
	end
	if #rewards > 0 then
		table.insert(lines, table.concat(rewards, " · "))
	end

	UI.Notification.Success(table.concat(lines, "\n"), 5)

	self.AchievementData.Progress = self.AchievementData.Progress or {}
	self.AchievementData.Unlocked = self.AchievementData.Unlocked or {}

	if payload.progress then
		self.AchievementData.Progress[payload.id] = {
			Value = payload.progress.value or payload.progress.Value or 0,
			Target = payload.progress.target or payload.progress.Target or 0,
			Unlocked = true,
			LastUpdate = os.time(),
		}
	end

	self.AchievementData.Unlocked[payload.id] = self.AchievementData.Unlocked[payload.id] or {
		At = os.time(),
	}

	if self._isVisible then
		self:RenderList()
	else
		self._needsRender = true
	end

	self:RefreshBalanceDisplay()
end

function AchievementController:OnProgressUpdate(payload)
	if not payload or not payload.id then
		return
	end

	self.AchievementData.Progress = self.AchievementData.Progress or {}
	local progress = self.AchievementData.Progress[payload.id] or {}
	progress.Value = payload.value or progress.Value or 0
	progress.Target = payload.target or progress.Target
	progress.Unlocked = payload.unlocked or progress.Unlocked
	progress.LastUpdate = os.time()
	self.AchievementData.Progress[payload.id] = progress

	if payload.unlocked then
		self.AchievementData.Unlocked = self.AchievementData.Unlocked or {}
		self.AchievementData.Unlocked[payload.id] = self.AchievementData.Unlocked[payload.id] or {
			At = os.time(),
		}
	end

	if self._isVisible then
		self:RenderList()
	else
		self._needsRender = true
	end

	if self.Panel and not self._isVisible then
		self:RenderList()
	end
end

function AchievementController:OnProfileSync(data)
	if not data then
		return warn("OnProfileSync: No data received")
	end

	self.AchievementData = data

	self:RenderList()
	self._needsRender = false
	self:RefreshBalanceDisplay()
end

function AchievementController:ClaimAchievement(achievementId)
	if not achievementId then
		return
	end

	local data = self.AchievementData or {}
	local unlockedMap = data.Unlocked or {}
	local claimedMap = data.Claimed or {}

	if unlockedMap[achievementId] and not claimedMap[achievementId] then
		self.ClaimEvent:Fire(achievementId)

		data.Claimed = data.Claimed or {}
		data.Claimed[achievementId] = {
			At = os.time(),
			Optimistic = true
		}

		if self._isVisible then
			self:RenderList()
		end
	end
end

function AchievementController:GetCategoryHeader(categoryId)
	local category = self.Categories[categoryId]
	if category then
		return category.Name, category.Color
	end
	return "General", Color3.fromRGB(200, 210, 230)
end

function AchievementController:GetProgressState(id, def)
	local data = self.AchievementData or {}
	local progress = data.Progress and data.Progress[id]
	local unlocked = data.Unlocked and data.Unlocked[id]
	local value = 0
	local target = def.tracker and def.tracker.target or 1

	if progress then
		value = progress.Value or value
		target = progress.Target or target
	elseif unlocked then
		value = target
	end

	local percent = 0
	if target > 0 then
		percent = math.clamp(value / target, 0, 1)
	end


	return value, target, percent, unlocked ~= nil
end

function AchievementController:BuildEntryModels()
	local entries = {}
	local data = self.AchievementData or {}
	local claimedMap = data.Claimed or {}
	local progressMap = data.Progress or {}

	local function hasMetPrerequisite(prerequisiteId)
		if not prerequisiteId then
			return true
		end

		if claimedMap[prerequisiteId] ~= nil then
			return true
		end

		local prerequisiteProgress = progressMap[prerequisiteId]
		if not prerequisiteProgress then
			return false
		end

		if prerequisiteProgress.Unlocked then
			return true
		end

		local prerequisiteDef = self.Achievements[prerequisiteId]
		local target = prerequisiteProgress.Target
		if target == nil and prerequisiteDef and prerequisiteDef.tracker then
			target = prerequisiteDef.tracker.target
		end

		target = target or 0
		if target <= 0 then
			return true
		end

		local value = prerequisiteProgress.Value or 0
		return value >= target
	end

	for id, def in pairs(self.Achievements) do
		local categoryName, categoryColor = self:GetCategoryHeader(def.category)
		local value, target, percent, unlocked = self:GetProgressState(id, def)
		local prerequisiteMet = hasMetPrerequisite(def.prerequisite)
		local claimed = claimedMap[id] ~= nil
		local canClaim = unlocked and not claimed
		local statusText
		local progressText
		local badgeTheme = "progress"
		local progressTheme = "progress"
		local isClaimable = false

		if def.prerequisite and not prerequisiteMet then
			local prerequisiteDef = self.Achievements[def.prerequisite]
			statusText = string.format("Requires %s", prerequisiteDef and prerequisiteDef.name or def.prerequisite)
			local prerequisiteProgress = progressMap[def.prerequisite]
			if prerequisiteProgress then
				local prerequisiteTarget = prerequisiteProgress.Target
				if prerequisiteTarget == nil and prerequisiteDef and prerequisiteDef.tracker then
					prerequisiteTarget = prerequisiteDef.tracker.target
				end
				prerequisiteTarget = prerequisiteTarget or 0
				local prerequisiteValue = prerequisiteProgress.Value or 0
				if prerequisiteTarget <= 0 then
					progressText = string.format("%d prerequisite progress", prerequisiteValue)
				else
					progressText = string.format("%d / %d prerequisite", prerequisiteValue, prerequisiteTarget)
				end
			else
				progressText = "Awaiting prerequisite"
			end
			badgeTheme = "blocked"
			progressTheme = "blocked"
			percent = 0
		elseif claimed then
			statusText = "Claimed"
			progressText = "Completed"
			badgeTheme = "claimed"
			progressTheme = "claimed"
		elseif canClaim then
			statusText = "Claim"
			progressText = "Ready to claim!"
			badgeTheme = "claimable"
			progressTheme = "claimable"
			isClaimable = true
		elseif unlocked then
			statusText = "Unlocked"
			progressText = "Completed"
			badgeTheme = "unlocked"
			progressTheme = "unlocked"
		else
			statusText = string.format("%d%%", math.floor(percent * 100))
			progressText = string.format("%d / %d", value, target)
		end

		local icon = def.icon
		if not icon and def.category then
			local categoryDef = self.Categories[def.category]
			if categoryDef then
				icon = categoryDef.Icon
			end
		end

		table.insert(entries, {
			id = id,
			name = def.name or id,
			description = def.description or "",
			icon = icon,
			order = def.order,
			category = {
				id = def.category,
				name = categoryName,
				color = categoryColor,
			},
			statusText = statusText,
			progressText = progressText,
			percent = percent,
			badgeTheme = badgeTheme,
			progressTheme = progressTheme,
			targetValue = target,
			isClaimable = isClaimable,
		})
	end

	table.sort(entries, function(a, b)
		local categoryA = (a.category and a.category.name or ""):lower()
		local categoryB = (b.category and b.category.name or ""):lower()
		if categoryA == categoryB then
			local orderA = a.order or math.huge
			local orderB = b.order or math.huge
			if orderA ~= orderB then
				return orderA < orderB
			end
			if (a.targetValue or math.huge) ~= (b.targetValue or math.huge) then
				return (a.targetValue or math.huge) < (b.targetValue or math.huge)
			end
			return (a.name or "") < (b.name or "")
		end
		return categoryA < categoryB
	end)

	return entries
end

function AchievementController:RenderList()
	if not self.Panel then
		return
	end

	local entries = self:BuildEntryModels()

	self.Panel:Render(entries)
	self._needsRender = false
end

function AchievementController:Show()
	if not self.Panel then
		return
	end

	if self._isVisible then
		return
	end

	self.Panel:Show()
	self._isVisible = true

	if self._needsRender then
		self:RenderList()
	end
end

function AchievementController:Hide()
	if not self.Panel then
		return
	end

	self.Panel:Hide()
	self._isVisible = false
end

function AchievementController:Toggle()
	if self._isVisible then
		self:Hide()
	else
		self:Show()
	end
end

return AchievementController
