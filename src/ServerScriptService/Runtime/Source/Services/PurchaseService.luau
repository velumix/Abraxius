local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Marketplace = require(ReplicatedStorage.Modules.Marketplace)
local PlayerDataManager = Mince:Get("PlayerDataManager")
local CurrencyService = Mince:Get("CurrencyService")
local StoreItems = Mince.Config.StoreItems
local MarketplaceProducts = Mince.Config.MarketplaceProducts

if not StoreItems then
	local success, result = pcall(function()
		return require(ReplicatedStorage.Runtime.Config.StoreItems)
	end)
	if success then
		StoreItems = result
	else
		warn("Failed to require StoreItems:", result)
		StoreItems = { Categories = {} }
	end
end

if not MarketplaceProducts then
	MarketplaceProducts = require(ReplicatedStorage.Runtime.Config.Shared.MarketplaceProducts)
end

local PassLookupById = {}
local GamepassMap = {}

for _, items in pairs(StoreItems.Categories) do
	for _, itemData in pairs(items) do
		if itemData.Gamepass then
			local gp = itemData.Gamepass
			if type(gp) == "string" then
				for _, config in pairs(Mince.Config) do
					if
						type(config) == "table"
						and (config.Key == gp or config.Name == gp)
						and (config.Id or config.GamepassId)
					then
						gp = config
						break
					end
				end
			end

			if type(gp) == "table" then
				local id = gp.Id or gp.GamepassId
				if id then
					PassLookupById[id] = gp
					local name = gp.Name or gp.Key
					if name then
						GamepassMap[id] = name
					end
				end
			end
		end
	end
end

for _, config in pairs(Mince.Config) do
	if type(config) == "table" and (config.GamepassId or config.Id) and config.EntitlementAttribute then
		local id = config.Id or config.GamepassId
		if id and not PassLookupById[id] then
			PassLookupById[id] = config
			local name = config.Name or config.Key
			if name and not GamepassMap[id] then
				GamepassMap[id] = name
			end
		end
	end
end

local DeveloperProducts = {}
local CurrencyAmounts = {}
local DonationProducts = {}

for _, product in ipairs(MarketplaceProducts.DeveloperProducts) do
	DeveloperProducts[product.Id] = product.Event
	CurrencyAmounts[product.Id] = product.CurrencyAmount
	DonationProducts[product.Id] = product.DonationAmount ~= nil
end

local EventHandlers = {
	CurrencyPurchase = function(player, eventData)
		local amount = CurrencyAmounts[eventData.ProductId]
		if not amount then
			local price = eventData.Price or 0
			if price <= 0 and RunService:IsStudio() then
				price = 100
				warn("Studio: Using mock price 100 for calculation")
			end
			amount = price * 10
		end

		if amount > 0 then
			if CurrencyService then
				CurrencyService:GiveCurrency(player, amount, "Purchase")
			else
				local profile = PlayerDataManager:GetProfileData(player)
				if profile then
					profile.Currency.Balance = (profile.Currency.Balance or 0) + amount
					PlayerDataManager:UpdatePlayer(player, "Currency")
				end
			end
		else
			warn("Unknown currency product or price:", eventData.ProductId)
		end
	end,

	SpawnLegendaryCreature = function(_player, _eventData) end,

	Explorer = function(player, _eventData)
		if player then
			player:SetAttribute("ExplorerPass", true)
		end
	end,

	Freecam = function(player, _eventData)
		if player then
			player:SetAttribute("FreecamPass", true)
		end
	end,
}

--[[
	@class PurchaseService
	@server

	Marketplace receipt processing and purchase prompt service.
]]

local PurchaseService = {
	Name = "PurchaseService",
	DeveloperProducts = DeveloperProducts,
	EventHandlers = EventHandlers,
	ExternalHandlers = {},
}

--[[
	Registers a developer product receipt handler.

	@within PurchaseService
	@param productId number
	@param handler function
]]
function PurchaseService:RegisterReceiptHandler(productId, handler)
	if type(productId) ~= "number" or type(handler) ~= "function" then
		warn("PurchaseService:RegisterReceiptHandler requires (number, function)")
		return
	end
	self.ExternalHandlers[productId] = handler
end

