local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local remote = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("OpenBundleShowcase")
local bundleAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Bundle")
local config = require(bundleAssets:WaitForChild("BundleConfig"))
local bundles = config.Bundles
local showRoom = bundleAssets:WaitForChild("ShowRoom")
local shopBundleTemplate = bundleAssets:WaitForChild("ShopBundle")
local bundleItemTemplate = bundleAssets:WaitForChild("BundleItem")
local knifeSkins = ReplicatedStorage:WaitForChild("KnifeSkins")
local knifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local stock = require(ReplicatedStorage:WaitForChild("SparkMod"):WaitForChild("Stock"))
stock:Init()

local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local purchaseRequest = gameRemotes:WaitForChild("BundlePurchaseRequest")
local purchaseResolved = gameRemotes:WaitForChild("BundlePurchaseResolved")
local ownershipUpdate = gameRemotes:WaitForChild("BundleOwnershipUpdate")
local getOwnership = gameRemotes:WaitForChild("GetBundleOwnership")

local gui = playerGui:WaitForChild("BundleShowcase")
local frame = gui:WaitForChild("Frame")
local bundleList = frame:WaitForChild("Bottom"):WaitForChild("Main")
local itemList = frame:WaitForChild("BuyHorizontalContainer"):WaitForChild("List")
local buyContainer = frame.BuyHorizontalContainer
local buyButton = buyContainer:WaitForChild("BuyHorizontal")
local closeButton = frame:WaitForChild("Close")
local giftButton = buyContainer:FindFirstChild("Gift")

frame.Bottom.Title.Text = "Each bundle includes a knife, kill effect, and pose!"
if giftButton then giftButton.Visible = false end

local isOpen = false
local selectedBundleId = 1
local previewModel
local lobbyPreviewModel
local previousCameraType
local previousCameraSubject
local previousCameraCFrame
local previousFieldOfView
local disabledGuis = {}
local bundleButtons = {}
local ownedBundles = {}
local purchasePending = false
local priceCache = {}

local function setCoreGuiEnabled(enabled)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
	end)
end

local function clearGenerated(container)
	for _, child in container:GetChildren() do
		if child:GetAttribute("BundleGenerated") then
			child:Destroy()
		end
	end
end

local function cloneKnifePreview(knifeId, spawnPart, parent)
	local skin = knifeSkinManager.getSkin(knifeId)
	if not skin then return nil end
	local tool = knifeSkins:FindFirstChild(skin.template)
	local sourceHandle = tool and tool:FindFirstChild("Handle")
	if not sourceHandle or not sourceHandle:IsA("BasePart") then return nil end

	local model = Instance.new("Model")
	model.Name = "BundleKnifePreview"
	local handle = sourceHandle:Clone()
	handle.Name = "Handle"
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	for _, descendant in handle:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	handle.Parent = model
	model.PrimaryPart = handle
	model.Parent = parent

	local _, size = model:GetBoundingBox()
	local lift = math.max(1.5, size.Y * 0.55)
	model:PivotTo(spawnPart.CFrame * CFrame.new(0, lift, 0) * CFrame.Angles(math.rad(20), math.rad(135), math.rad(-25)))
	return model
end

local function priceText(bundleData)
	if type(bundleData.ProductId) ~= "number" or bundleData.ProductId <= 0 then
		return "NOT CONFIGURED"
	end
	if priceCache[bundleData.ProductId] then return priceCache[bundleData.ProductId] end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, bundleData.ProductId, Enum.InfoType.Product)
	if ok and info and type(info.PriceInRobux) == "number" then
		priceCache[bundleData.ProductId] = utf8.char(0xE002) .. " " .. tostring(info.PriceInRobux)
		return priceCache[bundleData.ProductId]
	end
	return bundleData.PriceText or "BUY"
end

local function stockText(bundleData)
	if type(bundleData.ProductId) ~= "number" or bundleData.ProductId <= 0 then
		return "NOT CONFIGURED", true
	end
	local state = stock:GetItem(bundleData.StockEventId)
	if not state then return "STOCK LOADING", false end
	if state.infinite then return "AVAILABLE", false end
	if state.depleted or (state.current or 0) <= 0 then return "SOLD OUT", true end
	return tostring(state.current or 0) .. "/" .. tostring(state.total or 0) .. " LEFT", false
