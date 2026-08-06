local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local TableUtil = require(ReplicatedStorage.Modules.TableUtil)

local PlayerDataManager = Mince:Get("PlayerDataManager")
local AchievementService = Mince:Get("AchievementService")

--[[
	@class CurrencyService
	@server

	Server authority for Credits and EcoPoints.

	CurrencyService updates ProfileService data through PlayerDataManager,
	mirrors balances into Mince state objects for clients, awards gameplay
	currency, spends shop currency, tracks passive income, and records Roblox
	economy analytics outside Studio.
]]

local function getProfileData(player)
	local profileData = PlayerDataManager:GetProfileData(player)
	if not profileData then
		return nil
	end
	return profileData
end

local CurrencyService = {
	Name = "CurrencyService",

	Config = {
		PassiveIncomeAmount = 10,
		PassiveIncomeInterval = 180,
		EventRewardMultiplier = 1.5,
		ScanRewardBase = 5,
		ScanRewardAmount = 10,
		ExplorationRewardBase = 25,
	},

	_activePlayers = {},
	_lastUpdate = 0,
}

local CURRENCY_NAME = "Credits"
local ECOPOINTS_NAME = "EcoPoints"

local TRANSACTION_TYPE_BY_SOURCE = {
	PassiveIncome = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
	ScanningRewards = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	ExplorationRewards = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	EventRewards = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	["Debris Cleanup"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
}

local function GetCurrencyStateName(player)
	return "Currency_" .. tostring(player.UserId)
end

local function GetEcoPointsStateName(player)
	return "EcoPoints_" .. tostring(player.UserId)
end

local function SyncCurrencyState(player)
	local profileData = getProfileData(player)
	if not profileData then
		return
	end

	local currencyData = profileData.Currency
	local state = Mince:GetState(GetCurrencyStateName(player))
	state.Balance = currencyData.Balance
	state.TotalEarned = currencyData.TotalEarned
	state.TotalSpent = currencyData.TotalSpent
	state.LastIncomeTime = currencyData.LastIncomeTime
	state.IncomeStreak = currencyData.IncomeStreak
	state.Sources = TableUtil.Copy(currencyData.Sources, true)
end

local function SyncEcoPointsState(player)
	local profileData = getProfileData(player)
	if not profileData then
		return
	end

	local ecoData = profileData.EcoPoints
	local state = Mince:GetState(GetEcoPointsStateName(player))
	state.Balance = ecoData.Balance
	state.TotalEarned = ecoData.TotalEarned
	state.TotalSpent = ecoData.TotalSpent
	state.Sources = TableUtil.Copy(ecoData.Sources, true)
end

local function resolveTransactionType(source, fallback)
	if source and TRANSACTION_TYPE_BY_SOURCE[source] then
		return TRANSACTION_TYPE_BY_SOURCE[source]
	end
	if source == "Shop" or source == "Store" or source == "Purchase" then
		return Enum.AnalyticsEconomyTransactionType.Shop.Name
	end
	return fallback or Enum.AnalyticsEconomyTransactionType.Gameplay.Name
end

function CurrencyService:_LogEconomyEvent(player, flowType, currencyName, amount, balance, transactionType, itemSku, itemType, itemId, location)
	if RunService:IsStudio() then
		return
	end
	if not player or amount <= 0 then
		return
	end

	local ok, err = pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			currencyName,
			amount,
			balance,
			transactionType or Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			itemSku,
			itemType,
			itemId,
			location
		)
	end)

	if not ok then
		warn("Economy event failed:", err)
	end
end

--[[
	Records a Roblox economy analytics event.

	@within CurrencyService
	@param player Player
	@param flowType Enum.AnalyticsEconomyFlowType
	@param currencyName string
	@param amount number
	@param balance number
	@param transactionType string?
	@param itemSku string?
	@param itemType string?
	@param itemId string?
	@param location string?
]]
function CurrencyService:LogEconomyEvent(player, flowType, currencyName, amount, balance, transactionType, itemSku, itemType, itemId, location)
	self:_LogEconomyEvent(player, flowType, currencyName, amount, balance, transactionType, itemSku, itemType, itemId, location)
end

--[[
	Starts profile, player, and passive-income listeners.

	@within CurrencyService
]]
function CurrencyService:Setup()
	PlayerDataManager.ProfileLoaded:Connect(function(player, profile)
		if profile then
			self:_StartTrackingPlayer(player, profile.Data)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_OnPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_OnPlayerRemoving(player)
	end)

	for _, player in pairs(Players:GetPlayers()) do
		self:_OnPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(function()
		self:_ProcessPassiveIncome()
	end)
