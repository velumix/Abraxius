--!strict

local AdService = game:GetService("AdService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService_Rbx = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local MapService = require(ServerScriptService.MapBuilderServer.Services.MapService)
local Products = Constants.Products

export type GrantSource = "purchase" | "gift" | "join"
export type GrantContext = {
	source: GrantSource,
	purchaser: Player?,
	recipient: Player?,
	purchaserUserId: number?,
	recipientUserId: number?,
	receiptInfo: { [string]: any }?,
}

export type DevProductHandler = {
	productId: number?,
	label: string?,
	giftable: boolean?,
	grant: (player: Player, ctx: GrantContext) -> Enum.ProductPurchaseDecision?,
	validateGift: ((purchaser: Player, recipient: Player) -> (boolean, string?))?,
	onGiftQueued: ((purchaser: Player, recipientUserId: number) -> ())?,
}

type PendingGift = {
	kind: "product",
	recipientUserId: number,
	productId: number,
	expiresAt: number,
}

type PendingGiftRecord = {
	kind: "product",
	productId: number,
	purchaserUserId: number,
	purchaserName: string?,
	purchasedAt: number,
	purchaseId: string?,
}

local GIFT_INTENT_TTL = 160
local OFFLINE_GIFT_STORE = "MarketplacePendingGifts_v2"
local RESTRICT_ATTR = "PaidRandomRestricted"
local MAX_PRICE_LEVEL_RATIO = 1.25

local devProductHandlers: { [number]: DevProductHandler } = {}
local pendingGifts: { [Player]: PendingGift } = {}
local pendingGiftStore = DataStoreService:GetDataStore(OFFLINE_GIFT_STORE)

local Remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "GameRemotes"
	Remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name: string, className: string)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local GiftReceivedRemote = ensureRemote("GiftReceived", "RemoteEvent") :: RemoteEvent
local GiftDeliveredRemote = ensureRemote("GiftDelivered", "RemoteEvent") :: RemoteEvent
local GiftBroadcastRemote = ensureRemote("GiftBroadcast", "RemoteEvent") :: RemoteEvent
local GiftErrorRemote = ensureRemote("GiftError", "RemoteEvent") :: RemoteEvent
local AdCoinRewardRemote = ensureRemote("AdCoinReward", "RemoteEvent") :: RemoteEvent
local ClaimSixSevenCoinsRemote = ensureRemote("ClaimSixSevenCoins", "RemoteEvent") :: RemoteEvent

local MarketplaceService = Knit.CreateService({
	Name = "MarketplaceService",

	DevProductHandlerFired = Signal.new(),

	Client = {
		DevProductGranted = Knit.CreateSignal(),
		GiftReceived = Knit.CreateSignal(),
		GiftSent = Knit.CreateSignal(),
		GiftFailed = Knit.CreateSignal(),
	},
})

local DataService
local CoinService
local StarterPackService
local LimitedStockManager
local KnifeSkinManager
local PolicyManager
local LimitedBundleService
local MapManager
local MapCatalog
local TrollConfig
local UnboxManager
local KillEffectCrateManager
local MatchGameplayAction

local function dataService()
	if not DataService then
		DataService = Knit.GetService("DataService")
	end
	return DataService
end

local function coinService()
	if not CoinService then
		CoinService = Knit.GetService("CoinService")
	end
	return CoinService
end

local function starterPackService()
	if not StarterPackService then
		StarterPackService = Knit.GetService("StarterPackService")
	end
	return StarterPackService
end

local function limitedStockManager()
	if not LimitedStockManager then
		LimitedStockManager = require(ServerScriptService:WaitForChild("LimitedStockManager"))
	end
	return LimitedStockManager
end

local function knifeSkinManager()
	if not KnifeSkinManager then
		KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
	end
	return KnifeSkinManager
end

local function policyManager()
	if not PolicyManager then
		local ok, result = pcall(function()
			return require(ServerScriptService:WaitForChild("PolicyManager"))
		end)
		if ok then
			PolicyManager = result
		end
	end
	return PolicyManager
end

local function limitedBundleService()
	if not LimitedBundleService then
		LimitedBundleService = require(ServerScriptService:WaitForChild("LimitedBundleService"))
	end
	return LimitedBundleService
end

local function mapManager()
	if not MapManager then
		MapManager = require(ServerScriptService:WaitForChild("MapManager"))
	end
	return MapManager
end

local function mapCatalog()
	if not MapCatalog then
		MapCatalog = require(ReplicatedStorage:WaitForChild("MapCatalog"))
	end
	return MapCatalog
end

local function trollConfig()
	if not TrollConfig then
		TrollConfig = require(ReplicatedStorage:WaitForChild("TrollConfig"))
	end
	return TrollConfig
end

