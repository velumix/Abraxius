local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ServerModules = ServerScriptService:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local Marketplace = require(Modules.Marketplace)
local RobloxApiService = require(ServerModules.RobloxApiService)
local PlayerDataManager = Mince:Get("PlayerDataManager")

local MAX_LISTINGS = 25
local CACHE_TTL = 60
local OWNERSHIP_CACHE_TTL = 15
local LISTING_REQUEST_LIMIT = 4
local LISTING_REQUEST_WINDOW = 10
local PROMPT_RATE_LIMIT = 2
local PROMPT_RATE_WINDOW = 6
local PRODUCT_TYPES = {
	Transfer = "RobuxTransfer",
	GamePass = "GamePass",
	Asset = "Asset",
}
local TRANSFER_AMOUNTS = { 10, 25, 50, 100, 250, 500 }

local function copyTable(source)
	local clone = {}
	if type(source) ~= "table" then
		return clone
	end
	for k, v in pairs(source) do
		clone[k] = v
	end
	return clone
end

local function cloneRecentEntries(entries)
	local clone = {}
	if type(entries) ~= "table" then
		return clone
	end
	for index, entry in ipairs(entries) do
		if type(entry) == "table" then
			clone[index] = {
				donorUserId = entry.donorUserId,
				donorName = entry.donorName,
				amount = entry.amount,
				listingId = entry.listingId,
				listingName = entry.listingName,
				transferRequestId = entry.transferRequestId,
				timestamp = entry.timestamp,
			}
		end
	end
	return clone
end

local function defaultLedgerState()
	return {
		total = 0,
		donors = {},
		recent = {},
	}
end

local function defaultVisibilityState()
	return {
		hidden = {},
		version = 0,
		updatedAt = os.clock(),
	}
end

local TipjarService = {
	Name = "TipjarService",
	Tipjar = Mince.Component({ Tag = "Tipjar" }),
	PassCache = {},
	GamepassInfoCache = {},
	OwnershipCache = {},
	AssetInfoCache = {},
	AssetOwnershipCache = {},
	PendingPrompts = {},
	PendingTransfers = {},
	ProcessedTransfers = {},
	DonationLedger = {},
	ActiveTipjars = {},
	RateLimits = {},
	ListingVisibility = {},
	CustomListings = {},
}

function TipjarService:GetLedger(userId)
	local ledger = self.DonationLedger[userId]
	if not ledger then
		ledger = defaultLedgerState()
		self.DonationLedger[userId] = ledger
	end
	return ledger
end

function TipjarService:GetVisibility(userId)
	local record = self.ListingVisibility[userId]
	if not record then
		record = defaultVisibilityState()
		self.ListingVisibility[userId] = record
	end
	return record
end

function TipjarService:EnsureProfileEntry(profile)
	profile.Data.Tipjar = profile.Data.Tipjar
		or {
			Ledger = {
				totalReceived = 0,
				donors = {},
				recent = {},
			},
			ListingVisibility = {
				hidden = {},
				version = 0,
				updatedAt = 0,
			},
			CustomListings = {
				GamePasses = {},
				Assets = {},
			},
		}
	return profile.Data.Tipjar
end

function TipjarService:LoadState(player, profile)
	if not PlayerDataManager then
		return
	end

	profile = profile or PlayerDataManager:GetProfile(player)
	if not profile or not profile.Data then
		return
	end

	local tipjar = self:EnsureProfileEntry(profile)
	local ledgerData = tipjar.Ledger or {}
	self.DonationLedger[player.UserId] = {
		total = ledgerData.totalReceived or 0,
		donors = copyTable(ledgerData.donors),
		recent = cloneRecentEntries(ledgerData.recent),
	}

	local visibilityData = tipjar.ListingVisibility or {}
	self.ListingVisibility[player.UserId] = {
		hidden = copyTable(visibilityData.hidden),
		version = visibilityData.version or 0,
		updatedAt = visibilityData.updatedAt or os.clock(),
	}

	local customData = tipjar.CustomListings or {}
	self.CustomListings[player.UserId] = {
		GamePasses = copyTable(customData.GamePasses),
		Assets = copyTable(customData.Assets),
	}
end

function TipjarService:SaveState(player, profile)
	if not PlayerDataManager then
		return
	end

	profile = profile or PlayerDataManager:GetProfile(player)
	if not profile or not profile.Data then
		return
	end

	local tipjar = self:EnsureProfileEntry(profile)
	local ledger = self.DonationLedger[player.UserId]
	if ledger then
		tipjar.Ledger = {
			totalReceived = ledger.total or 0,
			donors = copyTable(ledger.donors),
			recent = cloneRecentEntries(ledger.recent),
		}
	end

	local visibility = self.ListingVisibility[player.UserId]
	if visibility then
		tipjar.ListingVisibility = {
			hidden = copyTable(visibility.hidden),
			version = visibility.version or 0,
			updatedAt = visibility.updatedAt or os.clock(),
		}
	end

	local custom = self.CustomListings[player.UserId]
	if custom then
		tipjar.CustomListings = {
			GamePasses = copyTable(custom.GamePasses),
			Assets = copyTable(custom.Assets),
		}
	end

	PlayerDataManager:UpdatePlayer(player, "Tipjar")
end

