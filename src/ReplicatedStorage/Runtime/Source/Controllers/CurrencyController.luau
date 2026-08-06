local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules:WaitForChild("Mince"))
local Signal = require(Modules:WaitForChild("Signal"))

local LocalPlayer = Players.LocalPlayer

local StateFolder = ReplicatedStorage.Modules.Mince.Addons.state:WaitForChild("States")

local function GetCurrencyStateName(userId)
	return "Currency_" .. tostring(userId)
end

local function GetEcoPointsStateName(userId)
	return "EcoPoints_" .. tostring(userId)
end

local function WaitForState(stateName, timeout)
	timeout = timeout or 30
	local startTime = os.clock()
	local warned = false

	while true do
		if StateFolder:FindFirstChild(stateName) then
			return Mince:GetState(stateName)
		end

		if not warned and os.clock() - startTime > timeout then
			warn("Timed out waiting for Mince state, continuing to wait:", stateName)
			warned = true
		end

		StateFolder.ChildAdded:Wait()
	end
end

local CurrencyController = {
	Name = "CurrencyController",

	_currencyData = {},
	_ecoPointsData = {},
	_loaded = false,

	CurrencyUpdated = Signal.new(),
	EcoPointsUpdated = Signal.new(),
}

function CurrencyController:Setup()
end

function CurrencyController:GameStart()
	local currencyState = WaitForState(GetCurrencyStateName(LocalPlayer.UserId))
	local ecoState = WaitForState(GetEcoPointsStateName(LocalPlayer.UserId))

	self._currencyData = {
		Balance = currencyState.Balance or 0,
		TotalEarned = currencyState.TotalEarned or 0,
		TotalSpent = currencyState.TotalSpent or 0,
	}

	self._ecoPointsData = {
		Balance = ecoState.Balance or 0,
		TotalEarned = ecoState.TotalEarned or 0,
		TotalSpent = ecoState.TotalSpent or 0,
	}

	currencyState:Observe("Balance", function(newBalance, oldBalance)
		local old = oldBalance or self._currencyData.Balance or 0
		local change = newBalance - old
		self._currencyData.Balance = newBalance
		self.CurrencyUpdated:Fire(newBalance, change)
	end)

	ecoState:Observe("Balance", function(newBalance, oldBalance)
		local old = oldBalance or self._ecoPointsData.Balance or 0
		local change = newBalance - old
		self._ecoPointsData.Balance = newBalance
		self.EcoPointsUpdated:Fire(newBalance, change)
	end)

	self._loaded = true
end

function CurrencyController:GetEcoBalance()
	return self._ecoPointsData.Balance or 0
end

function CurrencyController:GetBalance()
	return self._currencyData.Balance or 0
end

function CurrencyController:GetTotalEarned()
	return self._currencyData.TotalEarned or 0
end

function CurrencyController:GetTotalSpent()
	return self._currencyData.TotalSpent or 0
end

function CurrencyController:GetCurrencyData()
	return self._currencyData
end

function CurrencyController:IsLoaded()
	return self._loaded
end

function CurrencyController:WaitUntilLoaded()
	repeat task.wait() until self._loaded
end

return CurrencyController