local function unboxManager()
	if not UnboxManager then
		UnboxManager = require(ServerScriptService:WaitForChild("UnboxManager"))
	end
	return UnboxManager
end

local function killEffectCrateManager()
	if not KillEffectCrateManager then
		KillEffectCrateManager = require(ServerScriptService:WaitForChild("KillEffectCrateManager"))
	end
	return KillEffectCrateManager
end

local function matchGameplayAction()
	if not MatchGameplayAction then
		MatchGameplayAction = ServerScriptService:WaitForChild("MatchGameplayAction")
	end
	return MatchGameplayAction
end

local function isPlayerInGame(userId: number): Player?
	for _, plr in Players:GetPlayers() do
		if plr.UserId == userId then
			return plr
		end
	end
	return nil
end

local function displayName(player: Player?): string
	if not player then
		return "Someone"
	end
	return if player.DisplayName ~= "" then player.DisplayName else player.Name
end

local function waitUntilDataReady(player: Player, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players do
		local ok, loaded = pcall(function()
			return dataService():IsLoaded(player)
		end)
		if ok and loaded then
			return true
		end
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.1)
	end
	return false
end

local function isPaidRandomRestricted(player: Player): boolean
	local manager = policyManager()
	if manager and manager.isPaidRandomRestricted then
		local ok, result = pcall(manager.isPaidRandomRestricted, player)
		if ok then
			return result == true
		end
	end
	local attr = player:GetAttribute(RESTRICT_ATTR)
	if attr ~= nil then
		return attr == true
	end
	local ok, policyInfo = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	return (not ok) or policyInfo == nil or policyInfo.ArePaidRandomItemsRestricted == true
end

local function validatePaidRandomGift(_purchaser: Player, recipient: Player): (boolean, string?)
	if isPaidRandomRestricted(recipient) then
		return false, "This player can't receive gifts."
	end
	return true, nil
end

local function passesRegionCheck(buyerUserId: number, recipientUserId: number): boolean
	local ok, levels = pcall(function()
		return MarketplaceService_Rbx:GetUsersPriceLevelsAsync({ buyerUserId, recipientUserId })
	end)
	if not ok or type(levels) ~= "table" then
		return true
	end
	local lookup = {}
	for _, info in ipairs(levels) do
		lookup[info.UserId] = info.PriceLevel
	end
	local buyerLevel = lookup[buyerUserId]
	local recipientLevel = lookup[recipientUserId]
	if not buyerLevel or not recipientLevel or buyerLevel <= 0 then
		return true
	end
	return recipientLevel <= buyerLevel * MAX_PRICE_LEVEL_RATIO
end

local function playerOwnsSkin(player: Player, skinId: string): boolean
	local weapons = dataService():GetWeapons(player) or {}
	for _, item in ipairs(weapons) do
		if item.skinId == skinId then
			return true
		end
	end
	return false
end

local function fireCoinPopup(player: Player, amount: number)
	local remote = Remotes:FindFirstChild("CoinCollected")
	if not remote or not remote:IsA("RemoteEvent") then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position
	if pos then
		remote:FireClient(player, pos, amount)
	end
end

local function markReceipt(player: Player, purchaseId: string?)
	if purchaseId then
		dataService():MarkGrantedReceipt(player, purchaseId)
	end
end

local function alreadyGranted(player: Player, purchaseId: string?): boolean
	return purchaseId ~= nil and dataService():HasGrantedReceipt(player, purchaseId) == true
end

-- Central durable boundary shared by every developer-product grant path.
local function commitReceipt(
	player: Player,
	receiptInfo: { [string]: any }?,
	productId: number,
	ctx: GrantContext?,
	recipientUserId: number?,
	fallbackState: string?
): boolean
	if not receiptInfo then
		return false
	end
	local purchaseId = receiptInfo.PurchaseId
	if type(purchaseId) ~= "string" or purchaseId == "" then
		return false
	end
	local purchaserUserId = (ctx and ctx.purchaserUserId) or receiptInfo.PlayerId or player.UserId
	local intendedRecipientUserId = recipientUserId or (ctx and ctx.recipientUserId) or player.UserId
	local record = dataService():RecordReceipt(player, purchaseId, {
		ProductId = productId,
		PurchaserUserId = purchaserUserId,
		RecipientUserId = intendedRecipientUserId,
		Source = (ctx and ctx.source) or "purchase",
		GrantState = "granted",
		FallbackState = fallbackState or "none",
	})
	return record ~= nil and dataService():CommitReceipt(player, purchaseId, 30) == true
end

local function notifyGiftReceived(player: Player, productId: number, purchaserUserId: number?, fromName: string?)
	local handler = devProductHandlers[productId]
	local label = (handler and handler.label) or "a gift"
	GiftReceivedRemote:FireClient(player, { fromName = fromName or "Someone", label = label })
	MarketplaceService.Client.GiftReceived:Fire(player, productId, purchaserUserId or 0, fromName)