function TipjarService:SaveStateByUserId(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self:SaveState(player)
	end
end

function TipjarService:EnsureState(userId)
	if self.DonationLedger[userId] and self.ListingVisibility[userId] then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if player and PlayerDataManager then
		local profile = PlayerDataManager.Profiles and PlayerDataManager.Profiles[player]
		if profile then
			self:LoadState(player, profile)
		else
			self:LoadState(player)
		end
	end
end

local function normalizeProductType(value)
	if value == PRODUCT_TYPES.Transfer then
		return PRODUCT_TYPES.Transfer
	end

	if value == PRODUCT_TYPES.Asset then
		return PRODUCT_TYPES.Asset
	end

	if value == PRODUCT_TYPES.GamePass then
		return PRODUCT_TYPES.GamePass
	end

	if type(value) == "string" then
		local lowered = value:lower()
		if lowered == "robuxtransfer" or lowered == "transfer" then
			return PRODUCT_TYPES.Transfer
		end
		if lowered == "asset" then
			return PRODUCT_TYPES.Asset
		end
		if lowered == "gamepass" or lowered == "game_pass" then
			return PRODUCT_TYPES.GamePass
		end
	end

	return PRODUCT_TYPES.Transfer
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function getListingKey(productType, listingId)
	productType = normalizeProductType(productType)
	return string.format("%s_%d", productType, listingId)
end

function TipjarService:Setup()
	local tipjarComm = Mince:GetEvent("Tipjar")
	self.RequestListingsEvent = tipjarComm:Extend("RequestListings")
	self.ListingsResponseEvent = tipjarComm:Extend("ListingsResponse")
	self.PromptDonationEvent = tipjarComm:Extend("PromptDonation")
	self.DonationResultEvent = tipjarComm:Extend("DonationResult")
	self.OpenTipjarEvent = tipjarComm:Extend("OpenTipjar")
	self.ActivityFeedEvent = tipjarComm:Extend("ActivityFeed")
	self.ToggleListingVisibilityEvent = tipjarComm:Extend("ToggleListingVisibility")
	self.ListingVisibilityResultEvent = tipjarComm:Extend("ListingVisibilityResult")
	self.AddCustomListingResultEvent = tipjarComm:Extend("AddCustomListingResult")

	self.RequestListingsEvent.Event:Connect(function(player, targetUserId)
		self:HandleListingsRequest(player, targetUserId)
	end)

	self.PromptDonationEvent.Event:Connect(function(player, payload)
		self:HandlePromptRequest(player, payload)
	end)

	self.ToggleListingVisibilityEvent.Event:Connect(function(player, payload)
		self:HandleToggleVisibility(player, payload)
	end)

	Marketplace.PromptPurchaseResolved:Connect(function(player, listingId, infoType, wasPurchased)
		local productType
		if infoType == Enum.InfoType.Asset then
			productType = PRODUCT_TYPES.Asset
		elseif infoType == Enum.InfoType.GamePass then
			productType = PRODUCT_TYPES.GamePass
		else
			return
		end

		self:ProcessPromptResult(player, listingId, wasPurchased, productType)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)

	if PlayerDataManager then
		if PlayerDataManager.ProfileLoaded then
			PlayerDataManager.ProfileLoaded:Connect(function(player, profile)
				self:LoadState(player, profile)
			end)
		end

		if PlayerDataManager.ProfileReleased then
			PlayerDataManager.ProfileReleased:Connect(function(player, profile)
				self:SaveState(player, profile)
			end)
		end
	end

	local receiptsBound, receiptErr = pcall(function()
		self.TransferSenderReceiptConnection = MarketplaceService:BindReceiptHandler(
			Enum.ReceiptType.RobuxTransferSender,
			function(receiptInfo)
				return self:ProcessTransferReceipt(receiptInfo, PRODUCT_TYPES.Transfer, false)
			end
		)

		self.TransferReceiverReceiptConnection = MarketplaceService:BindReceiptHandler(
			Enum.ReceiptType.RobuxTransferReceiver,
			function(receiptInfo)
				return self:ProcessTransferReceipt(receiptInfo, PRODUCT_TYPES.Transfer, true)
			end
		)
	end)
	if not receiptsBound then
		warn("TipjarService: Robux transfer receipt handlers could not be registered.", receiptErr)
	end
end

function TipjarService:GameStart() end

function TipjarService:CleanupPlayer(player)
	self:SaveState(player)
	self.ActiveTipjars[player.UserId] = nil
	self.RateLimits[player] = nil
	self.PendingPrompts[player.UserId] = nil
	self.DonationLedger[player.UserId] = nil
	self.ListingVisibility[player.UserId] = nil
	self.CustomListings[player.UserId] = nil
end

function TipjarService:RegisterTipjar(component)
	local owner = component:GetOwner()
	if not owner then
		return
	end

	self.ActiveTipjars[owner.UserId] = {
		Component = component,
		Player = owner,
		UpdatedAt = os.clock(),
	}
end

function TipjarService:UnregisterTipjar(component)
	for userId, record in pairs(self.ActiveTipjars) do
		if record.Component == component then
			self.ActiveTipjars[userId] = nil
			break
		end
	end
end

function TipjarService:HandleListingsRequest(player, targetUserId)
	targetUserId = tonumber(targetUserId)
	if not targetUserId then
		return
	end
	if not self:CheckRateLimit(player, "Listings", LISTING_REQUEST_LIMIT, LISTING_REQUEST_WINDOW) then
		self.ListingsResponseEvent:Fire(player, false, { error = "Too many requests" })
		return
	end

	local success, payloadOrError = self:BuildListingsPayload(player, targetUserId)
	if not success then
		self.ListingsResponseEvent:Fire(player, false, { error = payloadOrError or "Unable to load listings" })
		return
	end

	self.ListingsResponseEvent:Fire(player, true, payloadOrError)
end

function TipjarService:HandlePromptRequest(player, payload)
	if type(payload) ~= "table" then
		return
	end

	local targetUserId = tonumber(payload.targetUserId)
	local listingId = tonumber(payload.listingId)
	local productType = normalizeProductType(payload.productType)
	if not targetUserId or not listingId then
		return
	end

	if targetUserId == player.UserId then
		self:FireDonationResult(player, false, "You cannot donate to yourself", "PromptRejected")
		return
	end

	if not self.ActiveTipjars[targetUserId] then
		self:FireDonationResult(player, false, "That tip jar is not active", "PromptRejected")
		return
	end

	if not self:CheckRateLimit(player, "Prompt", PROMPT_RATE_LIMIT, PROMPT_RATE_WINDOW) then
		self:FireDonationResult(player, false, "Please wait before prompting again", "PromptRejected")
		return
	end

	local listing, err = self:ValidateListing(targetUserId, listingId, productType)
	if not listing then
		self:FireDonationResult(player, false, err or "Listing unavailable", "PromptRejected")
		return
	end

	if
		productType ~= PRODUCT_TYPES.Transfer
		and player.UserId ~= targetUserId
		and self:IsListingHidden(targetUserId, listing.Id, productType)
	then
		self:FireDonationResult(player, false, "That listing is not currently visible", "PromptRejected")
		return
	end

	if productType ~= PRODUCT_TYPES.Transfer and self:ListingOwnedByUser(player.UserId, listing.Id, productType) then
		self:FireDonationResult(player, false, "You already own that product", "PromptRejected")
		return
	end

	self.PendingPrompts[player.UserId] = {
		targetUserId = targetUserId,
		listing = listing,
		productType = listing.ProductType,
		recordedAt = os.clock(),
	}

	local success, promptErr
	if productType == PRODUCT_TYPES.Transfer then
		success, promptErr = pcall(function()
			return MarketplaceService:PromptRobuxTransferAsync(player, targetUserId, listing.Price)
		end)
	elseif productType == PRODUCT_TYPES.Asset then
		success, promptErr = pcall(function()
			return Marketplace.PromptPurchase(listing.Id, Enum.InfoType.Asset, player)
		end)
	else
		success, promptErr = pcall(function()
			return Marketplace.PromptPurchase(listing.Id, Enum.InfoType.GamePass, player)
		end)
	end
	if not success then
		self.PendingPrompts[player.UserId] = nil
		self:FireDonationResult(player, false, "Unable to open purchase prompt", "PromptFailed")
		warn("Tipjar prompt failed", promptErr)
		return
	end

	if productType == PRODUCT_TYPES.Transfer then
		local transferRequestId = promptErr
		self.PendingTransfers[transferRequestId] = {
			transferRequestId = transferRequestId,
			senderUserId = player.UserId,
			senderName = player.DisplayName,
			targetUserId = targetUserId,
			listing = listing,
			amount = listing.Price,
			recordedAt = os.clock(),
		}
		self.PendingPrompts[player.UserId] = nil
		self:FireDonationResult(player, true, nil, "TransferPrompted", listing, transferRequestId)
		return
	end

	self:FireDonationResult(player, true, nil, "PromptAccepted", listing)
end

function TipjarService:OnTipjarClicked(player, component)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local owner = component and component:GetOwner()
	if not owner then
		return
	end

	self:EnsureState(owner.UserId)

	if not self.ActiveTipjars[owner.UserId] then
		return
	end

	local payload = {
		targetUserId = owner.UserId,
		target = {
			userId = owner.UserId,
			name = owner.DisplayName,
		},
		forceRefresh = true,
		ownerPreview = player == owner,
	}

	self.OpenTipjarEvent:Fire(player, payload)
end

function TipjarService:HandleToggleVisibility(player, payload)
	if type(payload) ~= "table" then
		return
	end

	local listingId = tonumber(payload.listingId)
	local productType = normalizeProductType(payload.productType)
	local desiredVisible = payload.visible ~= false

	if not listingId then
		return
	end

	self:EnsureState(player.UserId)

	local targetUserId = player.UserId
	local listing, err = self:ValidateListing(targetUserId, listingId, productType)
	if not listing then
		self:FireVisibilityResult(player, false, err or "Listing unavailable", listingId, productType, desiredVisible)
		return
	end

	self:SetListingVisibility(targetUserId, listingId, productType, desiredVisible)

	self:FireVisibilityResult(player, true, nil, listingId, productType, desiredVisible)
end

function TipjarService:HandlePromptOutcome(player, payload)
	if type(payload) ~= "table" then
		return
	end

	local listingId = tonumber(payload.listingId)
	local productType = normalizeProductType(payload.productType)
	local wasPurchased = payload.wasPurchased == true

	if not listingId then
		return
	end

	self:ProcessPromptResult(player, listingId, wasPurchased, productType)
end

function TipjarService:HandleAddCustomListing(player, payload)
	if type(payload) ~= "table" then
		return
	end

	local listingId = tonumber(payload.listingId)
	local productType = normalizeProductType(payload.productType)
	if not listingId then
		return
	end

	self:EnsureState(player.UserId)

	local listing, err = self:ValidateListing(player.UserId, listingId, productType)
	if not listing then
		self.AddCustomListingResultEvent:Fire(player, false, {
			message = err or "Listing could not be added",
			listingId = listingId,
			productType = productType,
		})
		return
	end

	local custom = self:GetCustomListings(player.UserId)
	local list = productType == PRODUCT_TYPES.Asset and custom.Assets or custom.GamePasses
	local alreadyAdded = false
	for _, existingId in ipairs(list) do
		if existingId == listingId then
			alreadyAdded = true
			break
		end
	end

	if not alreadyAdded then
		table.insert(list, listingId)
		self:SaveStateByUserId(player.UserId)
		self.PassCache[player.UserId] = nil
	end

	self.AddCustomListingResultEvent:Fire(player, true, {
		listing = listing,
		listingId = listingId,
		productType = productType,
		alreadyAdded = alreadyAdded,
	})
end

function TipjarService:GetTransferListing(amount)
	amount = tonumber(amount)
	if not amount or amount <= 0 or amount ~= math.floor(amount) then
		return nil, "Invalid transfer amount"
	end

	for _, allowedAmount in ipairs(TRANSFER_AMOUNTS) do
		if amount == allowedAmount then
			return {
				Id = amount,
				ProductType = PRODUCT_TYPES.Transfer,
				Name = string.format("%d Robux", amount),
				Description = "Send Robux directly to this player",
				Price = amount,
				Icon = nil,
			}
		end
	end

	return nil, "That transfer amount is not available"
end

function TipjarService:ProcessTransferReceipt(receiptInfo, _productType, isReceiver)
	local transferRequestId = receiptInfo and receiptInfo.TransferRequestId
	if type(transferRequestId) ~= "string" or transferRequestId == "" then
		return Enum.ReceiptDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ReceiptDecision.NotProcessedYet
	end

	local pending = self.PendingTransfers[transferRequestId]
	local amount = tonumber((pending and pending.amount) or receiptInfo.CurrencySpent)
	local listing = pending and pending.listing or self:GetTransferListing(amount)
	if not listing then
		return Enum.ReceiptDecision.NotProcessedYet
	end

	if isReceiver then
		if self.ProcessedTransfers[transferRequestId] then
			return Enum.ReceiptDecision.Processed
		end

		local donorUserId = pending and pending.senderUserId
		local donorName = pending and pending.senderName or "A player"
		self:RecordTransferDonation(donorUserId, donorName, player.UserId, listing, transferRequestId)
		self.ProcessedTransfers[transferRequestId] = true

		local recipientPayload = {
			state = "DonationReceived",
			listing = listing,
			donor = {
				userId = donorUserId,
				name = donorName,
			},
			targetUserId = player.UserId,
			transferRequestId = transferRequestId,
			ledger = self:GetLedgerSnapshot(player.UserId, player.UserId),
		}
		self.DonationResultEvent:Fire(player, true, recipientPayload)
		self.ActivityFeedEvent:Fire(player, recipientPayload)

		local donor = donorUserId and Players:GetPlayerByUserId(donorUserId)
		if donor then
			self.DonationResultEvent:Fire(donor, true, {
				state = "PurchaseComplete",
				listing = listing,
				targetUserId = player.UserId,
				transferRequestId = transferRequestId,
				ledger = self:GetLedgerSnapshot(player.UserId, donor.UserId),
			})
		end

		self.PendingTransfers[transferRequestId] = nil
		return Enum.ReceiptDecision.Processed
	end

	if pending then
		self.DonationResultEvent:Fire(player, true, {
			state = "TransferSettled",
			listing = listing,
			targetUserId = pending.targetUserId,
			transferRequestId = transferRequestId,
			ledger = self:GetLedgerSnapshot(pending.targetUserId, player.UserId),
		})
	end

	return Enum.ReceiptDecision.Processed
end

function TipjarService:ProcessPromptResult(player, productId, wasPurchased, productType)
	productType = normalizeProductType(productType)
	local pending = self.PendingPrompts[player.UserId]
	if not pending or pending.listing.Id ~= productId or pending.productType ~= productType then
		return
	end

	if not wasPurchased then
		self.PendingPrompts[player.UserId] = nil
		self:FireDonationResult(player, false, "Purchase cancelled", "PurchaseCancelled", pending.listing)
		return
	end

	local confirmed = self:ListingOwnedByUser(player.UserId, productId, productType)
	if not confirmed then
		self.PendingPrompts[player.UserId] = nil
		self:FireDonationResult(player, false, "We could not confirm that purchase", "PurchaseFailed", pending.listing)
		return
	end

	local listing = pending.listing
	local targetUserId = pending.targetUserId
	self.PendingPrompts[player.UserId] = nil

	self:RecordDonation(player, targetUserId, listing)

	local donorPayload = {
		state = "PurchaseComplete",
		listing = listing,
		targetUserId = targetUserId,
		ledger = self:GetLedgerSnapshot(targetUserId, player.UserId),
	}
	self.DonationResultEvent:Fire(player, true, donorPayload)

	local recipient = Players:GetPlayerByUserId(targetUserId)
	if recipient then
		local recipientPayload = {
			state = "DonationReceived",
			listing = listing,
			donor = {
				userId = player.UserId,
				name = player.DisplayName,
			},
			ledger = self:GetLedgerSnapshot(targetUserId, recipient.UserId),
		}
		self.DonationResultEvent:Fire(recipient, true, recipientPayload)
		self.ActivityFeedEvent:Fire(recipient, recipientPayload)
	end
end

function TipjarService:FireDonationResult(player, success, message, state, listing, transferRequestId)
	self.DonationResultEvent:Fire(player, success, {
		state = state,
		message = message,
		listing = listing,
		transferRequestId = transferRequestId,
	})
end

function TipjarService:FireVisibilityResult(player, success, message, listingId, productType, visible)
	self.ListingVisibilityResultEvent:Fire(player, success, {
		state = success and "VisibilityUpdated" or "VisibilityFailed",
		message = message,
		listingId = listingId,
		productType = productType,
		visible = visible,
		targetUserId = player.UserId,
	})
end

function TipjarService:BuildListingsPayload(requester, targetUserId)
	self:EnsureState(targetUserId)
	local listings, cacheOrError = self:GetListingsForUser(targetUserId)
	if not listings then
		return false, cacheOrError
	end

	local annotated = self:ApplyOwnershipFlags(requester, listings)
	annotated = self:ApplyVisibilityForViewer(targetUserId, requester.UserId, annotated)
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	local ledger = self:GetLedgerSnapshot(targetUserId, requester.UserId)

	return true,
		{
			requester = {
				userId = requester.UserId,
				name = requester.DisplayName,
			},
			target = {
				userId = targetUserId,
				name = targetPlayer and targetPlayer.DisplayName or ("User " .. targetUserId),
			},
			listings = annotated,
			cacheVersion = cacheOrError.version,
			cacheExpiresIn = clamp((cacheOrError.expires or 0) - os.clock(), 0, CACHE_TTL),
			ledger = ledger,
			ownerPreview = targetUserId == requester.UserId,
		}
end

function TipjarService:GetListingsForUser(targetUserId)
	local cache = self.PassCache[targetUserId]
	local now = os.clock()
	if cache and cache.expires > now then
		return cache.data, cache
	end

	local listings = self:BuildTransferListings()

	cache = {
		data = listings,
		expires = now + CACHE_TTL,
		version = HttpService:GenerateGUID(false),
	}
	self.PassCache[targetUserId] = cache

	return listings, cache
end

function TipjarService:BuildTransferListings()
	local listings = {}
	for _, amount in ipairs(TRANSFER_AMOUNTS) do
		table.insert(listings, {
			Id = amount,
			ProductType = PRODUCT_TYPES.Transfer,
			Name = string.format("%d Robux", amount),
			Description = "Send Robux directly to this player",
			Price = amount,
			Icon = nil,
			Visible = true,
		})
	end
	return listings
end

function TipjarService:GetCustomListings(userId)
	local record = self.CustomListings[userId]
	if not record then
		record = {
			GamePasses = {},
			Assets = {},
		}
		self.CustomListings[userId] = record
	end
	return record
end

function TipjarService:FetchListings(targetUserId)
	if not HttpService.HttpEnabled then
		return nil, "HTTP requests are disabled. Enable Allow HTTP Requests in Studio settings."
	end

	local success, inventory
	for attempt = 1, 2 do
		success, inventory = RobloxApiService.GetUserSaleInventory(targetUserId)
		if success and type(inventory) == "table" then
			break
		end
		task.wait(attempt * 0.5)
	end
	if not success or type(inventory) ~= "table" then
		return nil, "Unable to reach Roblox game pass API"
	end

	local gamePassEntries = type(inventory.gamePasses) == "table" and inventory.gamePasses or {}
	local catalogEntries = type(inventory.catalogItems) == "table" and inventory.catalogItems or {}

	local listings = {}
	local seen = {}

	local function appendListing(listingId, info, fallbackName, fallbackDescription, productType)
		productType = productType or PRODUCT_TYPES.GamePass
		local key = string.format("%s_%d", productType, listingId)
		if seen[key] then
			return
		end
		seen[key] = true

		table.insert(listings, {
			Id = listingId,
			ProductType = productType,
			Name = info.Name or fallbackName or ("Pass " .. listingId),
			Description = info.Description or fallbackDescription or "",
			Price = info.PriceInRobux or 0,
			Icon = info.IconImageAssetId,
		})
	end

	local function resolveEntryPassId(entry)
		if type(entry) ~= "table" then
			return nil
		end

		local candidate = entry.id
			or entry.gamePassId
			or entry.gamepassId
			or (type(entry.gamePass) == "table" and (entry.gamePass.id or entry.gamePass.gamePassId))
			or (type(entry.product) == "table" and (entry.product.id or entry.product.gamePassId))

		if type(candidate) == "string" then
			candidate = tonumber(candidate)
		end

		if type(candidate) == "number" and candidate > 0 then
			return candidate
		end

		return nil
	end

	local function resolveEntryName(entry)
		if type(entry) ~= "table" then
			return nil
		end

		local value = entry.displayName or entry.name or entry.Name
		if not value and type(entry.gamePass) == "table" then
			value = entry.gamePass.displayName or entry.gamePass.name
		end

		if type(value) == "string" and value ~= "" then
			return value
		end

		return nil
	end

	local function resolveEntryDescription(entry)
		if type(entry) ~= "table" then
			return nil
		end

		local value = entry.description or entry.Description or entry.descriptionText
		if not value and type(entry.gamePass) == "table" then
			value = entry.gamePass.description or entry.gamePass.Description
		end

		if type(value) == "string" and value ~= "" then
			return value
		end

		return nil
	end

	local custom = self:GetCustomListings(targetUserId)
	local customPasses = type(custom.GamePasses) == "table" and custom.GamePasses or {}
	local customAssets = type(custom.Assets) == "table" and custom.Assets or {}

	for _, passId in ipairs(customPasses) do
		if #listings >= MAX_LISTINGS then
			break
		end
		local resolvedId = tonumber(passId)
		if resolvedId then
			local info = self:ValidateGamepassListing(targetUserId, resolvedId)
			if info then
				appendListing(info.Id, info, info.Name, info.Description, info.ProductType)
			end
		end
	end

	for _, assetId in ipairs(customAssets) do
		if #listings >= MAX_LISTINGS then
			break
		end
		local resolvedId = tonumber(assetId)
		if resolvedId then
			local info = self:ValidateAssetListing(targetUserId, resolvedId)
			if info then
				appendListing(info.Id, info, info.Name, info.Description, info.ProductType)
			end
		end
	end

	for _, entry in ipairs(gamePassEntries) do
		if #listings >= MAX_LISTINGS then
			break
		end

		local passId = resolveEntryPassId(entry)
		if passId then
			local info = self:GetGamepassInfo(passId)
			if info then
				local creatorId = tonumber(info.Creator and info.Creator.CreatorTargetId)
				if creatorId == targetUserId and info.IsForSale ~= false and (info.PriceInRobux or 0) > 0 then
					appendListing(
						passId,
						info,
						resolveEntryName(entry),
						resolveEntryDescription(entry),
						PRODUCT_TYPES.GamePass
					)
				end
			end
		end
	end

	if #listings < MAX_LISTINGS then
		for _, entry in ipairs(catalogEntries) do
			if #listings >= MAX_LISTINGS then
				break
			end

			if type(entry) ~= "table" or entry.itemType ~= "Asset" then
				continue
			end

			local assetId = tonumber(entry.id)
			if not assetId then
				continue
			end

			local info = self:GetAssetInfo(assetId)
			if info then
				local creatorId = tonumber(info.Creator and (info.Creator.CreatorTargetId or info.Creator.Id))
				local price = info.PriceInRobux or entry.price or 0
				if creatorId == targetUserId and info.IsForSale ~= false and price > 0 then
					appendListing(
						assetId,
						info,
						resolveEntryName(entry),
						resolveEntryDescription(entry),
						PRODUCT_TYPES.Asset
					)
				end
			end
		end
	end

	table.sort(listings, function(a, b)
		if a.Price == b.Price then
			return a.Id < b.Id
		end
		return a.Price < b.Price
	end)

	return listings
end

function TipjarService:GetGamepassInfo(passId)
	local cache = self.GamepassInfoCache[passId]
	local now = os.clock()
	if cache and cache.expires > now then
		return cache.info
	end

	local info
	for attempt = 1, 2 do
		local success, result =
			pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
		if success then
			info = result
			break
		end
		task.wait(attempt * 0.25)
	end

	if not info then
		return nil
	end

	self.GamepassInfoCache[passId] = {
		info = info,
		expires = now + CACHE_TTL,
	}

	return info
end

function TipjarService:GetAssetInfo(assetId)
	local cache = self.AssetInfoCache[assetId]
	local now = os.clock()
	if cache and cache.expires > now then
		return cache.info
	end

	local info
	for attempt = 1, 2 do
		local success, result =
			pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId, Enum.InfoType.Asset)
		if success then
			info = result
			break
		end
		task.wait(attempt * 0.25)
	end

	if not info then
		return nil
	end

	self.AssetInfoCache[assetId] = {
		info = info,
		expires = now + CACHE_TTL,
	}

	return info
