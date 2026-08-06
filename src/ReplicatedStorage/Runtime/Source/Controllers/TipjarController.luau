local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules:WaitForChild("Mince"))
local UI = require(Modules:WaitForChild("UI"))

local TipjarScreen

local function getTipjarScreen()
	if not UI.TipjarScreen and UI.WaitUntilLoaded then
		UI.WaitUntilLoaded()
	end

	return UI.TipjarScreen
end

TipjarScreen = setmetatable({}, {
	__index = function(_, key)
		local screen = getTipjarScreen()
		if not screen then
			return nil
		end

		local value = screen[key]
		if typeof(value) ~= "function" then
			return value
		end

		return function(firstArg, ...)
			if firstArg == TipjarScreen then
				return value(screen, ...)
			end

			return value(firstArg, ...)
		end
	end,
})

local ROBUX_PREFIX = ""

local TipjarController = {
	Name = "TipjarController",
	Cache = {},
	CurrentTargetUserId = nil,
	CurrentTarget = nil,
	PendingRequestTarget = nil,
	PendingAddListing = false,
}

local function formatAmount(amount: number?): string
	local value = math.floor(tonumber(amount) or 0)
	local formatted = tostring(value)
	while true do
		local updated, replacements = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = updated
		if replacements == 0 then
			break
		end
	end
	return ROBUX_PREFIX .. formatted
end

function TipjarController:Setup()
	self.Cache = {}
	self.PendingRequestTarget = nil
	self.PendingListingId = nil
	self.PendingAddListing = false
	self.Connections = {}

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

end

function TipjarController:GameStart()
	table.insert(self.Connections, self.ListingsResponseEvent.Event:Connect(function(success, payload)
		self:OnListingsResponse(success, payload)
	end))

	table.insert(self.Connections, self.DonationResultEvent.Event:Connect(function(success, payload)
		self:OnDonationResult(success, payload)
	end))

	table.insert(self.Connections, self.ActivityFeedEvent.Event:Connect(function(payload)
		self:OnActivityFeed(payload)
	end))

	table.insert(self.Connections, self.ListingVisibilityResultEvent.Event:Connect(function(success, payload)
		self:OnVisibilityResult(success, payload)
	end))

	table.insert(self.Connections, self.OpenTipjarEvent.Event:Connect(function(payload)
		self:OnOpenTipjar(payload)
	end))

	self:InitOwnerEquipBindings()
end

function TipjarController:OnOpenTipjar(payload)
	local targetUserId
	if type(payload) == "table" then
		targetUserId = payload.targetUserId or (payload.target and payload.target.userId)
	end
	if not targetUserId then
		return
	end

	local targetData = payload.target or {
		userId = targetUserId,
		name = payload.targetName or self:GetDisplayName(targetUserId),
	}

	self:ShowTipjar(targetUserId, {
		target = targetData,
		ledger = payload.ledger,
		listings = payload.listings,
		forceRefresh = payload.forceRefresh,
		ownerPreview = payload.ownerPreview,
		status = payload.status,
	})
end

function TipjarController:GetDisplayName(userId)
	local player = Players:GetPlayerByUserId(userId)
	return player and player.DisplayName or ("User " .. tostring(userId))
end
function TipjarController:GetCachedTargetName(userId)
	if self.CurrentTarget and self.CurrentTarget.userId == userId then
		return self.CurrentTarget.name
	end

	local cache = self.Cache[userId]
	if cache and cache.target then
		return cache.target.name
	end

	return self:GetDisplayName(userId)
end

function TipjarController:IsViewing(userId)
	if not TipjarScreen or not TipjarScreen.Showing then
		return false
	end
	return self.CurrentTargetUserId == userId
end

function TipjarController:IsOwnerViewing()
	return self.CurrentTargetUserId ~= nil and self.CurrentTargetUserId == LocalPlayer.UserId
end