end

local function updatePhysicalBoard(bundleData)
	local physical = workspace:FindFirstChild("Bundle")
	local board = physical and physical:FindFirstChild("ShowRoom") and physical.ShowRoom:FindFirstChild("Board")
	if not board then return end
	board.Top.Text = string.upper(bundleData.Name)
	local duplicateTop = board.Top:FindFirstChild("Top")
	if duplicateTop then duplicateTop.Text = string.upper(bundleData.Name) end
	board.Rarity.Text = "3 EXCLUSIVE REWARDS"
	board.Rarity.TextColor3 = bundleData.AccentColor
	local text = stockText(bundleData)
	board.Stock.Visible = true
	board.Stock.Label.Text = text
	board.TimerHolder.Visible = false
end

local function showPhysicalBundle(bundleId)
	local physical = workspace:FindFirstChild("Bundle")
	local bundleData = bundles[bundleId]
	if not physical or not bundleData then return end
	if lobbyPreviewModel then lobbyPreviewModel:Destroy() end
	lobbyPreviewModel = cloneKnifePreview(bundleData.KnifeId, physical:WaitForChild("PenguinSpawn"), physical)
	updatePhysicalBoard(bundleData)
	local prompt = physical:FindFirstChild("Podium") and physical.Podium:FindFirstChild("Attachment") and physical.Podium.Attachment:FindFirstChild("ProximityPrompt")
	if prompt then prompt:SetAttribute("BundleId", bundleId) end
end

local function updateSelection(bundleId)
	local bundleData = bundles[bundleId]
	if not bundleData then return end
	selectedBundleId = bundleId

	for id, button in pairs(bundleButtons) do
		local stroke = button:FindFirstChild("SelectedStroke")
		if stroke then stroke.Visible = id == bundleId end
	end

	clearGenerated(itemList)
	for index, item in ipairs(bundleData.Items) do
		local card = bundleItemTemplate:Clone()
		card.Name = `BundleItem_{index}`
		card:SetAttribute("BundleGenerated", true)
		card.LayoutOrder = index
		card.Title.Text = item.Name
		card.ItemType.Text = string.upper(item.Type)
		card.ItemIcon.Image = ""
		card.ItemIcon.BackgroundTransparency = 0
		card.ItemIcon.BackgroundColor3 = bundleData.AccentColor
		card.View.Visible = false
		card.Parent = itemList
	end

	buyContainer.Title.Text = bundleData.Name
	local stockLabel, unavailable = stockText(bundleData)
	buyButton.RobuxText.Text = priceText(bundleData)
	buyButton.Interactable = not unavailable and not purchasePending and not ownedBundles[tostring(bundleId)]
	buyButton.Active = buyButton.Interactable
	buyContainer.PurchasedOverlay.Visible = ownedBundles[tostring(bundleId)] == true
	frame.LimitedQuantityTag.Visible = true
	frame.LimitedQuantityTag.Title.Text = unavailable and "STATUS" or "LIMITED STOCK"
	frame.LimitedQuantityTag.QuantityLabel.Text = stockLabel

	if previewModel then previewModel:Destroy() end
	previewModel = cloneKnifePreview(bundleData.KnifeId, showRoom:WaitForChild("PenguinSpawn"), showRoom)
end

local function buildCatalog()
	clearGenerated(bundleList)
	table.clear(bundleButtons)
	for bundleId, bundleData in pairs(bundles) do
		local card = shopBundleTemplate:Clone()
		card.Name = tostring(bundleId)
		card:SetAttribute("BundleGenerated", true)
		card.LayoutOrder = bundleData.Order or bundleId
		card.Active = true
		card.Interactable = true
		card.Selectable = true
		for _, descendant in card:GetDescendants() do
			if descendant:IsA("GuiButton") then
				descendant.Active = false
				descendant.Interactable = false
				descendant.Selectable = false
			end
		end
		card.Title.Text = bundleData.Name
		card.BG.Image = bundleData.Icon or ""
		card.BG.BackgroundTransparency = 0
		card.BG.BackgroundColor3 = bundleData.AccentColor
		card.PurchasedOverlay.Visible = ownedBundles[tostring(bundleId)] == true
		card.TimerHolder.Visible = true
		card.TimerHolder.Timer.Text = stockText(bundleData)
		card.Parent = bundleList
		bundleButtons[bundleId] = card
		card.Activated:Connect(function()
			updateSelection(bundleId)
		end)
	end