function PurchaseService:Setup()
	MarketplaceService.ProcessReceipt = function(r)
		return self:ProcessReceipt(r)
	end

	Marketplace.PromptPurchaseFinished:Connect(function(player, id, infoType)
		if infoType == Enum.InfoType.GamePass then
			self:HandleGamepassPurchase(player, id)
		end
	end)

	-- Developer products are granted exclusively by ProcessReceipt. The prompt
	-- completion signal is not authoritative proof that a receipt was fulfilled.

	Players.PlayerAdded:Connect(function(p)
		self:InitStats(p)
	end)

	if PlayerDataManager.ProfileLoaded then
		PlayerDataManager.ProfileLoaded:Connect(function(player)
			self:InitStats(player)
		end)
	end

	for _, p in pairs(Players:GetPlayers()) do
		self:InitStats(p)
	end

	local purchasePrompt = Mince:GetFunction("PurchasePrompt")
	purchasePrompt:Add(function(player, purchaseType, id)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return false, "PurchasePrompt requires a Player"
		end
		if purchaseType ~= "Product" and purchaseType ~= "Gamepass" then
			return false, "Unknown purchase prompt type"
		end
		if type(id) ~= "number" then
			return false, "PurchasePrompt id must be a number"
		end
	end)
	purchasePrompt.OnInvoke = function(player, purchaseType, id)
		if purchaseType == "Product" then
			return self:PromptDeveloperProduct(player, id)
		elseif purchaseType == "Gamepass" then
			return self:PromptGamepassPurchase(player, id)
		end
		return false
	end
end

function PurchaseService:InitStats(player)
	local profile = PlayerDataManager:GetProfileData(player)
	if profile and not profile.PurchaseStats then
		profile.PurchaseStats = {
			TotalPurchases = 0,
			TotalSpent = 0,
			ProductPurchases = {},
			GamepassPurchases = {},
			FirstPurchaseTime = nil,
			LastPurchaseTime = nil,
		}
		PlayerDataManager:SchedulePlayerUpdate(player, "PurchaseStats")
	end

	self:SyncPlayerPassOwnership(player)
end

function PurchaseService:SetPassAttribute(player, gamepassId, value)
	if not player then
		return
	end

	local passDef = PassLookupById[gamepassId]
	if passDef and passDef.EntitlementAttribute then
		player:SetAttribute(passDef.EntitlementAttribute, value and true or false)
	end
end

function PurchaseService:SyncPlayerPassOwnership(player)
	if not player then
		return
	end

	task.spawn(function()
		for passId, passDef in pairs(PassLookupById) do
			local attributeName = passDef and passDef.EntitlementAttribute
			if attributeName and player:GetAttribute(attributeName) == nil then
				player:SetAttribute(attributeName, false)
			end

			if passId then
				local success, owns =
					pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
				if success then
					if owns and attributeName then
						player:SetAttribute(attributeName, true)
					end
				else
					warn(string.format("Failed to verify %s (%d): %s", passDef.Name or "pass", passId, owns))
				end
			end
		end
	end)
end

function PurchaseService:UpdateStats(player, type, id, price)
	local profile = PlayerDataManager:GetProfileData(player)
	if not profile or not profile.PurchaseStats then
		return
	end

	local stats = profile.PurchaseStats

	stats.TotalPurchases = stats.TotalPurchases + 1
	stats.TotalSpent = stats.TotalSpent + (price or 0)
	stats.LastPurchaseTime = os.time()

	if not stats.FirstPurchaseTime then
		stats.FirstPurchaseTime = os.time()
	end

	if type == "Product" then
		stats.ProductPurchases[tostring(id)] = (stats.ProductPurchases[tostring(id)] or 0) + 1
	else
		stats.GamepassPurchases[tostring(id)] = 1
	end

	PlayerDataManager:SchedulePlayerUpdate(player, "PurchaseStats")
end

function PurchaseService:GetInfo(id, infoType)
	local success, info = Marketplace.GetProductInfo(id, infoType, true):await()
	return success and info or { Name = "Unknown", PriceInRobux = 0 }
end