function TipjarController:ShowTipjar(targetUserId, options)
	targetUserId = tonumber(targetUserId)
	if not targetUserId then
		return
	end

	options = options or {}
	local targetData = options.target or {
		userId = targetUserId,
		name = options.targetName or self:GetDisplayName(targetUserId),
	}

	self.CurrentTargetUserId = targetUserId
	self.CurrentTarget = targetData

	local cached = self:GetCacheEntry(targetUserId)
	local listings = options.listings or (cached and cached.listings)
	local ledger = options.ledger or (cached and cached.ledger)
	local initialStatus = options.status
	if not initialStatus then
		initialStatus = {
			text = listings and "Select a tier to donate" or "Loading donation options...",
			kind = "info",
		}
		if options.ownerPreview or targetUserId == LocalPlayer.UserId then
			initialStatus.text = "Previewing your tip jar listings"
		end
	end

	TipjarScreen.Show({
		target = targetData,
		ledger = ledger,
		listings = listings,
		isLoading = listings == nil,
		status = initialStatus,
		editing = targetUserId == LocalPlayer.UserId,
		onDonate = function(listing)
			self:PromptDonation(listing)
		end,
		onClose = function(reason)
			self:OnScreenClosed(reason)
		end,
	})

	if not listings or options.forceRefresh then
		self:RequestListingsFor(targetUserId)
	end
end

function TipjarController:RequestListingsFor(targetUserId)
	targetUserId = tonumber(targetUserId)
	if not targetUserId then
		return
	end

	self.PendingRequestTarget = targetUserId
	TipjarScreen:SetLoading(true)
	TipjarScreen:SetStatus("Loading donation options...", "info")
	self.RequestListingsEvent:Fire(targetUserId)
end

function TipjarController:OnListingsResponse(success, payload)
	if not payload then
		return
	end

	local targetUserId
	if payload.target and payload.target.userId then
		targetUserId = payload.target.userId
	elseif payload.targetUserId then
		targetUserId = payload.targetUserId
	else
		targetUserId = self.PendingRequestTarget or self.CurrentTargetUserId
	end

	if not targetUserId then
		return
	end

	if not success then
		if self:IsViewing(targetUserId) then
			TipjarScreen:SetLoading(false)
			TipjarScreen:SetStatus(payload.error or "Unable to load donation options", "error")
		end
		self.PendingRequestTarget = nil
		return
	end

	self.Cache[targetUserId] = {
		listings = payload.listings,
		ledger = payload.ledger,
		target = payload.target,
		expires = os.clock() + (payload.cacheExpiresIn or 0),
	}

	if not self:IsViewing(targetUserId) then
		return
	end

	TipjarScreen:SetTarget(payload.target)
	TipjarScreen:SetLedger(payload.ledger)
	TipjarScreen:RenderListings(payload.listings)
	TipjarScreen:SetLoading(false)

	if payload.ownerPreview or self:IsOwnerViewing() then
		TipjarScreen:SetStatus("Click a tier to toggle its visibility", "info")
	else
		TipjarScreen:SetStatus("Select a tier to donate", "info")
	end

	self.PendingRequestTarget = nil
end

function TipjarController:GetCacheEntry(targetUserId)
	local entry = self.Cache[targetUserId]
	if not entry then
		return nil
	end

	if entry.expires and entry.expires <= os.clock() then
		self.Cache[targetUserId] = nil
		return nil
	end

	return entry
end

function TipjarController:PreviewOwnTipjar()
	local userId = LocalPlayer.UserId
	local cached = self.Cache[userId]

	self:ShowTipjar(userId, {
		target = cached and cached.target or {
			userId = userId,
			name = self:GetDisplayName(userId),
		},
		ledger = cached and cached.ledger or nil,
		listings = cached and cached.listings or nil,
		forceRefresh = true,
		status = {
			text = "Previewing your tip jar listings",
			kind = "info",
		},
	})
end

function TipjarController:InitOwnerEquipBindings()
	table.insert(self.Connections, ContextActionService.LocalToolEquipped:Connect(function(tool)
		self:OnLocalToolEquipped(tool)
	end))

	table.insert(self.Connections, ContextActionService.LocalToolUnequipped:Connect(function(tool)
		self:OnLocalToolUnequipped(tool)
	end))