end

local function notifyGiftSent(purchaser: Player, productId: number, recipientUserId: number, wasOffline: boolean?)
	local handler = devProductHandlers[productId]
	local label = (handler and handler.label) or "a gift"
	local recipient = Players:GetPlayerByUserId(recipientUserId)
	GiftDeliveredRemote:FireClient(purchaser, {
		recipientName = recipient and displayName(recipient) or "your friend",
		label = label,
		queued = wasOffline == true,
	})
	if recipient then
		GiftBroadcastRemote:FireAllClients({
			fromName = displayName(purchaser),
			recipientName = displayName(recipient),
			label = label,
		})
	end
	MarketplaceService.Client.GiftSent:Fire(purchaser, productId, recipientUserId, wasOffline == true)
end

local function notifyGiftFailed(purchaser: Player, productId: number, recipientUserId: number, reason: string)
	GiftErrorRemote:FireClient(purchaser, { reason = reason })
	MarketplaceService.Client.GiftFailed:Fire(purchaser, productId, recipientUserId, reason)
end

function MarketplaceService:RegisterDevProduct(productId: number, handler: DevProductHandler)
	assert(typeof(productId) == "number", "productId must be number")
	assert(typeof(handler) == "table" and typeof(handler.grant) == "function", "handler must be { grant = fn }")
	devProductHandlers[productId] = handler
end

function MarketplaceService:PromptDevProduct(player: Player, productId: number)
	MarketplaceService_Rbx:PromptProductPurchase(player, productId)
end

function MarketplaceService.Client:RegisterGiftIntent(
	player: Player,
	productId: number,
	recipientUserId: number
): (boolean, (number | string)?)
	if typeof(productId) ~= "number" or typeof(recipientUserId) ~= "number" then
		return false, "Invalid request."
	end
	if recipientUserId == player.UserId then
		return false, "You can't gift yourself."
	end
	local handler = devProductHandlers[productId]
	if not handler or not handler.giftable then
		return false, "This item can't be gifted."
	end
	local recipient = isPlayerInGame(recipientUserId)
	if not recipient then
		return false, "That player isn't in the server."
	end
	if not passesRegionCheck(player.UserId, recipientUserId) then
		return false, "Gifting to this player's region isn't allowed."
	end
	if handler.validateGift then
		local ok, err = handler.validateGift(player, recipient)
		if not ok then
			return false, err or "This gift is not allowed."
		end
	end
	pendingGifts[player] = {
		kind = "product",
		recipientUserId = recipientUserId,
		productId = productId,
		expiresAt = workspace:GetServerTimeNow() + GIFT_INTENT_TTL,
	}
	return true, productId
end

function MarketplaceService.Client:CancelGiftIntent(player: Player)
	pendingGifts[player] = nil
end

function MarketplaceService.Client:GetGiftableRecipients(player: Player, productId: number): { number }
	local allowed = {}
	if typeof(productId) ~= "number" then
		return allowed
	end
	local handler = devProductHandlers[productId]
	if not handler or not handler.giftable then
		return allowed
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok = true
			if handler.validateGift then
				local success, passed = pcall(handler.validateGift, player, other)
				ok = success and passed == true
			end
			if ok then
				table.insert(allowed, other.UserId)
			end
		end
	end
	return allowed
end

local function queueOfflineGift(recipientUserId: number, record: PendingGiftRecord): boolean
	local key = tostring(recipientUserId)
	local ok, err = pcall(function()
		pendingGiftStore:UpdateAsync(key, function(existing: { PendingGiftRecord }?)
			existing = existing or {}
			if record.purchaseId then
				for _, queued in ipairs(existing :: { PendingGiftRecord }) do
					if queued.purchaseId == record.purchaseId then
						return existing
					end
				end
			end
			table.insert(existing :: { PendingGiftRecord }, record)
			return existing
		end)
	end)
	if not ok then
		warn(`[MarketplaceService] failed to queue offline gift for {recipientUserId}: {err}`)
	end
	return ok
end