end

function TipjarService:ApplyOwnershipFlags(player, listings)
	local output = {}
	for _, listing in ipairs(listings) do
		local copy = copyTable(listing)
		copy.ProductType = normalizeProductType(copy.ProductType)
		copy.Owned = copy.ProductType ~= PRODUCT_TYPES.Transfer
			and self:ListingOwnedByUser(player.UserId, listing.Id, copy.ProductType)
		table.insert(output, copy)
	end
	return output
end

function TipjarService:ApplyVisibilityForViewer(targetUserId, viewerUserId, listings)
	self:EnsureState(targetUserId)
	local record = self.ListingVisibility[targetUserId]
	local hiddenMap = record and record.hidden
	if not hiddenMap or next(hiddenMap) == nil then
		if targetUserId == viewerUserId then
			for _, listing in ipairs(listings) do
				listing.Visible = true
			end
		end
		return listings
	end

	if targetUserId == viewerUserId then
		for _, listing in ipairs(listings) do
			local key = getListingKey(listing.ProductType, listing.Id)
			listing.Visible = hiddenMap[key] ~= true
		end
		return listings
	end

	local filtered = {}
	for _, listing in ipairs(listings) do
		local key = getListingKey(listing.ProductType, listing.Id)
		if hiddenMap[key] ~= true then
			table.insert(filtered, listing)
		end
	end
	return filtered
