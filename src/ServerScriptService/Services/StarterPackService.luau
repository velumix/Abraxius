local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StarterPackService = Knit.CreateService({
	Name = "StarterPackService",
	Client = {
		Purchased = Knit.CreateSignal(),
	},
})

-- Existing dev product: 3606548877 (also used by GiftService catalog)
local STARTER_PACK_PRODUCT_ID = 3606548877

local DataService

StarterPackService.PRODUCT_ID = STARTER_PACK_PRODUCT_ID

function StarterPackService:KnitInit() end

function StarterPackService:KnitStart()
	DataService = Knit.GetService("DataService")
end

function StarterPackService.Client:GetStatus(player)
	local ds = DataService or Knit.GetService("DataService")
	local ok, status = pcall(function()
		ds:WaitForData(player)
		return ds:GetStarterPackStatus(player)
	end)
	if ok then
		return status
	end
	warn("[StarterPackService] status failed: " .. tostring(status))
	return { state = "not_started", expiresAt = 0, secondsRemaining = 900 }
end

function StarterPackService.Client:StartTimer(player)
	local ds = DataService or Knit.GetService("DataService")
	local ok, expiresAt = pcall(function()
		ds:StartStarterPackTimer(player)
	end)
	if not ok then
		warn("[StarterPackService] start timer failed: " .. tostring(expiresAt))
		return 0
	end
	if type(expiresAt) ~= "number" then
		local status = ds:GetStarterPackStatus(player)
		expiresAt = status and status.expiresAt or 0
	end
	return expiresAt
end

return StarterPackService
