local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Stock = require(ServerScriptService:WaitForChild("SparkMod"):WaitForChild("Services"):WaitForChild("Stock"))
local BundleConfig =
	require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Bundle"):WaitForChild("BundleConfig"))

local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local purchaseRequest = remotes:WaitForChild("BundlePurchaseRequest")
local purchaseResolved = remotes:WaitForChild("BundlePurchaseResolved")
local ownershipUpdate = remotes:WaitForChild("BundleOwnershipUpdate")
local getOwnership = remotes:WaitForChild("GetBundleOwnership")

local RESERVATION_TTL_SECONDS = 150
local reservations = {}
local bundleByProductId = {}
local bundleByEventId = {}
local started = false

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local _DataService
local function dataSvc()
	if not _DataService then
		local ok, s = pcall(function()
			return Knit.GetService("DataService")
		end)
		if ok then
			_DataService = s
		end
	end
	return _DataService
end

local function invGetOwnedBundles(player)
	return dataSvc():GetOwnedBundles(player)
end
local function invOwnsBundle(player, bundleId)
	return dataSvc():OwnsBundle(player, bundleId)
end
local function invIsLoaded(player)
	return dataSvc():IsLoaded(player)
end
local function invGrantOnce(player, id)
	return dataSvc():GrantWeaponOnce(player, id, "none")
end
local function invAddKillEffect(player, id)
	return dataSvc():AddKillEffect(player, id)
end
local function invGrantPose(player, id)
	return dataSvc():GrantPose(player, id)
end
local function invMarkBundleOwned(player, bundleId, claimNumber)
	return dataSvc():MarkBundleOwned(player, bundleId, claimNumber)
end
local function invHasGrantedReceipt(player, purchaseId)
	return dataSvc():HasGrantedReceipt(player, purchaseId)
end

local LimitedBundleService = {}

local function reservationKey(userId, productId)
	return tostring(userId) .. ":" .. tostring(productId)
end

local function getBundle(bundleId)
	return BundleConfig.Bundles[tonumber(bundleId)]
end

local function configured(bundle)
	return bundle
		and type(bundle.ProductId) == "number"
		and bundle.ProductId > 0
		and type(bundle.StockEventId) == "string"
		and bundle.StockEventId ~= ""
end

local function ownedMap(player)
	local result = {}
	for key in pairs(invGetOwnedBundles(player)) do
		result[tostring(key)] = true
	end
	return result
end

local function sendOwnership(player)
	ownershipUpdate:FireClient(player, ownedMap(player))
end

-- Limited bundles use the same durable receipt boundary as normal products.
local function commitBundleReceipt(player, receiptInfo)
	local record = dataSvc():RecordReceipt(player, receiptInfo.PurchaseId, {
		ProductId = receiptInfo.ProductId,
		PurchaserUserId = receiptInfo.PlayerId,
		RecipientUserId = player.UserId,
		Source = "purchase",
		GrantState = "granted",
		FallbackState = "none",
	})
	return record ~= nil and dataSvc():CommitReceipt(player, receiptInfo.PurchaseId, 30) == true
end

local function grantBundle(player, bundleId, claimNumber, receiptInfo)
	local bundle = getBundle(bundleId)
	if not bundle then
		return false, "Unknown bundle"
	end
	if invOwnsBundle(player, bundleId) then
		return true
	end
	if not invIsLoaded(player) then
		return false, "Inventory is not loaded"
	end

	local ok, err = pcall(function()
		for _, item in ipairs(bundle.Items or {}) do
			if item.Type == "Knife" then
				invGrantOnce(player, item.Id)
			elseif item.Type == "Kill Effect" then
				invAddKillEffect(player, item.Id)
			elseif item.Type == "Pose" then
				invGrantPose(player, item.Id)
			end
		end
		invMarkBundleOwned(player, bundleId, claimNumber)
		if not commitBundleReceipt(player, receiptInfo) then
			error("Receipt commit did not persist")
		end
	end)
	if not ok then
		return false, tostring(err)
	end

	sendOwnership(player)
	return true
end