end

function TipjarService:UserOwnsGamepass(userId, passId)
	local cacheKey = string.format("%d_%d", userId, passId)
	local cache = self.OwnershipCache[cacheKey]
	local now = os.clock()
	if cache and cache.expires > now then
		return cache.owns
	end

	local success, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
	local owns = success and result or false

	self.OwnershipCache[cacheKey] = {
		owns = owns,
		expires = now + OWNERSHIP_CACHE_TTL,
	}

	return owns
end

function TipjarService:UserOwnsAsset(userId, assetId)
	local cacheKey = string.format("asset_%d_%d", userId, assetId)
	local cache = self.AssetOwnershipCache[cacheKey]
	local now = os.clock()
	if cache and cache.expires > now then
		return cache.owns
	end

	local success, result = pcall(MarketplaceService.PlayerOwnsAsset, MarketplaceService, userId, assetId)
	local owns = success and result or false

	self.AssetOwnershipCache[cacheKey] = {
		owns = owns,
		expires = now + OWNERSHIP_CACHE_TTL,
	}

	return owns
end

function TipjarService:ListingOwnedByUser(userId, listingId, productType)
	productType = normalizeProductType(productType)
	if productType == PRODUCT_TYPES.Transfer then
		return false
	end
	if productType == PRODUCT_TYPES.Asset then
		return self:UserOwnsAsset(userId, listingId)
	end

	return self:UserOwnsGamepass(userId, listingId)