local function runDevProductGrant(
	handler: DevProductHandler,
	player: Player,
	ctx: GrantContext,
	productId: number
): Enum.ProductPurchaseDecision
	local ok, result = pcall(handler.grant, player, ctx)
	if not ok then
		warn(`[MarketplaceService] devproduct {productId} grant error: {result}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if result ~= nil and result ~= Enum.ProductPurchaseDecision.PurchaseGranted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if ctx.receiptInfo and not commitReceipt(player, ctx.receiptInfo, productId, ctx) then
		warn(`[MarketplaceService] devproduct {productId} receipt commit did not persist`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	MarketplaceService.DevProductHandlerFired:Fire(player, productId, ctx)
	MarketplaceService.Client.DevProductGranted:Fire(player, productId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function drainOfflineGifts(player: Player)
	if not waitUntilDataReady(player, 30) then
		return
	end
	local key = tostring(player.UserId)
	local captured: { PendingGiftRecord } = {}
	local ok, err = pcall(function()
		pendingGiftStore:UpdateAsync(key, function(existing: { PendingGiftRecord }?)
			if existing then
				for _, record in ipairs(existing) do
					table.insert(captured, record)
				end
			end
			return nil
		end)
	end)
	if not ok then
		warn(`[MarketplaceService] failed to drain offline gifts for {player.UserId}: {err}`)
		return
	end
	local remaining: { PendingGiftRecord } = {}
	for _, record in captured do
		local handler = devProductHandlers[record.productId]
		if not handler then
			warn(`[MarketplaceService] offline gift for unregistered devproduct {record.productId}`)
			continue
		end
		local decision = runDevProductGrant(handler, player, {
			source = "gift",
			purchaserUserId = record.purchaserUserId,
			recipient = player,
			recipientUserId = player.UserId,
			receiptInfo = {
				PurchaseId = record.purchaseId,
				ProductId = record.productId,
				PlayerId = record.purchaserUserId,
			},
		}, record.productId)
		if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			notifyGiftReceived(player, record.productId, record.purchaserUserId, record.purchaserName)
		else
			table.insert(remaining, record)
		end
	end
	if #remaining > 0 then
		for _, record in ipairs(remaining) do
			queueOfflineGift(player.UserId, record)
		end
	end
end

local function onProductPurchase(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaser = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not purchaser then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local productId = receiptInfo.ProductId :: number
	local intent = pendingGifts[purchaser]
	if intent and intent.productId == productId and workspace:GetServerTimeNow() <= intent.expiresAt then
		local handler = devProductHandlers[productId]
		if handler then
			local recipient = isPlayerInGame(intent.recipientUserId)
			if recipient then
				if not waitUntilDataReady(recipient, 30) then
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local decision = runDevProductGrant(handler, recipient, {
					source = "gift",
					purchaser = purchaser,
					recipient = recipient,
					purchaserUserId = purchaser.UserId,
					recipientUserId = recipient.UserId,
					receiptInfo = receiptInfo,
				}, productId)
				if decision ~= Enum.ProductPurchaseDecision.PurchaseGranted then
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				pendingGifts[purchaser] = nil
				notifyGiftSent(purchaser, productId, recipient.UserId, false)
				notifyGiftReceived(recipient, productId, purchaser.UserId, displayName(purchaser))
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end

			if
				not queueOfflineGift(intent.recipientUserId, {
					kind = "product",
					productId = productId,
					purchaserUserId = purchaser.UserId,
					purchaserName = displayName(purchaser),
					purchasedAt = workspace:GetServerTimeNow(),
					purchaseId = receiptInfo.PurchaseId,
				})
			then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local queuedContext: GrantContext = {
				source = "gift",
				purchaser = purchaser,
				purchaserUserId = purchaser.UserId,
				recipientUserId = intent.recipientUserId,
				receiptInfo = receiptInfo,
			}
			if
				not commitReceipt(
					purchaser,
					receiptInfo,
					productId,
					queuedContext,
					intent.recipientUserId,
					"offline_gift_queued"
				)
			then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			pendingGifts[purchaser] = nil
			if handler.onGiftQueued then
				pcall(handler.onGiftQueued, purchaser, intent.recipientUserId)
			end
			notifyGiftSent(purchaser, productId, intent.recipientUserId, true)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local handler = devProductHandlers[productId]
	if handler then
		if not waitUntilDataReady(purchaser, 30) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return runDevProductGrant(handler, purchaser, {
			source = "purchase",
			purchaser = purchaser,
			purchaserUserId = purchaser.UserId,
			receiptInfo = receiptInfo,
		}, productId)
	end

	local decision = MarketplaceService:_ProcessAncillaryProduct(receiptInfo)
	if decision then
		return decision
	end

	warn(`[MarketplaceService] unhandled devproduct {productId}`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onProductPurchaseFinished(userId: number, productId: number, wasPurchased: boolean)
	if wasPurchased then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	local intent = pendingGifts[player]
	if intent and intent.productId == productId then
		pendingGifts[player] = nil
		notifyGiftFailed(player, productId, intent.recipientUserId, "Gift cancelled.")
	end
end

local SEEKER_GAMEPASS_ID = Constants.Gamepasses.SEEKER
local SEEKER_BOOST_ATTR = "OwnsSeekerGamepass"

local function refreshSeekerGamepass(player: Player)
	local ok, owns = pcall(function()
		return MarketplaceService_Rbx:UserOwnsGamePassAsync(player.UserId, SEEKER_GAMEPASS_ID)
	end)
	if ok then
		player:SetAttribute(SEEKER_BOOST_ATTR, owns == true)
	else
		warn("[MarketplaceService] seeker gamepass check failed for " .. player.Name .. ": " .. tostring(owns))
		player:SetAttribute(SEEKER_BOOST_ATTR, false)
	end
end

local PRODUCT = {
	Coins500 = Products.Coins500,
	Coins1K = Products.Coins1K,
	Coins5K = Products.Coins5K,
	Coins10K = Products.Coins10K,
	StarterPack = 3606548877,
	LimitedTimePack = Constants.LimitedTimePack.Product,
	VoidBlade = 3605583585,
	FrozenKnife = Products.FrozenKnife,
	VampireScythe = 3604856682,
	GuaranteedSeeker = 3601754778,
	RevealAll = 3604590604,
	RevealOne = 3604589435,
	SizeTiny = 3605258594,
	SizeGiant = 3605258716,
	SixSevenCoins = 3605271422,
}

local REVIVE_TIER_OF = {
	[3605235518] = 1,
	[3605238864] = 2,
	[3605239104] = 3,
	[3605239189] = 4,
}

local CRATE_PRODUCTS = {
	[Products.WoodenCrate] = { crateName = "Wooden Crate", amount = 1 },
	[Products.SilverCrate] = { crateName = "Silver Crate", amount = 1 },
	[Products.GoldenCrate] = { crateName = "Golden Crate", amount = 1 },
	[Products.BrainrotCrate] = { crateName = "Brainrot Crate", amount = 1 },
	[Products.KawaiiKitchenCrate] = { crateName = "Kawaii Kitchen Crate", amount = 1 },
	[Products.BackroomsCrate] = { crateName = "Backrooms Crate", amount = 1 },
	-- Elemental Crate: three fixed Robux products that open the same crate 1 / 3 / 10 times
	-- (the grant loop below clamps amount to 1..10 and calls openCrate that many times).
	[Products.ElementalCrateX1] = { crateName = "Elemental Crate", amount = 1 },
	[Products.ElementalCrateX3] = { crateName = "Elemental Crate", amount = 3 },
	[Products.ElementalCrateX10] = { crateName = "Elemental Crate", amount = 10 },
}

local KE_CRATE_PRODUCTS = {
	[Products.NoviceCrate] = "Novice Crate",
	[Products.EmotionalCrate] = "Emotional Crate",
}

local function runMatchAction(action: string, player: Player, payload: any?): boolean
	local ok, result = pcall(function()
		return (matchGameplayAction() :: BindableFunction):Invoke(action, player, payload)
	end)
	if not ok then
		warn("[MarketplaceService] match action failed: " .. tostring(result))
		return false
	end
	return result == true
end

local function registerBuiltInProducts()
	local coinAmounts = {
		[PRODUCT.Coins500] = 500,
		[PRODUCT.Coins1K] = 1000,
		[PRODUCT.Coins5K] = 5000,
		[PRODUCT.Coins10K] = 10000,
	}
	for productId, amount in pairs(coinAmounts) do
		MarketplaceService:RegisterDevProduct(productId, {
			label = tostring(amount) .. " Coins",
			giftable = true,
			validateGift = validatePaidRandomGift,
			grant = function(player: Player, ctx: GrantContext)
				if ctx.source == "purchase" and isPaidRandomRestricted(player) then
					warn("[MarketplaceService] blocked restricted coin purchase for " .. player.Name)
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
				if alreadyGranted(player, purchaseId) then
					return nil
				end
				coinService():Credit(
					player,
					amount,
					(ctx.source == "gift" and "gifted " or "purchased ") .. amount .. " coins"
				)
				fireCoinPopup(player, amount)
				markReceipt(player, purchaseId)
				return nil
			end,
		})
	end

	local fireworkPacks = {
		[3607832624] = { label = "Small Firework Pack", amount = 250 },
		[3607832643] = { label = "Medium Firework Pack", amount = 900 },
		[3607832659] = { label = "Large Firework Pack", amount = 3000 },
	}
	for productId, pack in pairs(fireworkPacks) do
		MarketplaceService:RegisterDevProduct(productId, {
			label = pack.amount .. " Coins",
			giftable = true,
			grant = function(player: Player, ctx: GrantContext)
				local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
				if alreadyGranted(player, purchaseId) then
					return nil
				end
				coinService():Credit(
					player,
					pack.amount,
					(ctx.source == "gift" and "gifted " or "purchased ") .. pack.label .. " converted to coins"
				)
				fireCoinPopup(player, pack.amount)
				markReceipt(player, purchaseId)
				return nil
			end,
		})
	end

	local fireworkSpinProducts = {
		[3607832684] = { label = "1 Crate Spin", amount = 1 },
		[3607832705] = { label = "3 Crate Spins", amount = 3 },
	}
	for productId, spinPack in pairs(fireworkSpinProducts) do
		MarketplaceService:RegisterDevProduct(productId, {
			label = tostring(spinPack.amount * 75) .. " Coins",
			giftable = true,
			validateGift = validatePaidRandomGift,
			grant = function(player: Player, ctx: GrantContext)
				if ctx.source == "purchase" and isPaidRandomRestricted(player) then
					warn("[MarketplaceService] blocked restricted firework crate spin purchase for " .. player.Name)
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
				if alreadyGranted(player, purchaseId) then
					return nil
				end
				local coinAmount = spinPack.amount * 75
				coinService():Credit(
					player,
					coinAmount,
					(ctx.source == "gift" and "gifted " or "purchased ") .. spinPack.label .. " converted to coins"
				)
				fireCoinPopup(player, coinAmount)
				markReceipt(player, purchaseId)
				return nil
			end,
		})
	end

	MarketplaceService:RegisterDevProduct(PRODUCT.StarterPack, {
		label = "Starter Pack",
		giftable = true,
		validateGift = validatePaidRandomGift,
		grant = function(player: Player, ctx: GrantContext)
			local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
			if alreadyGranted(player, purchaseId) then
				if ctx.source == "purchase" then
					starterPackService().Client.Purchased:Fire(player)
				end
				return nil
			end
			if ctx.source == "purchase" then
				local status = dataService():GetStarterPackStatus(player)
				if status and status.state ~= "purchased" then
					dataService():AddWeapon(player, "darkrose", "none")
					dataService():GrantPose(player, "ononeknee", false)
					coinService():CreditFromPack(player, 500, "starter pack")
					fireCoinPopup(player, 500)
					dataService():MarkStarterPackPurchased(player)
				end
				starterPackService().Client.Purchased:Fire(player)
			else
				dataService():AddWeapon(player, "darkrose", "none")
				dataService():GrantPose(player, "ononeknee", false)
				coinService():CreditFromPack(player, 500, "gifted starter pack")
				fireCoinPopup(player, 500)
			end
			markReceipt(player, purchaseId)
			return nil
		end,
	})

	MarketplaceService:RegisterDevProduct(PRODUCT.LimitedTimePack, {
		label = "Limited Time Pack",
		giftable = true,
		validateGift = validatePaidRandomGift,
		grant = function(player: Player, ctx: GrantContext)
			local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
			if alreadyGranted(player, purchaseId) then
				return nil
			end
			local deadline = Remotes:FindFirstChild("LimitedOfferDeadline")
			if deadline and deadline:IsA("NumberValue") and deadline.Value > 0 and os.time() >= deadline.Value then
				warn("[LimitedTimePack] offer expired; refusing purchase for " .. player.Name)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			dataService():AddWeapon(player, Constants.LimitedTimePack.Knife, knifeSkinManager().rollGuaranteedEffect())
			coinService():CreditFromPack(
				player,
				Constants.LimitedTimePack.Coins,
				(ctx.source == "gift" and "gifted " or "") .. "limited time pack"
			)
			fireCoinPopup(player, Constants.LimitedTimePack.Coins)
			markReceipt(player, purchaseId)
			return nil
		end,
	})

	MarketplaceService:RegisterDevProduct(PRODUCT.VoidBlade, {
		label = "Void Blade",
		giftable = true,
		grant = function(player: Player, ctx: GrantContext)
			local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
			if alreadyGranted(player, purchaseId) then
				return nil
			end
			dataService():AddWeapon(player, "voidblade", "none")
			markReceipt(player, purchaseId)
			return nil
		end,
	})

	MarketplaceService:RegisterDevProduct(PRODUCT.VampireScythe, {
		label = "Vampire Scythe",
		giftable = true,
		grant = function(player: Player, ctx: GrantContext)
			local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
			if alreadyGranted(player, purchaseId) then
				return nil
			end
			if not limitedStockManager().tryConsumeStock() then
				warn("[VampireScythe] SOLD OUT; refusing purchase for " .. player.Name)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			dataService():AddWeapon(player, "vampirescythe", "none")
			markReceipt(player, purchaseId)
			return nil
		end,
	})

	MarketplaceService:RegisterDevProduct(PRODUCT.FrozenKnife, {
		label = "Frozen Knife",
		giftable = true,
		validateGift = function(_purchaser: Player, recipient: Player): (boolean, string?)
			if isPaidRandomRestricted(recipient) then
				return false, "This player can't receive gifts."
			end
			if playerOwnsSkin(recipient, "frozen") then
				return false, "That player already owns Frozen Knife."
			end
			return true, nil
		end,
		grant = function(player: Player, ctx: GrantContext)
			local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
			if alreadyGranted(player, purchaseId) then
				return nil
			end
			if playerOwnsSkin(player, "frozen") then
				markReceipt(player, purchaseId)
				return nil
			end
			local deadline = Remotes:FindFirstChild("FrozenKnifeDeadline")
			if deadline and deadline:IsA("IntValue") and deadline.Value > 0 and os.time() >= deadline.Value then
				warn("[FrozenKnife] offer expired; refusing purchase for " .. player.Name)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if not limitedStockManager().tryConsumeFrozenKnifeStock() then
				warn("[FrozenKnife] SOLD OUT; refusing purchase for " .. player.Name)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			dataService():AddWeapon(player, "frozen", knifeSkinManager().rollGuaranteedEffect())
			coinService():CreditFromPack(player, 3000, "frozen knife")
			markReceipt(player, purchaseId)
			return nil
		end,
	})

	MarketplaceService:RegisterDevProduct(PRODUCT.GuaranteedSeeker, {
		grant = function(player: Player)
			return if runMatchAction("QueueSeeker", player) then nil else Enum.ProductPurchaseDecision.NotProcessedYet
		end,
	})

	for productId, tier in pairs(REVIVE_TIER_OF) do
		MarketplaceService:RegisterDevProduct(productId, {
			grant = function(player: Player)
				return if runMatchAction("ReviveTier", player, { tier = tier })
					then nil
					else Enum.ProductPurchaseDecision.NotProcessedYet
			end,
		})
	end

	MarketplaceService:RegisterDevProduct(PRODUCT.RevealAll, {
		grant = function(player: Player)
			return if runMatchAction("RevealHiders", player, { mode = "all" })
				then nil
				else Enum.ProductPurchaseDecision.NotProcessedYet
		end,
	})
	MarketplaceService:RegisterDevProduct(PRODUCT.RevealOne, {
		grant = function(player: Player)
			return if runMatchAction("RevealHiders", player, { mode = "one" })
				then nil
				else Enum.ProductPurchaseDecision.NotProcessedYet
		end,
	})

	MarketplaceService:RegisterDevProduct(PRODUCT.SizeTiny, {
		grant = function(player: Player)
			return if runMatchAction("ApplyHiderSize", player, { sizeKey = "tiny" })
				then nil
				else Enum.ProductPurchaseDecision.NotProcessedYet
		end,
	})
	MarketplaceService:RegisterDevProduct(PRODUCT.SizeGiant, {
		grant = function(player: Player)
			return if runMatchAction("ApplyHiderSize", player, { sizeKey = "giant" })
				then nil
				else Enum.ProductPurchaseDecision.NotProcessedYet
		end,
	})

	for productId, trollInfo in pairs(trollConfig().ByProduct) do
		MarketplaceService:RegisterDevProduct(productId, {
			grant = function(player: Player)
				return if runMatchAction("ApplyTroll", player, trollInfo)
					then nil
					else Enum.ProductPurchaseDecision.NotProcessedYet
			end,
		})
	end

	for productId, crateName in pairs(KE_CRATE_PRODUCTS) do
		MarketplaceService:RegisterDevProduct(productId, {
			label = crateName,
			grant = function(player: Player, ctx: GrantContext)
				if ctx.source == "purchase" and isPaidRandomRestricted(player) then
					warn("[MarketplaceService] blocked restricted kill effect crate purchase for " .. player.Name)
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local purchaseId = ctx.receiptInfo and ctx.receiptInfo.PurchaseId
				if alreadyGranted(player, purchaseId) then
					return nil
				end
				if not killEffectCrateManager().openCrate(player, crateName) then
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				markReceipt(player, purchaseId)
				return nil
			end,
		})
	end
end

function MarketplaceService:_ProcessAncillaryProduct(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision?
	local bundleOk, bundleDecision = pcall(function()
		return limitedBundleService().ProcessReceipt(receiptInfo)
	end)
	if not bundleOk then
		warn("[MarketplaceService] bundle receipt handler failed: " .. tostring(bundleDecision))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if bundleDecision then
		return bundleDecision
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if dataService():HasGrantedReceipt(player, receiptInfo.PurchaseId) then
		return if commitReceipt(player, receiptInfo, receiptInfo.ProductId, nil)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if receiptInfo.ProductId == Constants.QUEUE_CUSTOM_MAP_PRODUCT then
		local mapInfo = MapService:GetPurchasingQueuedMap(player)
		if mapInfo then
			MapService:RecordLoad(mapInfo)
			mapManager().queueForcedMap(mapInfo.Name, player.DisplayName or player.Name, player, mapInfo)
		end
		return if commitReceipt(
				player,
				receiptInfo,
				receiptInfo.ProductId,
				nil,
				player.UserId,
				if mapInfo then "none" else "custom_map_context_missing"
			)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local mapEntry = mapCatalog().getByProduct(receiptInfo.ProductId)
	if mapEntry then
		mapManager().queueForcedMap(mapEntry.name, displayName(player), player.UserId)
		local chooseMapConfirm = Remotes:FindFirstChild("ChooseMapConfirm")
		if chooseMapConfirm and chooseMapConfirm:IsA("RemoteEvent") then
			chooseMapConfirm:FireClient(player, mapEntry.name)
		end
		local globalMapChoice = Remotes:FindFirstChild("GlobalMapChoice")
		if globalMapChoice and globalMapChoice:IsA("RemoteEvent") then
			globalMapChoice:FireAllClients({ playerName = displayName(player), mapName = mapEntry.name })
		end
		return if commitReceipt(player, receiptInfo, receiptInfo.ProductId, nil)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local crateGrant = CRATE_PRODUCTS[receiptInfo.ProductId]
	-- Rotating weekly "RobuxCase": the lobby model keeps the fixed name "RobuxCase" and carries the
	-- current week's crate + product ids as attributes (CrateName, ProductId1 = x1, ProductId3 = x3, ProductId10 = x10),
	-- so swapping the crate weekly needs no code change here. Map its product ids -> (crate, amount).
	if not crateGrant then
		local robuxCase = workspace:FindFirstChild("LobbyInteractives")
			and workspace.LobbyInteractives:FindFirstChild("RobuxCase")
		if robuxCase then
			local rcName = robuxCase:GetAttribute("CrateName")
			if type(rcName) == "string" then
				local pid1 = robuxCase:GetAttribute("ProductId1")
				local pid3 = robuxCase:GetAttribute("ProductId3")
				local pid10 = robuxCase:GetAttribute("ProductId10")
				if type(pid1) == "number" and receiptInfo.ProductId == pid1 then
					crateGrant = { crateName = rcName, amount = 1 }
				elseif type(pid3) == "number" and receiptInfo.ProductId == pid3 then
					crateGrant = { crateName = rcName, amount = 3 }
				elseif type(pid10) == "number" and receiptInfo.ProductId == pid10 then
					crateGrant = { crateName = rcName, amount = 10 }
				end
			end
		end
	end
	if crateGrant then
		local crateName = crateGrant.crateName
		if knifeSkinManager().isCrateExpired(crateName) then
			warn("[MarketplaceService] blocked expired crate purchase: " .. crateName)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if isPaidRandomRestricted(player) then
			warn("[MarketplaceService] blocked restricted crate purchase for " .. player.Name)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local purchaseId = receiptInfo.PurchaseId
		local ok, openedOrErr = pcall(function()
			dataService():WaitForData(player)
			if dataService():HasGrantedReceipt(player, purchaseId) then
				if not commitReceipt(player, receiptInfo, receiptInfo.ProductId, nil) then
					error("Receipt commit did not persist")
				end
				return 1
			end
			local amount = math.clamp(crateGrant.amount or 1, 1, 10)
			local opened = 0
			for _ = 1, amount do
				if unboxManager().openCrate(player, crateName) then
					opened += 1
				end
			end
			if opened < amount then
				error("Only opened " .. opened .. "/" .. amount .. " crates")
			end
			markReceipt(player, purchaseId)
			if not commitReceipt(player, receiptInfo, receiptInfo.ProductId, nil) then
				error("Receipt commit did not persist")
			end
			return opened
		end)
		if ok and openedOrErr > 0 then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		warn("[MarketplaceService] crate purchase grant failed for " .. player.Name .. ": " .. tostring(openedOrErr))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if receiptInfo.ProductId == PRODUCT.SixSevenCoins then
		coinService():Credit(player, 67, "watch ad")
		AdCoinRewardRemote:FireClient(player, 67)
		return if commitReceipt(player, receiptInfo, receiptInfo.ProductId, nil)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return nil
end

function MarketplaceService:KnitInit()
	registerBuiltInProducts()
end

function MarketplaceService:KnitStart()
	pcall(function()
		limitedBundleService().Start()
	end)

	MarketplaceService_Rbx.ProcessReceipt = onProductPurchase
	MarketplaceService_Rbx.PromptProductPurchaseFinished:Connect(onProductPurchaseFinished)
	MarketplaceService_Rbx.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamepassId: number, wasPurchased: boolean)
			if wasPurchased and gamepassId == SEEKER_GAMEPASS_ID then
				player:SetAttribute(SEEKER_BOOST_ATTR, true)
			end
		end
	)

	ClaimSixSevenCoinsRemote.OnServerEvent:Connect(function(player: Player)
		local success, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(PRODUCT.SixSevenCoins)
			return AdService:ShowRewardedVideoAdAsync(player, reward)
		end)
		if not success then
			warn("[MarketplaceService] rewarded ad prompt failed: " .. tostring(result))
		end
	end)

	local function onPlayerAdded(player: Player)
		task.spawn(refreshSeekerGamepass, player)
		task.spawn(drainOfflineGifts, player)
	end
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		pendingGifts[player] = nil
	end)
end

return MarketplaceService