function LimitedBundleService.ProcessReceipt(receiptInfo)
	local bundleId = bundleByProductId[receiptInfo.ProductId]
	if not bundleId then
		return nil
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if invHasGrantedReceipt(player, receiptInfo.PurchaseId) or invOwnsBundle(player, bundleId) then
		return if commitBundleReceipt(player, receiptInfo)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local bundle = getBundle(bundleId)
	local key = reservationKey(player.UserId, receiptInfo.ProductId)
	local reservation = reservations[key]
	reservations[key] = nil
	local claimNumber = 0

	if reservation then
		local committed, result = Stock:CommitReservation(reservation.id, player)
		if committed and type(result) == "table" then
			claimNumber = tonumber(result.claimNumber) or 0
		else
			-- Robux has already been charged. Attempt an authoritative claim, but always honour delivery.
			local claimOk, claimErr = Stock:Claim(bundle.StockEventId, player)
			if not claimOk then
				warn("[LimitedBundleService] stock fallback claim failed after charge:", claimErr)
			end
		end
	else
		-- Receipt may retry on a different server. Claim authoritatively, then honour the paid purchase.
		local claimOk, claimErr = Stock:Claim(bundle.StockEventId, player)
		if not claimOk then
			warn("[LimitedBundleService] receipt had no reservation; stock claim failed:", claimErr)
		end
	end

	local granted, reason = grantBundle(player, bundleId, claimNumber, receiptInfo)
	if not granted then
		warn("[LimitedBundleService] grant failed; receipt will retry:", reason)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	purchaseResolved:FireClient(player, bundleId, true)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function requestPurchase(player, bundleId)
	bundleId = tonumber(bundleId)
	local bundle = getBundle(bundleId)
	if not bundle then
		purchaseResolved:FireClient(player, bundleId, false, "Unknown bundle")
		return
	end
	if not configured(bundle) then
		purchaseResolved:FireClient(player, bundleId, false, "Product ID is not configured yet")
		return
	end
	if invOwnsBundle(player, bundleId) then
		purchaseResolved:FireClient(player, bundleId, false, "You already own this bundle")
		return
	end
	if not invIsLoaded(player) then
		purchaseResolved:FireClient(player, bundleId, false, "Inventory is still loading")
		return
	end

	local status = Stock:GetStatus(bundle.StockEventId)
	if status and not status.infinite and (status.depleted or status.current <= 0) then
		purchaseResolved:FireClient(player, bundleId, false, "Sold out")
		return
	end

	local key = reservationKey(player.UserId, bundle.ProductId)
	if reservations[key] then
		purchaseResolved:FireClient(player, bundleId, false, "Purchase already in progress")
		return
	end

	local ok, result = Stock:Reserve(bundle.StockEventId, player, { ttlSeconds = RESERVATION_TTL_SECONDS })
	if not ok or type(result) ~= "table" or type(result.id) ~= "string" then
		purchaseResolved:FireClient(player, bundleId, false, tostring(result or "Stock service unavailable"))
		return
	end
	reservations[key] = { id = result.id, bundleId = bundleId }
	MarketplaceService:PromptProductPurchase(player, bundle.ProductId)
end

function LimitedBundleService.Start()
	if started then
		return
	end
	started = true
	for bundleId, bundle in pairs(BundleConfig.Bundles) do
		if configured(bundle) then
			bundleByProductId[bundle.ProductId] = bundleId
			bundleByEventId[bundle.StockEventId] = bundleId
		end
	end

	purchaseRequest.OnServerEvent:Connect(requestPurchase)
	getOwnership.OnServerInvoke = function(player)
		local waited = 0
		while not invIsLoaded(player) and waited < 12 do
			task.wait(0.25)
			waited += 0.25
		end
		return ownedMap(player)
	end

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if purchased then
			return
		end
		local key = reservationKey(userId, productId)
		local reservation = reservations[key]
		if not reservation then
			return
		end
		reservations[key] = nil
		task.spawn(function()
			Stock:CancelReservation(reservation.id)
		end)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			purchaseResolved:FireClient(player, reservation.bundleId, false, "Cancelled")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for key, reservation in pairs(reservations) do
			if string.find(key, tostring(player.UserId) .. ":", 1, true) == 1 then
				reservations[key] = nil
				task.spawn(function()
					Stock:CancelReservation(reservation.id)
				end)
			end
		end
	end)
end

return LimitedBundleService