end

function TipjarService:IsListingHidden(targetUserId, listingId, productType)
	self:EnsureState(targetUserId)
	local record = self.ListingVisibility[targetUserId]
	if not record or not record.hidden then
		return false
	end
	local key = getListingKey(productType, listingId)
	return record.hidden[key] == true
end

function TipjarService:SetListingVisibility(targetUserId, listingId, productType, visible)
	local record = self:GetVisibility(targetUserId)

	local key = getListingKey(productType, listingId)
	if visible then
		record.hidden[key] = nil
	else
		record.hidden[key] = true
	end

	record.version = (record.version or 0) + 1
	record.updatedAt = os.clock()

	self:SaveStateByUserId(targetUserId)
end

function TipjarService:ValidateGamepassListing(targetUserId, passId)
	local info = self:GetGamepassInfo(passId)
	if not info then
		return nil, "Unable to load listing details"
	end

	local creatorId = tonumber(info.Creator and info.Creator.CreatorTargetId)

	if creatorId ~= targetUserId then
		return nil, "Listing does not belong to that player"
	end

	if info.IsForSale == false then
		return nil, "Listing is no longer for sale"
	end

	if not info.PriceInRobux or info.PriceInRobux <= 0 then
		return nil, "Listing price is invalid"
	end

	return {
		Id = passId,
		ProductType = PRODUCT_TYPES.GamePass,
		Name = info.Name,
		Description = info.Description or "",
		Price = info.PriceInRobux,
		Icon = info.IconImageAssetId,
	}
