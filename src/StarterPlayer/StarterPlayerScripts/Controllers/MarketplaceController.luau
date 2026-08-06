--!strict

local MarketplaceService_Rbx = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local player = Players.LocalPlayer :: Player

local MarketplaceController = Knit.CreateController({
	Name = "MarketplaceController",

	DevProductGranted = Signal.new(),
	GiftReceived = Signal.new(),
	GiftSent = Signal.new(),
	GiftFailed = Signal.new(),
})

local marketplaceService: any = nil

type ProductKind = "gamepass" | "product"
type ProductInfo = { [string]: any }
type InfoBucket = { [number]: ProductInfo }

local infoCache: { [ProductKind]: InfoBucket } = {
	gamepass = {} :: InfoBucket,
	product = {} :: InfoBucket,
}
local pendingFetches: { [string]: Signal.Signal<()> } = {}

function MarketplaceController:PromptGamepass(gamepassId: number)
	MarketplaceService_Rbx:PromptGamePassPurchase(player, gamepassId)
end

function MarketplaceController:PromptDevProduct(productId: number)
	MarketplaceService_Rbx:PromptProductPurchase(player, productId)
end

function MarketplaceController:PromptGift(productId: number, recipientUserId: number): (boolean, string?)
	if not marketplaceService then
		return false, "MarketplaceService not ready."
	end
	local ok, productIdOrErr = marketplaceService:RegisterGiftIntent(productId, recipientUserId)
	if not ok then
		return false, tostring(productIdOrErr)
	end
	MarketplaceService_Rbx:PromptProductPurchase(player, productIdOrErr :: number)
	return true, nil
end

function MarketplaceController:CancelGift()
	if marketplaceService then
		marketplaceService:CancelGiftIntent()
	end
end

function MarketplaceController:GetGiftableRecipients(productId: number): { number }?
	if not marketplaceService then
		return nil
	end
	local ok, result = pcall(function()
		return marketplaceService:GetGiftableRecipients(productId)
	end)
	if ok and type(result) == "table" then
		return result
	end
	return nil
end

local function fetchInfo(kind: ProductKind, id: number): ProductInfo?
	local cached = infoCache[kind][id]
	if cached then
		return cached
	end
	local key = `{kind}:{id}`
	local pending = pendingFetches[key]
	if pending then
		pending:Wait()
		return infoCache[kind][id]
	end
	local signal = Signal.new() :: Signal.Signal<()>
	pendingFetches[key] = signal
	local ok, result = pcall(function()
		return MarketplaceService_Rbx:GetProductInfo(
			id,
			if kind == "gamepass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		)
	end)
	if ok and typeof(result) == "table" then
		infoCache[kind][id] = result :: ProductInfo
	end
	pendingFetches[key] = nil
	signal:Fire()
	return infoCache[kind][id]
end

function MarketplaceController:GetGamepassInfo(gamepassId: number): ProductInfo?
	return fetchInfo("gamepass", gamepassId)
end

function MarketplaceController:GetDevProductInfo(productId: number): ProductInfo?
	return fetchInfo("product", productId)
end

function MarketplaceController:GetGamepassPrice(gamepassId: number): number?
	local info = self:GetGamepassInfo(gamepassId)
	return info and info.PriceInRobux
end

function MarketplaceController:GetDevProductPrice(productId: number): number?
	local info = self:GetDevProductInfo(productId)
	return info and info.PriceInRobux
end

function MarketplaceController:KnitStart()
	marketplaceService = Knit.GetService("MarketplaceService")

	marketplaceService.DevProductGranted:Connect(function(productId: number)
		self.DevProductGranted:Fire(productId)
	end)
	marketplaceService.GiftReceived:Connect(function(productId: number, purchaserUserId: number, fromName: string?)
		self.GiftReceived:Fire(productId, purchaserUserId, fromName)
	end)
	marketplaceService.GiftSent:Connect(function(productId: number, recipientUserId: number, wasOffline: boolean?)
		self.GiftSent:Fire(productId, recipientUserId, wasOffline)
	end)
	marketplaceService.GiftFailed:Connect(function(productId: number, recipientUserId: number, reason: string)
		self.GiftFailed:Fire(productId, recipientUserId, reason)
	end)
end

return MarketplaceController