end

function TipjarController:IsTipjarTool(tool)
	return tool and tool:IsA("Tool") and CollectionService:HasTag(tool, "Tipjar")
end

function TipjarController:OnLocalToolEquipped(tool)
	if not self:IsTipjarTool(tool) then
		return
	end

	self:PreviewOwnTipjar()
end

function TipjarController:OnLocalToolUnequipped(tool)
	if not self:IsTipjarTool(tool) then
		return
	end

	if self:IsOwnerViewing() then
		self:Hide("TipjarToolUnequipped")
	end
end

function TipjarController:PromptDonation(listing)
	if not listing or not listing.Id then
		return
	end

	if not self.CurrentTargetUserId then
		return
	end

	if self:IsOwnerViewing() then
		self:ToggleListingVisibility(listing)
		return
	end

	if listing.Owned then
		TipjarScreen:SetStatus("You already own that product", "info")
		return
	end

	self.PendingListingId = listing.Id

	self.PromptDonationEvent:Fire({
		targetUserId = self.CurrentTargetUserId,
		listingId = listing.Id,
		productType = listing.ProductType,
	})

	TipjarScreen:SetStatus("Confirm the Robux transfer prompt", "info")
end

function TipjarController:GetListingKey(listingId, productType)
	return string.format("%s_%s", tostring(productType or "GamePass"), tostring(listingId))
end

function TipjarController:ToggleListingVisibility(listing)
	if not listing or not listing.Id then
		return
	end

	local key = self:GetListingKey(listing.Id, listing.ProductType)
	self.PendingVisibility = self.PendingVisibility or {}
	if self.PendingVisibility[key] then
		return
	end

	local currentlyVisible = listing.Visible ~= false
	local desiredVisible = not currentlyVisible

	self.PendingVisibility[key] = true
	TipjarScreen:SetListingPending(listing.Id, listing.ProductType, true)
	TipjarScreen:SetStatus(desiredVisible and "Making listing visible..." or "Hiding listing from visitors...", "info")

	self.ToggleListingVisibilityEvent:Fire({
		listingId = listing.Id,
		productType = listing.ProductType,
		visible = desiredVisible,
	})
end


function TipjarController:OnDonationResult(success, payload)
	if not payload then
		return
	end

	local state = payload.state
	if payload.ledger and payload.targetUserId then
		local cached = self.Cache[payload.targetUserId] or {}
		cached.ledger = payload.ledger
		cached.target = cached.target or payload.target
		cached.expires = os.clock() + 30
		self.Cache[payload.targetUserId] = cached
	end

	if state == "DonationReceived" then
		self:HandleOwnerDonation(payload)
		return
	end

	local viewingTarget = payload.targetUserId or self.CurrentTargetUserId
	local isViewing = viewingTarget and self:IsViewing(viewingTarget)

	if not success then
		if isViewing then
			TipjarScreen:SetStatus(payload.message or "Donation could not be completed", "error")
		elseif payload.message then
			UI.Notify(payload.message, "Warning", 4)
		end
		return
	end

	if state == "TransferPrompted" or state == "PromptAccepted" then
		if isViewing then
			TipjarScreen:SetStatus("Waiting for the Robux transfer to settle", "info")
		end
		return
	end

	if state == "TransferSettled" then
		if isViewing then
			TipjarScreen:SetStatus("Transfer confirmed", "success")
		end
		return
	end

	if state == "PurchaseComplete" then
		if isViewing then
			if payload.ledger then
				TipjarScreen:SetLedger(payload.ledger)
			end
			TipjarScreen:SetStatus("Thank you for the donation!", "success")
		else
			local targetName = viewingTarget and self:GetCachedTargetName(viewingTarget) or "that creator"
			UI.Notify(string.format("Thanks for tipping %s!", targetName), "Success", 4)
		end
		return
	end

	if payload.message then
		if isViewing then
			TipjarScreen:SetStatus(payload.message, "info")
		else
			UI.Notify(payload.message, "Info", 4)
		end
	end
end