end

function TipjarService:ValidateAssetListing(targetUserId, assetId)
	local info = self:GetAssetInfo(assetId)
	if not info then
		return nil, "Unable to load listing details"
	end

	local creatorId = tonumber(info.Creator and (info.Creator.CreatorTargetId or info.Creator.Id))
	if creatorId ~= targetUserId then
		return nil, "Listing does not belong to that player"
	end

	if info.IsForSale == false then
		return nil, "Listing is no longer for sale"
	end

	if not info.PriceInRobux or info.PriceInRobux <= 0 then
		return nil, "Listing price is invalid"
	end

	return {
		Id = assetId,
		ProductType = PRODUCT_TYPES.Asset,
		Name = info.Name,
		Description = info.Description or "",
		Price = info.PriceInRobux,
		Icon = info.IconImageAssetId,
	}
end

function TipjarService:ValidateListing(targetUserId, listingId, productType)
	productType = normalizeProductType(productType)
	if productType == PRODUCT_TYPES.Transfer then
		return self:GetTransferListing(listingId)
	end
	if productType == PRODUCT_TYPES.Asset then
		return self:ValidateAssetListing(targetUserId, listingId)
	end

	return self:ValidateGamepassListing(targetUserId, listingId)
end

function TipjarService:RecordDonation(donorPlayer, targetUserId, listing)
	local ledger = self:GetLedger(targetUserId)

	ledger.total = ledger.total + listing.Price
	ledger.donors[donorPlayer.UserId] = (ledger.donors[donorPlayer.UserId] or 0) + listing.Price

	table.insert(ledger.recent, 1, {
		donorUserId = donorPlayer.UserId,
		donorName = donorPlayer.DisplayName,
		amount = listing.Price,
		listingId = listing.Id,
		listingName = listing.Name,
		timestamp = os.time(),
	})

	while #ledger.recent > 10 do
		table.remove(ledger.recent)
	end

	self:SaveStateByUserId(targetUserId)

	local AchievementService = Mince:Get("AchievementService")
	if AchievementService then
		AchievementService:RecordStat(donorPlayer, "DonationsMade", 1)
	end
