--!strict
-- @author Velumix
-- @version 0.0.1
--[=[
	@class GameAnalyticsService
	@server
	Hooks this game's events into AnalyticsService.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsConfig = require(ReplicatedStorage.Config.AnalyticsConfig)
local Knit = require(ReplicatedStorage.Modules.Knit)
local Trove = require(ReplicatedStorage.Modules.Trove)

local Service = Knit.CreateService({ Name = "GameAnalyticsService", Client = {} })
Service._trove = Trove.new()

function Service:KnitInit()
	self._analytics = Knit.GetService("AnalyticsService")
	self._data = Knit.GetService("PlayerDataService")
	self._weapons = Knit.GetService("WeaponService")
end

function Service:KnitStart()
	local function joined(player: Player)
		self._analytics:LogStep(player, "Onboarding", 1)
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	self._trove:Connect(Players.PlayerAdded, joined)
	self._trove:Connect(self._data.DataLoaded, function(player)
		self._analytics:LogStep(player, "Onboarding", 2)
	end)
	self._trove:Connect(self._data.MutationApplied, function(player, operation, reason, details)
		if operation ~= "AwardCurrency" and operation ~= "SpendCurrency" then
			return
		end
		local currency = details.Currency
		local amount = details.Amount
		local balance = self._data:GetValue(player, currency)
		if type(currency) ~= "string" or type(amount) ~= "number" or type(balance) ~= "number" then
			return
		end
		local flow: "Source" | "Sink" = if operation == "AwardCurrency" then "Source" else "Sink"
		local fallback = if flow == "Source"
			then AnalyticsConfig.Economy.DefaultSourceTransaction
			else AnalyticsConfig.Economy.DefaultSinkTransaction
		local transactionType = AnalyticsConfig.Economy.TransactionByReason[reason] or fallback
		self._analytics:LogEconomy(player, flow, currency, amount, balance, transactionType, reason)
	end)
	for _, player in Players:GetPlayers() do
		if self._data:GetState(player) == "Ready" then
			self._analytics:LogStep(player, "Onboarding", 2)
		end
	end
	self._trove:Connect(self._weapons.WeaponEquipped, function(player, _tool, equipped)
		if equipped then
			self._analytics:LogStep(player, "Onboarding", 3)
		end
	end)
	self._trove:Connect(self._weapons.WeaponActivated, function(player)
		self._analytics:LogStep(player, "Onboarding", 4)
	end)
	self._trove:Connect(self._weapons.CharacterHit, function(player)
		self._analytics:LogStep(player, "Onboarding", 5)
	end)
end

function Service:Destroy()
	self._trove:Destroy()
end

return Service