function TipjarController:ApplyListingVisibility(targetUserId, listingId, productType, visible)
	local cache = self.Cache[targetUserId]
	if cache and cache.listings then
		for _, entry in ipairs(cache.listings) do
			if entry.Id == listingId and entry.ProductType == productType then
				entry.Visible = visible ~= false
				break
			end
		end
	end

	if self:IsViewing(targetUserId) then
		TipjarScreen:SetListingPending(listingId, productType, false)
		TipjarScreen:SetListingVisibility(listingId, productType, visible)
	end
end

function TipjarController:OnVisibilityResult(success, payload)
	if not payload or not payload.listingId then
		return
	end

	local targetUserId = payload.targetUserId or LocalPlayer.UserId
	local listingId = payload.listingId
	local productType = payload.productType or "GamePass"
	local key = self:GetListingKey(listingId, productType)
	if self.PendingVisibility and self.PendingVisibility[key] then
		self.PendingVisibility[key] = nil
	end

	if not success then
		TipjarScreen:SetListingPending(listingId, productType, false)
		if self:IsOwnerViewing() then
			TipjarScreen:SetStatus(payload.message or "Unable to update listing visibility", "error")
		else
			UI.Notify(payload.message or "Unable to update listing visibility", "Warning", 3)
		end
		return
	end

	self:ApplyListingVisibility(targetUserId, listingId, productType, payload.visible ~= false)

	if self:IsOwnerViewing() then
		TipjarScreen:SetStatus((payload.visible ~= false) and "Listing is now visible" or "Listing hidden from visitors", "success")
	end
end

function TipjarController:HandleOwnerDonation(payload)
	local donorName = payload.donor and payload.donor.name or "A player"
	local amountText = formatAmount(payload.listing and payload.listing.Price)

	UI.Notify(string.format("%s tipped you %s!", donorName, amountText), "Success", 5)

	if payload.listing and payload.targetUserId then
		self:SetCachedListingOwned(payload.targetUserId, payload.listing.Id, payload.listing.ProductType)
	end

	if payload.ledger then
		local cached = self.Cache[LocalPlayer.UserId] or {}
		cached.ledger = payload.ledger
		cached.target = cached.target or {userId = LocalPlayer.UserId, name = self:GetDisplayName(LocalPlayer.UserId)}
		cached.expires = os.clock() + 30
		self.Cache[LocalPlayer.UserId] = cached
	end
end

function TipjarController:OnActivityFeed(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.ledger then
		local ownerId = LocalPlayer.UserId
		local cached = self.Cache[ownerId] or {}
		cached.ledger = payload.ledger
		cached.expires = os.clock() + 30
		self.Cache[ownerId] = cached
	end

	if not self:IsViewing(LocalPlayer.UserId) then
		return
	end

	if payload.ledger then
		TipjarScreen:SetLedger(payload.ledger)
	end

	TipjarScreen:PushActivity({
		donorName = payload.donor and payload.donor.name,
		donorUserId = payload.donor and payload.donor.userId,
		amount = payload.listing and payload.listing.Price,
	})

	local donorName = payload.donor and payload.donor.name or "A player"
	TipjarScreen:SetStatus(string.format("%s just tipped you %s!", donorName, formatAmount(payload.listing and payload.listing.Price)), "success")
end

function TipjarController:SetCachedListingOwned(targetUserId, listingId, productType)
	if not targetUserId or not listingId then
		return
	end

	local cache = self.Cache[targetUserId]
	if not cache or not cache.listings then
		return
	end

	for _, listing in ipairs(cache.listings) do
		if listing.Id == listingId and (not productType or listing.ProductType == productType) then
			listing.Owned = true
			break
		end
	end
end

function TipjarController:OnScreenClosed()
	self.CurrentTargetUserId = nil
	self.CurrentTarget = nil
	self.PendingListingId = nil
	self.PendingVisibility = nil
	self.PendingAddListing = false
end

function TipjarController:Hide(reason)
	if TipjarScreen and TipjarScreen.Hide then
		TipjarScreen.Hide(reason)
	end
	self:OnScreenClosed(reason)
end

return TipjarController