end

local function closeShowroom()
	if not isOpen then return end
	isOpen = false
	gui.Enabled = false
	if previewModel then previewModel:Destroy(); previewModel = nil end
	showRoom.Parent = bundleAssets

	for screenGui in pairs(disabledGuis) do
		if screenGui.Parent then screenGui.Enabled = true end
	end
	table.clear(disabledGuis)
	setCoreGuiEnabled(true)
	camera.CameraType = previousCameraType or Enum.CameraType.Custom
	camera.CameraSubject = previousCameraSubject
	camera.CFrame = previousCameraCFrame or camera.CFrame
	camera.FieldOfView = previousFieldOfView or 70
end

local function openShowroom(bundleId)
	if isOpen then
		if bundles[bundleId] then updateSelection(bundleId) end
		return
	end
	isOpen = true
	previousCameraType = camera.CameraType
	previousCameraSubject = camera.CameraSubject
	previousCameraCFrame = camera.CFrame
	previousFieldOfView = camera.FieldOfView

	table.clear(disabledGuis)
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child ~= gui and child.Enabled then
			child.Enabled = false
			disabledGuis[child] = true
		end
	end
	setCoreGuiEnabled(false)

	showRoom.Parent = workspace
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 40
	camera.CFrame = showRoom:WaitForChild("Camera").CFrame
	gui.Enabled = true
	local ok, result = pcall(function() return getOwnership:InvokeServer() end)
	if ok and type(result) == "table" then ownedBundles = result end
	buildCatalog()
	updateSelection(bundles[bundleId] and bundleId or selectedBundleId)
end

closeButton.Activated:Connect(closeShowroom)
buyButton.Activated:Connect(function()
	if purchasePending or ownedBundles[tostring(selectedBundleId)] then return end
	purchasePending = true
	updateSelection(selectedBundleId)
	purchaseRequest:FireServer(selectedBundleId)
end)

purchaseResolved.OnClientEvent:Connect(function(bundleId, ok, reason)
	purchasePending = false
	if ok then ownedBundles[tostring(bundleId)] = true end
	if isOpen then
		buildCatalog()
		updateSelection(selectedBundleId)
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = ok and "Bundle Purchased" or "Bundle Purchase",
			Text = ok and "Your bundle rewards were added to your inventory." or tostring(reason or "Purchase failed"),
			Duration = 4,
		})
	end)
end)

ownershipUpdate.OnClientEvent:Connect(function(updated)
	if type(updated) == "table" then ownedBundles = updated end
	if isOpen then buildCatalog(); updateSelection(selectedBundleId) end
end)

stock.Updated:Connect(function(eventId)
	if isOpen then buildCatalog(); updateSelection(selectedBundleId) end
	for _, bundleData in pairs(bundles) do
		if bundleData.StockEventId == eventId then updatePhysicalBoard(bundleData) end
	end
end)

remote.OnClientEvent:Connect(openShowroom)

local physical = workspace:FindFirstChild("Bundle")
if physical then
	local prompt = physical:FindFirstChild("Podium") and physical.Podium:FindFirstChild("Attachment") and physical.Podium.Attachment:FindFirstChild("ProximityPrompt")
	if prompt then
		prompt.ObjectText = "Bundles"
		prompt.ActionText = "Open"
		prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer == player then
				openShowroom(prompt:GetAttribute("BundleId") or 1)
			end
		end)
	end

	task.spawn(function()
		local ids = {}
		for id in pairs(bundles) do table.insert(ids, id) end
		table.sort(ids)
		local index = 1
		while physical.Parent do
			showPhysicalBundle(ids[index])
			index = index % #ids + 1
			task.wait(config.DisplayCycleSeconds or 12)
		end
	end)
end

player.CharacterAdded:Connect(function()
	if isOpen then closeShowroom() end
end)