function PurchaseService:ProcessReceipt(r)
	print("ProcessReceipt called for ProductId:", r.ProductId, "PurchaseId:", r.PurchaseId, "PlayerId:", r.PlayerId)

	local player = Players:GetPlayerByUserId(r.PlayerId)
	if not player then
		warn("Player not found for UserId:", r.PlayerId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local eventName = self.DeveloperProducts[r.ProductId]
	local externalHandler = self.ExternalHandlers[r.ProductId]

	if not eventName and not externalHandler then
		warn("No handler registered for ProductId:", r.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = PlayerDataManager:GetProfileData(player)

	if not profile then
		warn("Profile not loaded for player:", player.Name, "- waiting for profile...")

		local startTime = os.clock()
		local maxWait = 30

		while not profile and (os.clock() - startTime) < maxWait do
			if not player.Parent then
				warn("Player left before profile loaded:", player.Name)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			task.wait(0.5)
			profile = PlayerDataManager:GetProfileData(player)
		end

		if not profile then
			warn("Profile load timeout for player:", player.Name)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		print("Profile loaded after waiting for player:", player.Name)
	end

	profile.PurchaseHistory = profile.PurchaseHistory or {}
	if profile.PurchaseHistory[r.PurchaseId] then
		print("Purchase already processed (duplicate):", r.PurchaseId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local info = self:GetInfo(r.ProductId, Enum.InfoType.Product)

	-- External handlers (e.g., donation leaderboard) run first.
	if externalHandler then
		local extSuccess, decision = pcall(externalHandler, r)
		if not extSuccess then
			warn("External receipt handler failed for ProductId:", r.ProductId, decision)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if decision == false or decision == Enum.ProductPurchaseDecision.NotProcessedYet then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	-- Internal currency/event handlers.
	if eventName then
		local handler = self.EventHandlers[eventName]
		if handler then
			local success, err = pcall(
				handler,
				player,
				{ PurchaseId = r.PurchaseId, ProductId = r.ProductId, Price = info.PriceInRobux }
			)
			if not success then
				warn("Purchase handler failed for ProductId:", r.ProductId, err)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		else
			warn("No handler found for event:", eventName)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	print("Purchase processed successfully for:", player.Name)

	profile.PurchaseHistory[r.PurchaseId] = { ProductId = r.ProductId, Timestamp = os.time() }
	PlayerDataManager:SchedulePlayerUpdate(player, "PurchaseHistory")
	self:UpdateStats(player, "Product", r.ProductId, info.PriceInRobux)

	if DonationProducts[r.ProductId] then
		local AchievementService = Mince:Get("AchievementService")
		if AchievementService then
			AchievementService:RecordStat(player, "DonationsMade", 1)
		end
	end

	if PlayerDataManager.ForceSave then
		PlayerDataManager:ForceSave(player)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService:GrantDeveloperProduct(player, eventName, productInfo, receiptInfo)
	local eventData = {
		Player = player,
		PurchaseId = receiptInfo.PurchaseId,
		ProductId = receiptInfo.ProductId,
		ProductName = productInfo.Name,
		Price = productInfo.Price,
	}

	self.EventTriggered:Fire(player, eventName, eventData)

	print("Triggered event", eventName, "for", player.Name)

	return true
end

function PurchaseService:HandleGamepassPurchase(player, id)
	local eventName = GamepassMap[id]
	if not eventName then
		return
	end

	local info = self:GetInfo(id, Enum.InfoType.GamePass)
	local profile = PlayerDataManager:GetProfileData(player)

	if profile then
		profile.Gamepasses = profile.Gamepasses or {}
		profile.Gamepasses[id] = { PurchaseTime = os.time(), Name = info.Name }
		PlayerDataManager:SchedulePlayerUpdate(player, "Gamepasses")
	end

	self:SetPassAttribute(player, id, true)

	self:UpdateStats(player, "Gamepass", id, info.PriceInRobux)

	local handler = self.EventHandlers[eventName]
	if handler then
		handler(player, { GamepassId = id, GamepassName = info.Name })
	end
end

function PurchaseService:PromptGamepassPurchase(player, gamepassId)
	if not GamepassMap[gamepassId] then
		warn("Attempting to prompt purchase for unregistered gamepass:", gamepassId)
		return false
	end
	Marketplace.PromptPurchase(gamepassId, Enum.InfoType.GamePass, player)
	return true
end

function PurchaseService:PromptDeveloperProduct(player, productId)
	if not self.DeveloperProducts[productId] then
		warn("Attempting to prompt purchase for unregistered developer product:", productId)
		return false
	end
	Marketplace.PromptPurchase(productId, Enum.InfoType.Product, player)
	return true
end

return PurchaseService