end

function CurrencyService:_StartTrackingPlayer(player, profileData)
	if not player or not player.Parent or not profileData or not profileData.Currency then
		return
	end

	self._activePlayers[player] = {
		LastActivity = tick(),
		SessionStart = tick(),
		LastIncomeTime = profileData.Currency.LastIncomeTime or tick(),
	}

	PlayerDataManager:UpdatePlayer(player, "Currency")
	SyncCurrencyState(player)

	if profileData.EcoPoints then
		SyncEcoPointsState(player)
	end
end

function CurrencyService:_OnPlayerAdded(player)
	local profileData = getProfileData(player)
	if not profileData then
		return
	end

	self:_StartTrackingPlayer(player, profileData)
end

function CurrencyService:_OnPlayerRemoving(player)
	self._activePlayers[player] = nil
end

function CurrencyService:_ProcessPassiveIncome()
	local currentTime = tick()

	if currentTime - self._lastUpdate < 1 then
		return
	end
	self._lastUpdate = currentTime

	for player, activityData in pairs(self._activePlayers) do
		if not player.Parent then
			self._activePlayers[player] = nil
			continue
		end

		if currentTime - activityData.LastActivity > 300 then
			continue
		end

		if currentTime - activityData.LastIncomeTime >= self.Config.PassiveIncomeInterval then
			self:_GivePassiveIncome(player)
			activityData.LastIncomeTime = currentTime
		end
	end
end

function CurrencyService:_GivePassiveIncome(player)
	local profileData = getProfileData(player)
	if not profileData then
		return
	end
	local currencyData = profileData.Currency

	local amount = self.Config.PassiveIncomeAmount

	currencyData.Balance = currencyData.Balance + amount
	currencyData.TotalEarned = currencyData.TotalEarned + amount
	currencyData.Sources.PassiveIncome = currencyData.Sources.PassiveIncome + amount
	currencyData.LastIncomeTime = tick()
	currencyData.IncomeStreak = currencyData.IncomeStreak + 1

	PlayerDataManager:UpdatePlayer(player, "Currency")
	SyncCurrencyState(player)

	self:_SendCurrencyNotification(player, "Passive Income", amount)

	self:_LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		CURRENCY_NAME,
		amount,
		currencyData.Balance,
		resolveTransactionType("PassiveIncome"),
		"PassiveIncome"
	)
end

function CurrencyService:_SendCurrencyNotification(player, source, amount, currencyType)
	currencyType = currencyType or "Credits"

end

--[[
	Records collected debris and awards cleanup currency.

	@within CurrencyService
	@param player Player
	@param trashName string
	@return boolean
]]
function CurrencyService:CollectTrash(player, trashName)
	local profileData = getProfileData(player)
	if not profileData then
		return false
	end

	if not profileData.CollectedTrash then
		profileData.CollectedTrash = {}
	end

	local currentCount = profileData.CollectedTrash[trashName] or 0
	profileData.CollectedTrash[trashName] = currentCount + 1

	local Statistics = Mince:Get("Statistics")
	if Statistics then
		Statistics:Record(player, "TrashCollected", 1)
	end

	self:GiveEcoPoints(player, 1, "Debris Cleanup")
	self:GiveCurrency(player, 1, "Debris Cleanup")
	PlayerDataManager:UpdatePlayer(player, "CollectedTrash")

	return true
end

--[[
	Adds EcoPoints to a player's profile and replicated state.

	@within CurrencyService
	@param player Player
	@param amount number
	@param source string?
	@return boolean
]]
function CurrencyService:GiveEcoPoints(player, amount, source)
	local profileData = getProfileData(player)
	if not profileData then
		return false
	end
	if not profileData.EcoPoints then
		profileData.EcoPoints = {
			Balance = 0,
			TotalEarned = 0,
			TotalSpent = 0,
			Sources = {}
		}
	end

	local ecoData = profileData.EcoPoints

	if amount <= 0 then return false end

	ecoData.Balance = ecoData.Balance + amount
	ecoData.TotalEarned = ecoData.TotalEarned + amount

	if source then
		ecoData.Sources[source] = (ecoData.Sources[source] or 0) + amount
	end

	PlayerDataManager:UpdatePlayer(player, "EcoPoints")
	SyncEcoPointsState(player)

	self:_SendCurrencyNotification(player, source, amount, "EcoPoints")

	local transactionType = resolveTransactionType(source)
	self:_LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		ECOPOINTS_NAME,
		amount,
		ecoData.Balance,
		transactionType,
		source
	)

	return true
end

