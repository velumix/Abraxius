--!nocheck
-- @author Velumix
-- @version 0.0.1
--[=[
	@class CommerceService
	@server
	Owns developer-product receipts and configured marketplace prompts.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local CommerceConfig = require(ReplicatedStorage.Config.CommerceConfig)
local Knit = require(ReplicatedStorage.Modules.Knit)
local Marketplace = require(ReplicatedStorage.Modules.Marketplace)
local NetGuard = require(ServerScriptService.NetGuard)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)

local CommerceService = Knit.CreateService({
	Name = "CommerceService",
	Client = {
		PurchaseProcessed = Knit.CreateSignal(),
		GamePassPurchased = Knit.CreateSignal(),
	},
})

--[=[
	@prop PurchaseProcessed Signal
	@within CommerceService
	Fires after a newly granted developer product is durable.
]=]
CommerceService.PurchaseProcessed = Signal.new()
--[=[
	@prop GamePassPurchased Signal
	@within CommerceService
	Fires after a game-pass cache update is durable.
]=]
CommerceService.GamePassPurchased = Signal.new()
CommerceService._productHandlers = {}
CommerceService._processingReceipts = {}
CommerceService._trove = Trove.new()

local function resolveCatalogId(catalog, value): number?
	if type(value) == "number" and catalog[value] then
		return value
	end
	if type(value) == "string" then
		for id, name in pairs(catalog) do
			if name == value then
				return id
			end
		end
	end
	return nil
end

NetGuard.Define("Commerce.PromptProduct", {
	RateLimit = { Requests = 1, Window = 2 },
	MaxStringLength = 64,
	Validate = function(_player, product)
		return resolveCatalogId(CommerceConfig.DeveloperProducts, product) ~= nil, "UNKNOWN_PRODUCT"
	end,
})
NetGuard.Define("Commerce.PromptGamePass", {
	RateLimit = { Requests = 1, Window = 2 },
	MaxStringLength = 64,
	Validate = function(_player, gamePass)
		return resolveCatalogId(CommerceConfig.GamePasses, gamePass) ~= nil, "UNKNOWN_GAME_PASS"
	end,
})
NetGuard.Define("Commerce.OwnsGamePass", {
	RateLimit = { Requests = 4, Window = 10 },
	MaxStringLength = 64,
	Validate = function(_player, gamePass)
		return resolveCatalogId(CommerceConfig.GamePasses, gamePass) ~= nil, "UNKNOWN_GAME_PASS"
	end,
})

local function ensureCommerceData(profile)
	local data = profile.Data
	data.Commerce = data.Commerce or {}
	data.Commerce.ProcessedReceipts = data.Commerce.ProcessedReceipts or {}
	data.Commerce.OwnedGamePasses = data.Commerce.OwnedGamePasses or {}
	return data.Commerce
end

--[=[
	Registers the single grant handler for a configured developer product. Grant
	handlers receive `(player, receiptInfo, data)` and must mutate only `data`.

	@param product string | number -- Stable product name or configured asset ID.
	@param handler (player: Player, receiptInfo: table, data: table) -> boolean?
]=]
function CommerceService:RegisterProduct(product, handler)
	assert(type(handler) == "function", "product handler must be a function")
	local productId = resolveCatalogId(CommerceConfig.DeveloperProducts, product)
	assert(productId, `unknown developer product: {tostring(product)}`)
	assert(not self._productHandlers[productId], `developer product {productId} already has a handler`)
	self._productHandlers[productId] = handler
end

function CommerceService:_processReceipt(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if self._processingReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = self._dataService:WaitForProfile(player, CommerceConfig.ReceiptProfileWaitSeconds)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local productName = CommerceConfig.DeveloperProducts[productId]
	local handler = self._productHandlers[productId]
	if not productName or not handler then
		warn(`No receipt handler registered for developer product {productId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self._processingReceipts[purchaseId] = true
	local committed, result = self._dataService:RunCommittedMutation(
		player,
		function(data, commitVersion): (boolean, any)
			local commerce = ensureCommerceData({ Data = data })
			local existing = commerce.ProcessedReceipts[purchaseId]
			if existing then
				existing.CommitVersion = commitVersion
				return true, { NewlyGranted = false }
			end

			local granted = handler(player, receiptInfo, data)
			if granted == false then
				return false, "HANDLER_DEFERRED"
			end
			commerce.ProcessedReceipts[purchaseId] = {
				ProductId = productId,
				ProductName = productName,
				ProcessedAt = os.time(),
				CommitVersion = commitVersion,
			}
			return true, { NewlyGranted = true }
		end,
		CommerceConfig.ReceiptCommitTimeoutSeconds
	)

	if committed and result.NewlyGranted then
		self.PurchaseProcessed:Fire(player, productName, receiptInfo)
		self.Client.PurchaseProcessed:Fire(player, productName)
	elseif not committed then
		warn(`Developer product {productId} was deferred: {tostring(result)}`)
	end
	self._processingReceipts[purchaseId] = nil

	return if committed
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

--[=[
	Prompts a configured developer product.

	@param player Player
	@param product string | number
	@return boolean -- Whether the product resolved and a prompt was requested.
]=]
function CommerceService:PromptProduct(player: Player, product): boolean
	local productId = resolveCatalogId(CommerceConfig.DeveloperProducts, product)
	if not productId then
		return false
	end
	Marketplace.PromptPurchase(productId, Enum.InfoType.Product, player)
	return true
end

--[=[
	Prompts a configured game pass.

	@param player Player
	@param gamePass string | number
	@return boolean -- Whether the game pass resolved and a prompt was requested.
]=]
function CommerceService:PromptGamePass(player: Player, gamePass): boolean
	local gamePassId = resolveCatalogId(CommerceConfig.GamePasses, gamePass)
	if not gamePassId then
		return false
	end
	Marketplace.PromptPurchase(gamePassId, Enum.InfoType.GamePass, player)
	return true
end

--[=[
	Yields while resolving authoritative game-pass ownership.

	@param player Player
	@param gamePass string | number
	@return boolean
	@yields
]=]
function CommerceService:OwnsGamePass(player: Player, gamePass)
	local gamePassId = resolveCatalogId(CommerceConfig.GamePasses, gamePass)
	if not gamePassId then
		return false
	end
	local ok, owns = Marketplace.GetOwnership(player, gamePassId, Enum.InfoType.GamePass):await()
	return ok and owns == true
end

--[=[
	@client
	@within CommerceService
	Guarded remote method that prompts a developer product for the caller.

	@param product string | number
	@return boolean
	@return string? -- NetGuard rejection code.
]=]
function CommerceService.Client:PromptProduct(player: Player, product)
	local allowed, reason = NetGuard.Check(player, "Commerce.PromptProduct", product)
	if not allowed then
		return false, reason
	end
	return self.Server:PromptProduct(player, product)
end

--[=[
	@client
	@within CommerceService
	Guarded remote method that prompts a game pass for the caller.

	@param gamePass string | number
	@return boolean
	@return string? -- NetGuard rejection code.
]=]
function CommerceService.Client:PromptGamePass(player: Player, gamePass)
	local allowed, reason = NetGuard.Check(player, "Commerce.PromptGamePass", gamePass)
	if not allowed then
		return false, reason
	end
	return self.Server:PromptGamePass(player, gamePass)
end

--[=[
	@client
	@within CommerceService
	Guarded remote method that resolves the caller's game-pass ownership.

	@param gamePass string | number
	@return boolean
	@return string? -- NetGuard rejection code.
]=]
function CommerceService.Client:OwnsGamePass(player: Player, gamePass)
	local allowed, reason = NetGuard.Check(player, "Commerce.OwnsGamePass", gamePass)
	if not allowed then
		return false, reason
	end
	return self.Server:OwnsGamePass(player, gamePass)
end

function CommerceService:KnitInit()
	self._dataService = Knit.GetService("PlayerDataService")

	Marketplace.AddPurchaseValidator("CommerceConfig", function(_player, id, infoType)
		if infoType == Enum.InfoType.Product then
			return CommerceConfig.DeveloperProducts[id] ~= nil
		elseif infoType == Enum.InfoType.GamePass then
			return CommerceConfig.GamePasses[id] ~= nil
		elseif infoType == Enum.InfoType.Asset then
			return CommerceConfig.Assets[id] ~= nil
		elseif infoType == Enum.InfoType.Bundle then
			return CommerceConfig.Bundles[id] ~= nil
		elseif infoType == Enum.InfoType.Subscription then
			return CommerceConfig.Subscriptions[id] ~= nil
		end
		return false
	end)

	self._trove:Connect(Marketplace.PromptPurchaseFinished, function(player, id, infoType)
		if infoType ~= Enum.InfoType.GamePass or not CommerceConfig.GamePasses[id] then
			return
		end
		task.spawn(function()
			local committed, reason = self._dataService:RunCommittedMutation(player, function(data)
				local commerce = ensureCommerceData({ Data = data })
				commerce.OwnedGamePasses[tostring(id)] = os.time()
				return true
			end, CommerceConfig.ReceiptCommitTimeoutSeconds)
			if committed then
				self.GamePassPurchased:Fire(player, CommerceConfig.GamePasses[id], id)
				self.Client.GamePassPurchased:Fire(player, CommerceConfig.GamePasses[id], id)
			else
				warn(`Game pass cache commit failed for {id}: {tostring(reason)}`)
			end
		end)
	end)
end

function CommerceService:KnitStart()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end
end

--[=[
	Disconnects service-owned marketplace connections. Intended for test teardown.
]=]
function CommerceService:Destroy()
	self._trove:Clean()
end

return CommerceService