end

function TipjarService:RecordTransferDonation(donorUserId, donorName, targetUserId, listing, transferRequestId)
	local ledger = self:GetLedger(targetUserId)
	local amount = tonumber(listing and listing.Price) or 0
	if amount <= 0 then
		return
	end

	ledger.total = ledger.total + amount
	if donorUserId then
		ledger.donors[donorUserId] = (ledger.donors[donorUserId] or 0) + amount
	end

	table.insert(ledger.recent, 1, {
		donorUserId = donorUserId,
		donorName = donorName or "A player",
		amount = amount,
		listingId = listing and listing.Id,
		listingName = listing and listing.Name or string.format("%d Robux", amount),
		transferRequestId = transferRequestId,
		timestamp = os.time(),
	})

	while #ledger.recent > 10 do
		table.remove(ledger.recent)
	end

	self:SaveStateByUserId(targetUserId)

	local donorPlayer = donorUserId and Players:GetPlayerByUserId(donorUserId)
	local AchievementService = Mince:Get("AchievementService")
	if donorPlayer and AchievementService then
		AchievementService:RecordStat(donorPlayer, "DonationsMade", 1)
	end
end

function TipjarService:GetLedgerSnapshot(targetUserId, viewerUserId)
	self:EnsureState(targetUserId)
	local ledger = self.DonationLedger[targetUserId]
	if not ledger then
		return {
			totalReceived = 0,
			viewerTotal = 0,
			recent = {},
		}
	end

	local recentCopy = {}
	for _, entry in ipairs(ledger.recent) do
		table.insert(recentCopy, copyTable(entry))
	end

	return {
		totalReceived = ledger.total,
		viewerTotal = ledger.donors[viewerUserId] or 0,
		recent = recentCopy,
	}