function CurrencyService:GetEcoPoints(player)
	local profileData = getProfileData(player)
	if not profileData then
		return 0
	end
	if not profileData.EcoPoints then return 0 end
	return profileData.EcoPoints.Balance or 0
end

--[[
	Spends EcoPoints and syncs profile, state, and economy analytics.

	@within CurrencyService
	@param player Player
	@param amount number
	@param source string?
	@return boolean
]]
function CurrencyService:SpendEcoPoints(player, amount, source)
	local profileData = getProfileData(player)
	if not profileData then
		return false
	end
	if not profileData.EcoPoints then
		profileData.EcoPoints = {
			Balance = 0,
			TotalEarned = 0,
			TotalSpent = 0,
			Sources = {}
		}
	end

	local ecoData = profileData.EcoPoints

	if amount <= 0 or (ecoData.Balance or 0) < amount then
		return false
	end

	ecoData.Balance = (ecoData.Balance or 0) - amount
	ecoData.TotalSpent = (ecoData.TotalSpent or 0) + amount

	PlayerDataManager:UpdatePlayer(player, "EcoPoints")
	SyncEcoPointsState(player)

	local transactionType = resolveTransactionType(source, Enum.AnalyticsEconomyTransactionType.Shop.Name)
	self:_LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		ECOPOINTS_NAME,
		amount,
		ecoData.Balance,
		transactionType,
		source
	)

	return true
end

--[[
	Adds Credits to a player's profile and replicated state.

	@within CurrencyService
	@param player Player
	@param amount number
	@param source string?
	@return boolean
]]
function CurrencyService:GiveCurrency(player, amount, source)
	local profileData = getProfileData(player)
	if not profileData then
		return false
	end
	local currencyData = profileData.Currency

	if amount <= 0 then return false end

	currencyData.Balance = currencyData.Balance + amount
	currencyData.TotalEarned = currencyData.TotalEarned + amount

	if source and currencyData.Sources[source] then
		currencyData.Sources[source] = currencyData.Sources[source] + amount
	end

	PlayerDataManager:UpdatePlayer(player, "Currency")
	AchievementService:HandleCurrency(player)
	SyncCurrencyState(player)

	self:_SendCurrencyNotification(player, source or "Unknown", amount)

	local transactionType = resolveTransactionType(source)
	self:_LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		CURRENCY_NAME,
		amount,
		currencyData.Balance,
		transactionType,
		source
	)

	local Leaderboards = Mince:Get("Leaderboards")
	if Leaderboards then
		Leaderboards:UpdateLeaderboard(player, "TotalCoins", currencyData.TotalEarned)
	end

	return true
end

--[[
	Attempts to spend Credits from a player's balance.

	@within CurrencyService
	@param player Player
	@param amount number
	@param source string?
	@return boolean
]]
function CurrencyService:SpendCurrency(player, amount, source)
	local profileData = getProfileData(player)
	if not profileData then
		return false
	end
	local currencyData = profileData.Currency

	if amount <= 0 or currencyData.Balance < amount then
		return false
	end

	currencyData.Balance = currencyData.Balance - amount
	currencyData.TotalSpent = currencyData.TotalSpent + amount

	PlayerDataManager:UpdatePlayer(player, "Currency")
	SyncCurrencyState(player)

	local transactionType = resolveTransactionType(source, Enum.AnalyticsEconomyTransactionType.Shop.Name)
	self:_LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		CURRENCY_NAME,
		amount,
		currencyData.Balance,
		transactionType,
		source
	)

	return true
end

function CurrencyService:GetBalance(player)
	local profileData = getProfileData(player)
	if not profileData then
		return 0
	end
	return profileData.Currency.Balance
end

function CurrencyService:UpdatePlayerActivity(player)
	if self._activePlayers[player] then
		self._activePlayers[player].LastActivity = tick()
	end
end

function CurrencyService:GiveEventReward(player, baseAmount)
	local amount = math.floor(baseAmount * self.Config.EventRewardMultiplier)
	return self:GiveCurrency(player, amount, "EventRewards")
end

function CurrencyService:GiveScanReward(player, creatureRarity)
	local multiplier = creatureRarity or 1
	local baseAmount = self.Config.ScanRewardAmount or self.Config.ScanRewardBase or 0
	local amount = baseAmount * multiplier
	return self:GiveCurrency(player, amount, "ScanningRewards")
end

function CurrencyService:GiveExplorationReward(player, areaImportance)
	local multiplier = areaImportance or 1
	local amount = self.Config.ExplorationRewardBase * multiplier
	return self:GiveCurrency(player, amount, "ExplorationRewards")
end

return CurrencyService