end

function TipjarService:CheckRateLimit(player, bucket, limit, window)
	self.RateLimits[player] = self.RateLimits[player] or {}
	local now = os.clock()
	local record = self.RateLimits[player][bucket]
	if not record or record.resetsAt <= now then
		record = {
			count = 0,
			resetsAt = now + window,
		}
		self.RateLimits[player][bucket] = record
	end

	if record.count >= limit then
		return false
	end

	record.count = record.count + 1
	return true
end

function TipjarService.Tipjar:Construct()
	self.Tool = self.Instance :: Tool
	self.Connections = {}

	self.Connections.Equipped = self.Tool.Equipped:Connect(function()
		TipjarService:RegisterTipjar(self)
	end)

	self.Connections.Unequipped = self.Tool.Unequipped:Connect(function()
		TipjarService:UnregisterTipjar(self)
	end)

	self.Connections.Destroying = self.Tool.Destroying:Connect(function()
		TipjarService:UnregisterTipjar(self)
	end)

	self:AttachClickDetector()
end

function TipjarService.Tipjar:GetOwner()
	local parent = self.Tool.Parent
	if not parent then
		return nil
	end

	if parent:IsA("Backpack") then
		local player = parent.Parent
		if player and player:IsA("Player") then
			return player
		end
		return nil
	end

	if parent:IsA("Model") then
		return Players:GetPlayerFromCharacter(parent)
	end

	return nil
end

function TipjarService.Tipjar:Destroying()
	if self.Connections then
		for _, connection in pairs(self.Connections) do
			if connection then
				connection:Disconnect()
			end
		end
	end

	if self.ClickDetectorConnection then
		self.ClickDetectorConnection:Disconnect()
		self.ClickDetectorConnection = nil
	end

	if self.CreatedClickDetector and self.ClickDetector then
		self.ClickDetector:Destroy()
	end

	self.ClickDetector = nil

	TipjarService:UnregisterTipjar(self)
end

function TipjarService.Tipjar:GetClickPart()
	local handle = self.Tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end

	return self.Tool:FindFirstChildWhichIsA("BasePart")
end

function TipjarService.Tipjar:AttachClickDetector()
	local part = self:GetClickPart()
	if not part then
		if not self.Connections then
			self.Connections = {}
		end

		if not self.Connections.HandleAdded then
			self.Connections.HandleAdded = self.Tool.ChildAdded:Connect(function()
				if self:GetClickPart() then
					self:AttachClickDetector()
				end
			end)
		end
		return
	end

	if self.Connections and self.Connections.HandleAdded then
		self.Connections.HandleAdded:Disconnect()
		self.Connections.HandleAdded = nil
	end

	local detector = part:FindFirstChildOfClass("ClickDetector")
	if not detector then
		detector = Instance.new("ClickDetector")
		detector.Name = "TipjarClickDetector"
		detector.MaxActivationDistance = 20
		detector.Parent = part
		self.CreatedClickDetector = true
	end

	self.ClickDetector = detector

	if self.ClickDetectorConnection then
		self.ClickDetectorConnection:Disconnect()
	end

	self.ClickDetectorConnection = detector.MouseClick:Connect(function(player)
		TipjarService:OnTipjarClicked(player, self)
	end)
end

return TipjarService
