local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")

local Players = game.Players
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)
local UserProfile = require(ReplicatedStorage.Runtime.Source.UserProfile)
local SoundHandler = Mince:Get("SoundHandler")

local Store = {}

Store.RobuxPriceCache = {}
Store.RobuxPricePending = {}
Store.EcoSymbol = "♻"
Store.EcoBalance = 0
Store.DefaultDock = "Left"
Store.DockLayouts = {
	Left = {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.02, 0.52),
		Size = UDim2.fromScale(0.44, 0.88),
	},
}

local CATEGORY_COLORS = {
	Gear = Color3.fromRGB(26, 111, 255),
	Tools = Color3.fromRGB(255, 201, 39),
	Cosmetics = Color3.fromRGB(39, 209, 173),
	TanksAndBCD = Color3.fromRGB(96, 172, 255),
	Masks = Color3.fromRGB(114, 207, 223),
	Fins = Color3.fromRGB(88, 188, 255),
	Suits = Color3.fromRGB(159, 139, 255),
}

local STORE_VIEW_CATEGORIES = {
	TanksAndBCD = {
		DisplayName = "Tanks / BCD",
		Slots = { Harness = true },
	},
	Masks = {
		DisplayName = "Masks",
		Slots = { DiveMask = true },
	},
	Fins = {
		DisplayName = "Fins",
		Slots = { Fins = true },
	},
	Suits = {
		DisplayName = "Suits",
		Slots = { Hat = true },
	},
	Tools = {
		DisplayName = "Tools",
		Slots = { Tool = true, Plushie = true },
	},
}

local STORE_VIEW_CATEGORY_ORDER = { "TanksAndBCD", "Masks", "Fins", "Suits", "Tools" }
local ITEM_CARD_REST_SCALE = 0.98
local ITEM_CARD_HOVER_SCALE = 1
local DETAIL_VIEWPORT_ROTATION_SPEED = math.rad(28)
local BUTTON_HOVER_SCALE = 1.035
local BUTTON_PRESS_SCALE = 0.965
local DETAIL_PURCHASE_COLOR = Color3.fromRGB(30, 90, 168)
local DETAIL_EQUIP_COLOR = Color3.fromRGB(42, 168, 108)
local DETAIL_UNEQUIP_COLOR = Color3.fromRGB(205, 82, 76)
local DETAIL_ROBUX_COLOR = Color3.fromRGB(104, 255, 37)
local DETAIL_DISABLED_COLOR = Color3.fromRGB(91, 98, 110)
local DETAIL_DISABLED_CONTENT_COLOR = Color3.fromRGB(169, 175, 185)
local PURCHASE_EFFECT_COLOR = Color3.fromRGB(54, 214, 137)
local MERCHANT_MUSIC_SOURCE = "Merchant"
local MERCHANT_MUSIC_DUCK_SCALE = 0.28

local function playUiSound(soundName)
	if SoundHandler then
		SoundHandler:PlaySound(soundName)
	end
end

local function startMerchantMusic()
	if SoundHandler and SoundHandler.BeginMusicOverride then
		SoundHandler:BeginMusicOverride(MERCHANT_MUSIC_SOURCE, MERCHANT_MUSIC_DUCK_SCALE)
	end
end

local function stopMerchantMusic()
	if SoundHandler and SoundHandler.EndMusicOverride then
		SoundHandler:EndMusicOverride(MERCHANT_MUSIC_SOURCE)
	end
end

local function buildDescriptionText(itemData)
	local descText = itemData.ShortDescription or itemData.Description or ""
	return descText
end

local function getRarity(itemData)
	if Store.StoreItems and Store.StoreItems.GetRarity then
		return Store.StoreItems.GetRarity(itemData)
	end

	local rarityName = itemData.Rarity or "Common"
	return nil, rarityName
end

local function applyRarity(label, itemData)
	if not label then
		return
	end

	local rarity, rarityName = getRarity(itemData)
	label.Text = (rarity and rarity.Text) or rarityName
	label.TextColor3 = (rarity and rarity.PrimaryColor) or Color3.new(1, 1, 1)
end

local function setMuted(root, muted)
	if not root then
		return
	end

	local objects = { root }
	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(objects, descendant)
	end

	for _, object in ipairs(objects) do
		if object:IsA("GuiObject") and object.BackgroundTransparency < 1 then
			local originalColor = object:GetAttribute("StoreOriginalBackgroundColor")
			local originalTransparency = object:GetAttribute("StoreOriginalBackgroundTransparency")
			if originalColor == nil then
				originalColor = object.BackgroundColor3
				object:SetAttribute("StoreOriginalBackgroundColor", originalColor)
			end
			if originalTransparency == nil then
				originalTransparency = object.BackgroundTransparency
				object:SetAttribute("StoreOriginalBackgroundTransparency", originalTransparency)
			end
			object.BackgroundColor3 = muted and originalColor:Lerp(DETAIL_DISABLED_COLOR, 0.75) or originalColor
			object.BackgroundTransparency = muted and math.min(1, originalTransparency + 0.15) or originalTransparency
		end

		if object:IsA("TextLabel") then
			local originalColor = object:GetAttribute("StoreOriginalTextColor")
			local originalTransparency = object:GetAttribute("StoreOriginalTextTransparency")
			if originalColor == nil then
				originalColor = object.TextColor3
				object:SetAttribute("StoreOriginalTextColor", originalColor)
			end
			if originalTransparency == nil then
				originalTransparency = object.TextTransparency
				object:SetAttribute("StoreOriginalTextTransparency", originalTransparency)
			end
			object.TextColor3 = muted and DETAIL_DISABLED_CONTENT_COLOR or originalColor
			object.TextTransparency = muted and math.max(originalTransparency, 0.2) or originalTransparency
		elseif object:IsA("ImageLabel") then
			local originalColor = object:GetAttribute("StoreOriginalImageColor")
			local originalTransparency = object:GetAttribute("StoreOriginalImageTransparency")
			if originalColor == nil then
				originalColor = object.ImageColor3
				object:SetAttribute("StoreOriginalImageColor", originalColor)
			end
			if originalTransparency == nil then
				originalTransparency = object.ImageTransparency
				object:SetAttribute("StoreOriginalImageTransparency", originalTransparency)
			end
			object.ImageColor3 = muted and DETAIL_DISABLED_CONTENT_COLOR or originalColor
			object.ImageTransparency = muted and math.max(originalTransparency, 0.2) or originalTransparency
		end
	end
end

function Store.BindButtonFeedback(button)
	if not button or not button:IsA("GuiButton") or button:GetAttribute("StoreFeedbackBound") then
		return
	end
	button:SetAttribute("StoreFeedbackBound", true)

	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "StoreFeedbackScale"
		scale.Parent = button
	end

	local restScale = scale.Scale
	local hovered = false
	local activeTween
	local function tweenTo(targetScale, duration)
		if activeTween then
			activeTween:Cancel()
		end
		activeTween = TweenService:Create(
			scale,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = targetScale }
		)
		activeTween:Play()
	end

	table.insert(
		Store.Connections,
		button.MouseEnter:Connect(function()
			hovered = true
			tweenTo(button.Interactable and restScale * BUTTON_HOVER_SCALE or restScale, 0.09)
			if button.Interactable then
				playUiSound("ButtonHover")
			end
		end)
	)
	table.insert(
		Store.Connections,
		button.MouseLeave:Connect(function()
			hovered = false
			tweenTo(restScale, 0.09)
		end)
	)
	table.insert(
		Store.Connections,
		button.MouseButton1Down:Connect(function()
			if button.Interactable then
				tweenTo(restScale * BUTTON_PRESS_SCALE, 0.055)
				playUiSound("ClickDown")
			end
		end)
	)
	table.insert(
		Store.Connections,
		button.MouseButton1Up:Connect(function()
			tweenTo(hovered and button.Interactable and restScale * BUTTON_HOVER_SCALE or restScale, 0.09)
			if button.Interactable then
				playUiSound("ClickUp")
			end
		end)
	)
end

function Store.SetCategoryNotification(categoryName, enabled)
	local categoryButton = Store.Categories and Store.Categories[categoryName]
	if not categoryButton then
		return
	end

	enabled = enabled == true
	if categoryButton:GetAttribute("NotificationEnabled") ~= enabled then
		categoryButton:SetAttribute("NotificationEnabled", enabled)
	end

	local dot = categoryButton:FindFirstChild("NotificationDot")
	if not dot or not dot:IsA("GuiObject") then
		return
	end

	Store.CategoryNotificationTweens = Store.CategoryNotificationTweens or {}
	local existingTweens = Store.CategoryNotificationTweens[categoryName]
	if existingTweens then
		for _, tween in ipairs(existingTweens) do
			tween:Cancel()
		end
		Store.CategoryNotificationTweens[categoryName] = nil
	end

	local scale = dot:FindFirstChild("NotificationPulseScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "NotificationPulseScale"
		scale.Parent = dot
	end
	scale.Scale = 1

	local baseTransparency = dot:GetAttribute("NotificationBaseTransparency")
	if baseTransparency == nil then
		baseTransparency = dot.BackgroundTransparency
		dot:SetAttribute("NotificationBaseTransparency", baseTransparency)
	end
	dot.BackgroundTransparency = baseTransparency
	dot.Visible = enabled

	if not enabled then
		return
	end

	local pulseInfo = TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local scaleTween = TweenService:Create(scale, pulseInfo, { Scale = 1.3 })
	local fadeTween = TweenService:Create(dot, pulseInfo, {
		BackgroundTransparency = math.min(1, baseTransparency + 0.28),
	})
	Store.CategoryNotificationTweens[categoryName] = { scaleTween, fadeTween }
	scaleTween:Play()
	fadeTween:Play()
end

function Store.SetCategoryNotifications(notificationStates)
	for categoryName, enabled in pairs(notificationStates or {}) do
		Store.SetCategoryNotification(categoryName, enabled)
	end
end

function Store.PlayPurchaseEffect(itemName)
	if not Store.Gui or not Store.Gui.Enabled then
		return
	end

	playUiSound("NotifSound")

	local target
	for _, card in ipairs(Store.LoadedBoxes or {}) do
		if card and card.Parent and card.Name == itemName then
			target = card
			break
		end
	end
	target = target or Store.DetailPrimaryAction
	if not target or not target:IsA("GuiObject") then
		return
	end

	local previousEffect = target:FindFirstChild("PurchaseSuccessEffect")
	if previousEffect then
		previousEffect:Destroy()
	end

	local effect = Instance.new("Frame")
	effect.Name = "PurchaseSuccessEffect"
	effect.Size = UDim2.fromScale(1, 1)
	effect.BackgroundColor3 = PURCHASE_EFFECT_COLOR
	effect.BackgroundTransparency = 0.18
	effect.BorderSizePixel = 0
	effect.ZIndex = target.ZIndex + 20
	effect.Parent = target

	local targetCorner = target:FindFirstChildOfClass("UICorner")
	local corner = Instance.new("UICorner")
	corner.CornerRadius = targetCorner and targetCorner.CornerRadius or UDim.new(0, 10)
	corner.Parent = effect

	local label = Instance.new("TextLabel")
	label.Name = "PurchasedLabel"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -16, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "PURCHASED"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 17
	label.TextTransparency = 0
	label.ZIndex = effect.ZIndex + 1
	label.Parent = effect

	local effectScale = Instance.new("UIScale")
	effectScale.Scale = 0.88
	effectScale.Parent = effect

	local targetScale = target:FindFirstChildOfClass("UIScale")
	local targetRestScale = targetScale and targetScale.Scale
	if targetScale then
		TweenService:Create(
			targetScale,
			TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = targetRestScale * 1.045 }
		):Play()
	end

	TweenService
		:Create(effectScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	task.delay(0.18, function()
		if targetScale and targetScale.Parent then
			TweenService:Create(
				targetScale,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = targetRestScale }
			):Play()
		end
	end)

	task.delay(0.38, function()
		if effect.Parent then
			TweenService:Create(effect, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
		end
	end)

	task.delay(0.65, function()
		effect:Destroy()
	end)
end

function Store:GetItemCategory(itemName)
	for categoryName, items in pairs(Store.StoreItems and Store.StoreItems.Categories or {}) do
		if items[itemName] then
			return categoryName
		end
	end
	return nil
end

function Store:GetItemNameForAssetId(assetId)
	for _, items in pairs(Store.StoreItems and Store.StoreItems.Categories or {}) do
		for itemName, itemData in pairs(items) do
			if itemData.RobuxAssetId == assetId or itemData.AssetId == assetId then
				return itemName
			end
		end
	end
	return nil
end

function Store:GetCurrencyConfig(itemName)
	if Store:GetItemCategory(itemName) == "Cosmetics" then
		return {
			prefix = Store.EcoSymbol,
			name = "EcoPoints",
			short = Store.EcoSymbol,
		}
	end

	return {
		prefix = "$",
		name = "coins",
		short = "$",
	}
end

function Store:GetCosmeticViewportObject(itemName)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cosmetics = assets and assets:FindFirstChild("Cosmetics")
	if not cosmetics then
		return nil
	end

	local found = cosmetics:FindFirstChild(itemName, true)
	if found and found:IsA("Accessory") then
		return found
	end

	return nil
end

function Store:GetViewCategoryItems(viewCategory)
	local definition = STORE_VIEW_CATEGORIES[viewCategory]
	if not definition or not Store.StoreItems then
		return {}
	end

	local items = {}
	for sourceCategory, categoryItems in pairs(Store.StoreItems.Categories or {}) do
		for itemName, itemData in pairs(categoryItems) do
			if not itemData.Hidden and definition.Slots[itemData.Slot] then
				table.insert(items, {
					Name = itemName,
					Data = itemData,
					Category = sourceCategory,
				})
			end
		end
	end

	table.sort(items, function(a, b)
		local rarityA = getRarity(a.Data)
		local rarityB = getRarity(b.Data)
		local rarityOrderA = rarityA and rarityA.Order or -1
		local rarityOrderB = rarityB and rarityB.Order or -1
		if rarityOrderA ~= rarityOrderB then
			return rarityOrderA < rarityOrderB
		end

		local orderA = a.Data.SortOrder or 1000
		local orderB = b.Data.SortOrder or 1000
		if orderA ~= orderB then
			return orderA < orderB
		end
		if (a.Data.Price or 0) ~= (b.Data.Price or 0) then
			return (a.Data.Price or 0) < (b.Data.Price or 0)
		end
		return a.Name < b.Name
	end)

	return items
end

function Store.Init(Interface)
	Store.Interface = Interface
	Store.Gui = PlayerGui:WaitForChild("StoreUI")

	if not Store.Gui then
		warn("StoreUI not found in PlayerGui")
		return
	end
	if Mince.CursorClickEffect then
		Mince.CursorClickEffect:SetTargetGui(Store.Gui)
	end
	-- StarterGui keeps the templates visible for edit-time authoring. The live
	-- client starts closed and generates categories/items only when requested.
	Store.Gui.Enabled = false

	Store.Connections = {}
	Store.LoadedBoxes = {}
	Store.CategoryCardCache = {}
	Store.CategoryBuildEvents = {}
	Store.CategoryTransitionId = 0
	Store.CardAccentColors = setmetatable({}, { __mode = "k" })
	Store.CardOverlayTweens = setmetatable({}, { __mode = "k" })
	Store.CardOverlaySizes = setmetatable({}, { __mode = "k" })
	Store.CardHoverStyles = setmetatable({}, { __mode = "k" })
	Store.CategoryNotificationTweens = {}

	Store.OwnedItems = {}
	Store.Balance = 0
	Store.EcoBalance = 0

	local storeComm = Mince:GetEvent("StoreEvents")
	Store.PurchaseRequest = storeComm:Extend("PurchaseRequest")
	Store.EquipRequest = storeComm:Extend("EquipRequest")
	Store.UnequipRequest = storeComm:Extend("UnequipRequest")
	Store.RequestInventory = storeComm:Extend("RequestInventory")
	Store.GiftRequest = storeComm:Extend("GiftRequest")

	local PurchaseResult = storeComm:Extend("PurchaseResult")
	PurchaseResult.Event:Connect(function(success, message, itemName)
		Store:OnPurchaseResult(success, message, itemName)
	end)

	local EquipResult = storeComm:Extend("EquipResult")
	EquipResult.Event:Connect(function(success, message, itemName)
		Store:OnEquipResult(success, message, itemName)
	end)

	local InventorySync = storeComm:Extend("InventorySync")
	InventorySync.Event:Connect(function(inventoryData)
		Store:UpdateInventory(inventoryData)
	end)

	local GearStatsUpdate = storeComm:Extend("GearStatsUpdate")
	GearStatsUpdate.Event:Connect(function(stats)
		Store.GearStats = stats
	end)

	local GiftResult = storeComm:Extend("GiftResult")
	GiftResult.Event:Connect(function(success, message)
		if Store.DetailStatus then
			Store.DetailStatus.Text = message or ""
			Store.DetailStatus.TextColor3 = success and Color3.fromRGB(39, 209, 173) or Color3.fromRGB(255, 110, 110)
		end
		if Store.Interface and Store.Interface.Notify then
			Store.Interface.Notify(message, success and "Success" or "Error", 4)
		end
		if success and Store.GiftPlayerList then
			Store.GiftPlayerList.Visible = false
		end
	end)

	MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
		if player == Players.LocalPlayer and isPurchased then
			local purchasedItemName = Store:GetItemNameForAssetId(assetId)
			Store.PlayPurchaseEffect(purchasedItemName or "ITEM UNLOCKED")
			if Store.Interface and Store.Interface.Notify then
				Store.Interface.Notify(`{purchasedItemName or "Item"} purchased!`, "Success", 3)
			end
			Store.RequestInventory:Fire()
		end
	end)

	Store.RequestInventory:Fire()

	Store.Cleanup = function()
		for _, conn in Store.Connections do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		Store.Connections = {}
		for _, tweens in pairs(Store.CategoryNotificationTweens or {}) do
			for _, tween in ipairs(tweens) do
				tween:Cancel()
			end
		end
		Store.CategoryNotificationTweens = {}
		stopMerchantMusic()
		Store._setOtherPlayersHidden(false)
	end

	Store.Main = Store.Gui:WaitForChild("Main")
	Store.MainContainer = Store.Main
	Store._captureDefaultLayout()
	Store.DetailPanel = Store.Gui:WaitForChild("ItemDetailsPanel")
	Store.DetailPanelTargetPosition = Store.DetailPanel.Position
	Store.DetailPanelTween = nil
	Store.DetailPanelScale = Store.DetailPanel:FindFirstChild("DetailPanelPoofScale")
	if not Store.DetailPanelScale then
		Store.DetailPanelScale = Instance.new("UIScale")
		Store.DetailPanelScale.Name = "DetailPanelPoofScale"
		Store.DetailPanelScale.Parent = Store.DetailPanel
	end
	Store.DetailPanelScale.Scale = 1
	Store.DetailPanel.Visible = false

	local storeContent = Store.Main:WaitForChild("StoreContent")
	local catalog = storeContent:WaitForChild("Catalog")
	Store.CategoryContainer = storeContent:WaitForChild("CategoryList")
	Store.ItemBox = catalog:WaitForChild("ItemList")
	Store.ShopBox = Store.ItemBox:WaitForChild("ItemCardTemplate")
	Store.ShopBox.Visible = false
	Store.ShopBox.Parent = nil
	Store.SearchInput = catalog:WaitForChild("SearchBar"):WaitForChild("SearchInput")
	Store.ExitButton = Store.Main:WaitForChild("Header"):WaitForChild("CloseButton")

	Store.Categories = {}
	for _, categoryId in ipairs(STORE_VIEW_CATEGORY_ORDER) do
		Store.Categories[categoryId] = Store.CategoryContainer:FindFirstChild(categoryId)
	end
	Store.CategoryButtonStyles = {}

	local detailsContent = Store.DetailPanel:WaitForChild("DetailsContent")
	local detailLayout = detailsContent:WaitForChild("DetailLayout")
	local detailHeader = Store.DetailPanel:WaitForChild("Header")
	Store.DetailViewport = detailLayout:WaitForChild("ItemPreview")
	Store.DetailInfo = detailLayout:WaitForChild("ItemInfo")
	Store.DetailPrices = detailLayout:WaitForChild("PriceList")
	Store.DetailActions = detailLayout:WaitForChild("PurchaseActions")
	Store.DetailCategoryTitle = detailHeader:WaitForChild("CategoryTitle")
	Store.DetailCategoryIcon = detailHeader:FindFirstChild("CategoryIcon")
	Store.DetailPrimaryAction = Store.DetailActions:WaitForChild("PurchaseButton")
	Store.DetailRobuxAction = Store.DetailActions:WaitForChild("RobuxPurchaseButton")
	Store.DetailCloseButton = detailHeader:WaitForChild("CloseButton")
	Store.BindButtonFeedback(Store.ExitButton)
	Store.BindButtonFeedback(Store.DetailCloseButton)
	Store.BindButtonFeedback(Store.DetailPrimaryAction)
	Store.BindButtonFeedback(Store.DetailRobuxAction)
	Store.DetailViewportRotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not Store.Gui.Enabled or not Store.DetailPanel.Visible or not Store.DetailViewport.Visible then
			return
		end

		local worldModel = Store.DetailViewport:FindFirstChildOfClass("WorldModel")
		if worldModel then
			worldModel:PivotTo(worldModel:GetPivot() * CFrame.Angles(0, DETAIL_VIEWPORT_ROTATION_SPEED * deltaTime, 0))
		end
	end)
	table.insert(Store.Connections, Store.DetailViewportRotationConnection)

	Store._scale = Store.Main:FindFirstChild("Scale") or Instance.new("UIScale")
	Store._scale.Name = "Scale"
	Store._scale.Scale = 1
	Store._scale.Parent = Store.Main
	Store._isVisible = false
	Store._activeTween = nil
	Store._activeTweenConnection = nil
	Store._otherPlayersHidden = false
	Store._otherPlayerVisibilityConnections = {}
	Store._otherPlayerVisibilityOriginals = {}
	Store._viewportUpdateAccumulator = 0

	Store.ExitButton.Activated:Connect(Store.Hide)
	Store.DetailCloseButton.Activated:Connect(function()
		Store.HideItemDetails()
	end)
	Store.DetailPrimaryAction.Activated:Connect(function()
		local selected = Store.SelectedItem
		if selected then
			Store:OnActionButtonClick(selected.Name, selected.Category, selected.Data)
		end
	end)
	Store.DetailRobuxAction.Activated:Connect(function()
		local selected = Store.SelectedItem
		local itemState = selected and Store.OwnedItems[selected.Name]
		if selected and not (itemState and itemState.Owned) then
			Store:PromptRobuxPurchase(selected.Data, selected.Name)
		end
	end)

	Store.StoreItems = Mince.Config.StoreItems

	if not Store.StoreItems then
		warn("StoreItems not found in Mince.Config")
	end

	UserProfile:Upon("Currency", function(currencyData)
		local newBalance = 0
		if currencyData then
			newBalance = currencyData.Balance or 0
		end
		Store.Balance = newBalance
	end)

	UserProfile:Upon("EcoPoints", function(ecoData)
		local newBalance = 0
		if ecoData then
			newBalance = ecoData.Balance or 0
		end
		Store.EcoBalance = newBalance
	end)

	Store.CurrentCategory = "TanksAndBCD"

	for categoryName, categoryButton in pairs(Store.Categories) do
		if categoryButton then
			local selectionAccent = categoryButton:FindFirstChild("SelectionAccent")
			local existingStroke = categoryButton:FindFirstChildOfClass("UIStroke")
			if not existingStroke then
				existingStroke = Instance.new("UIStroke")
				existingStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				existingStroke.Thickness = 2
				existingStroke.Parent = categoryButton
			end

			local label = categoryButton:FindFirstChildWhichIsA("TextLabel")
				or categoryButton:FindFirstChildWhichIsA("TextBox")
				or categoryButton:FindFirstChildWhichIsA("TextButton")
			local icon = categoryButton:FindFirstChildWhichIsA("ImageLabel")
			Store.CategoryButtonStyles[categoryName] = {
				BackgroundTransparency = categoryButton.BackgroundTransparency,
				BackgroundColor3 = categoryButton.BackgroundColor3,
				TextColor3 = categoryButton:IsA("TextButton") and categoryButton.TextColor3 or nil,
				Font = categoryButton:IsA("TextButton") and categoryButton.Font or nil,
				StrokeColor3 = existingStroke.Color,
				StrokeTransparency = existingStroke.Transparency,
				ImageColor3 = categoryButton:IsA("ImageButton") and categoryButton.ImageColor3 or nil,
				ImageTransparency = categoryButton:IsA("ImageButton") and categoryButton.ImageTransparency or nil,
				Label = label,
				LabelTextColor3 = label and label.TextColor3 or nil,
				LabelFont = label and label.Font or nil,
				Icon = icon,
				IconImageColor3 = icon and icon.ImageColor3 or nil,
				IconImageTransparency = icon and icon.ImageTransparency or nil,
				SelectionAccent = selectionAccent,
				SelectionAccentColor3 = selectionAccent and selectionAccent.BackgroundColor3 or nil,
			}

			local connection = categoryButton.Activated:Connect(function()
				Store.SetCategoryNotification(categoryName, false)
				Store.DisplayCategory(categoryName)
			end)
			table.insert(Store.Connections, connection)

			local notificationDot = categoryButton:FindFirstChild("NotificationDot")
			if notificationDot then
				local notificationEnabled = categoryButton:GetAttribute("NotificationEnabled")
				if notificationEnabled == nil then
					notificationEnabled = notificationDot.Visible
				end
				Store.SetCategoryNotification(categoryName, notificationEnabled)
				table.insert(
					Store.Connections,
					categoryButton:GetAttributeChangedSignal("NotificationEnabled"):Connect(function()
						Store.SetCategoryNotification(
							categoryName,
							categoryButton:GetAttribute("NotificationEnabled") == true
						)
					end)
				)
			end

			local buttonScale = categoryButton:FindFirstChild("UIScale")
			if not buttonScale then
				buttonScale = Instance.new("UIScale")
				buttonScale.Name = "UIScale"
				buttonScale.Scale = 1
				buttonScale.Parent = categoryButton
			end

			local hoverEnter = categoryButton.MouseEnter:Connect(function()
				playUiSound("ButtonHover")
				local style = Store.CategoryButtonStyles[categoryName]
				local isSelected = categoryButton:GetAttribute("IsSelected") == true
				local baseTransparency = style and style.BackgroundTransparency or categoryButton.BackgroundTransparency
				if isSelected then
					baseTransparency = math.max(0, baseTransparency - 0.1)
				end
				local hoverTween = TweenService:Create(
					categoryButton,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						BackgroundTransparency = math.max(0, baseTransparency - 0.2),
					}
				)
				local scaleTween = TweenService:Create(
					buttonScale,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1.025 }
				)
				hoverTween:Play()
				scaleTween:Play()
			end)

			table.insert(Store.Connections, hoverEnter)

			table.insert(
				Store.Connections,
				categoryButton.MouseButton1Down:Connect(function()
					if categoryButton.Interactable then
						playUiSound("ClickDown")
					end
				end)
			)
			table.insert(
				Store.Connections,
				categoryButton.MouseButton1Up:Connect(function()
					if categoryButton.Interactable then
						playUiSound("ClickUp")
					end
				end)
			)

			local hoverLeave = categoryButton.MouseLeave:Connect(function()
				local style = Store.CategoryButtonStyles[categoryName]
				local isSelected = categoryButton:GetAttribute("IsSelected") == true
				local baseTransparency = style and style.BackgroundTransparency or categoryButton.BackgroundTransparency
				local baseScale = isSelected and 1.01 or 1
				if isSelected then
					baseTransparency = math.max(0, baseTransparency - 0.1)
				end
				local leaveTween = TweenService:Create(
					categoryButton,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						BackgroundTransparency = baseTransparency,
					}
				)
				local scaleBackTween = TweenService:Create(
					buttonScale,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = baseScale }
				)
				leaveTween:Play()
				scaleBackTween:Play()
			end)
			table.insert(Store.Connections, hoverLeave)
		else
			warn("Category button not found:", categoryName)
		end
	end

	Store.SearchInput = Store.SearchInput or Store.MainContainer:FindFirstChild("Input", true)
	if Store.SearchInput and Store.SearchInput:IsA("TextBox") then
		table.insert(
			Store.Connections,
			Store.SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
				local query = string.lower(Store.SearchInput.Text)
				for _, shopBox in ipairs(Store.LoadedBoxes) do
					if shopBox and shopBox.Parent then
						local itemName = string.lower(shopBox.Name)
						local description = shopBox:FindFirstChild("ItemDescription", true)
							or shopBox:FindFirstChild("Description", true)
						local descriptionText = description and string.lower(description.Text) or ""
						shopBox.Visible = query == ""
							or string.find(itemName, query, 1, true) ~= nil
							or string.find(descriptionText, query, 1, true) ~= nil
					end
				end
			end)
		)
	end

	task.spawn(function()
		for _, categoryName in ipairs(STORE_VIEW_CATEGORY_ORDER) do
			if not Store.Gui then
				return
			end
			Store.BuildCategoryCards(categoryName, true)
		end
	end)
end

function Store:RefreshDetailPanel()
	local selected = Store.SelectedItem
	if not selected or not Store.DetailPanel then
		return
	end

	local itemData = selected.Data
	local itemState = Store.OwnedItems[selected.Name]
	local viewDefinition = STORE_VIEW_CATEGORIES[selected.ViewCategory]
	local info = Store.DetailInfo
	local currency = Store:GetCurrencyConfig(selected.Name)

	Store.DetailCategoryTitle.Text = viewDefinition and viewDefinition.DisplayName or selected.ViewCategory
	info.ItemName.Text = selected.Name
	applyRarity(info.ItemRarity, itemData)
	info.ItemDescription.Text = buildDescriptionText(itemData)

	local coinContainer = Store.DetailPrices:FindFirstChild("CoinsContainer")
	local robuxContainer = Store.DetailPrices:FindFirstChild("RobuxContainer")
	local isOwned = itemState and itemState.Owned == true
	local isEquipped = itemState and itemState.Equipped == true
	if coinContainer then
		coinContainer.Visible = itemData.Price ~= nil
		coinContainer.CoinsCost.Text = string.format("%s%s", currency.prefix, tostring(itemData.Price or 0))
		setMuted(coinContainer, isOwned)
	end
	if robuxContainer then
		robuxContainer.Visible = itemData.RobuxAssetId ~= nil
		if itemData.RobuxAssetId then
			robuxContainer.RobuxCost.Text = Store:GetRobuxPriceText(itemData.RobuxAssetId, selected.Name, itemData)
		end
		setMuted(robuxContainer, isOwned)
	end

	local purchaseText = Store.DetailPrimaryAction:FindFirstChild("PurchaseText")
	if purchaseText then
		purchaseText.Text = isEquipped and "Unequip"
			or isOwned and "Equip"
			or itemData.Gamepass and "Get pass"
			or "Purchase"
		purchaseText.TextColor3 = Color3.new(1, 1, 1)
	end
	Store.DetailPrimaryAction.Active = true
	Store.DetailPrimaryAction.Interactable = true
	Store.DetailPrimaryAction.AutoButtonColor = true
	Store.DetailPrimaryAction.BackgroundColor3 = isEquipped and DETAIL_UNEQUIP_COLOR
		or isOwned and DETAIL_EQUIP_COLOR
		or DETAIL_PURCHASE_COLOR

	local hasRobuxOption = itemData.RobuxAssetId ~= nil
	Store.DetailRobuxAction.Visible = hasRobuxOption
	Store.DetailRobuxAction.Active = hasRobuxOption and not isOwned
	Store.DetailRobuxAction.Interactable = hasRobuxOption and not isOwned
	Store.DetailRobuxAction.AutoButtonColor = hasRobuxOption and not isOwned
	Store.DetailRobuxAction.BackgroundColor3 = isOwned and DETAIL_DISABLED_COLOR or DETAIL_ROBUX_COLOR
	local robuxText = Store.DetailRobuxAction:FindFirstChild("RobuxText")
	if robuxText and robuxText:IsA("TextLabel") then
		robuxText.TextColor3 = isOwned and DETAIL_DISABLED_CONTENT_COLOR or Color3.new(0, 0, 0)
	end
	local robuxIcon = Store.DetailRobuxAction:FindFirstChild("RobuxIcon")
	if robuxIcon and robuxIcon:IsA("ImageLabel") then
		robuxIcon.ImageColor3 = isOwned and DETAIL_DISABLED_CONTENT_COLOR or Color3.new(0, 0, 0)
	end
end

function Store:RefreshDetailPanelLegacy()
	local selected = Store.SelectedItem
	if not selected or not Store.DetailPanel then
		return
	end

	local body = Store.DetailBody
	local itemData = selected.Data
	local itemState = Store.OwnedItems[selected.Name]
	local currency = Store:GetCurrencyConfig(selected.Name)
	local stats = body and body:FindFirstChild("Stats")
	local priceValue = stats and stats:FindFirstChild("PriceRow") and stats.PriceRow:FindFirstChild("Value")
	local slotValue = stats and stats:FindFirstChild("SlotRow") and stats.SlotRow:FindFirstChild("Value")
	local ownershipValue = stats and stats:FindFirstChild("OwnershipRow") and stats.OwnershipRow:FindFirstChild("Value")

	if priceValue then
		priceValue.Text = itemData.Gamepass and "GAMEPASS"
			or string.format("%s%s", currency.prefix, tostring(itemData.Price or 0))
	end
	if slotValue then
		slotValue.Text = string.upper(itemData.Slot or selected.Category or "ITEM")
	end
	if ownershipValue then
		ownershipValue.Text = itemState and itemState.Equipped and "EQUIPPED"
			or itemState and itemState.Owned and "OWNED"
			or "NOT OWNED"
	end

	if Store.DetailPrimaryAction then
		Store.UpdateButtonState(Store.DetailPrimaryAction, selected.Name, itemData)
	end
	if Store.DetailRobuxAction then
		Store.DetailRobuxAction.Visible = itemData.RobuxAssetId ~= nil
		if itemData.RobuxAssetId then
			Store.DetailRobuxAction.Text = Store:GetRobuxPriceText(itemData.RobuxAssetId, selected.Name, itemData)
		end
	end
	if Store.DetailGiftAction then
		Store.DetailGiftAction.Visible = (itemData.Price or 0) > 0 and itemData.Gamepass == nil
	end
end

function Store.ClearItemSelection()
	Store.SelectedItem = nil
	for _, card in ipairs(Store.LoadedBoxes or {}) do
		if card and card.Parent then
			Store.SetCardSelected(card, false)
		end
	end
end

function Store.HideItemDetails(instant)
	if Store.DetailPanelTween then
		Store.DetailPanelTween:Cancel()
		Store.DetailPanelTween = nil
	end

	Store.ClearItemSelection()
	local panel = Store.DetailPanel
	if not panel then
		return
	end

	local targetPosition = Store.DetailPanelTargetPosition or panel.Position
	if instant or not panel.Visible then
		panel.Visible = false
		panel.Position = targetPosition
		Store.DetailPanelScale.Scale = 1
		return
	end

	local tween = TweenService:Create(
		Store.DetailPanelScale,
		TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Scale = 0 }
	)
	Store.DetailPanelTween = tween
	tween.Completed:Once(function()
		if Store.DetailPanelTween == tween then
			Store.DetailPanelTween = nil
			panel.Visible = false
			panel.Position = targetPosition
			Store.DetailPanelScale.Scale = 1
		end
	end)
	tween:Play()
end

function Store.ShowItemDetailsPanel()
	local panel = Store.DetailPanel
	if not panel then
		return
	end

	if Store.DetailPanelTween then
		Store.DetailPanelTween:Cancel()
	end

	local targetPosition = Store.DetailPanelTargetPosition or panel.Position
	panel.Position = targetPosition
	Store.DetailPanelScale.Scale = 0
	panel.Visible = true

	local tween = TweenService:Create(
		Store.DetailPanelScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	Store.DetailPanelTween = tween
	tween.Completed:Once(function()
		if Store.DetailPanelTween == tween then
			Store.DetailPanelTween = nil
		end
	end)
	tween:Play()
end

function Store:ShowItemDetails(itemName, category, itemData, viewCategory)
	Store.SelectedItem = {
		Name = itemName,
		Category = category,
		Data = itemData,
		ViewCategory = viewCategory or Store.CurrentCategory,
	}

	local viewportObject = itemData.Object
	if not viewportObject and category == "Cosmetics" then
		viewportObject = Store:GetCosmeticViewportObject(itemName)
	end
	Store.DetailViewport.Visible = viewportObject ~= nil
	if viewportObject then
		Store.SetupViewportFrame(Store.DetailViewport, viewportObject)
		Store.ConfigureViewportForItem(Store.DetailViewport, itemName, category)
	end

	Store:RefreshDetailPanel()
	Store.ShowItemDetailsPanel()
end

function Store:ShowItemDetailsLegacy(itemName, category, itemData)
	if not Store.DetailPanel or not Store.DetailBody then
		return
	end
	Store.SelectedItem = { Name = itemName, Category = category, Data = itemData }

	local body = Store.DetailBody
	body.ItemName.Text = itemName
	body.CategoryLabel.Text = category
	body.CategoryLabel.TextColor3 = CATEGORY_COLORS[category] or Color3.new(1, 1, 1)
	body.LevelLabel.Text = itemData.Gamepass and "GAMEPASS" or "SHOP ITEM"
	body.Description.Text = buildDescriptionText(itemData)
	if Store.DetailStatus then
		Store.DetailStatus.Text = ""
	end
	if Store.GiftPlayerList then
		Store.GiftPlayerList.Visible = false
	end

	local viewportObject = itemData.Object
	if not viewportObject and category == "Cosmetics" then
		viewportObject = Store:GetCosmeticViewportObject(itemName)
	end
	if Store.DetailViewport then
		Store.DetailViewport.Visible = viewportObject ~= nil
		if viewportObject then
			Store.SetupViewportFrame(Store.DetailViewport, viewportObject)
			Store.ConfigureViewportForItem(Store.DetailViewport, itemName, category)
		end
	end

	Store:RefreshDetailPanel()
	Store.ShowItemDetailsPanel()
end

function Store:PopulateGiftPlayers()
	local list = Store.GiftPlayerList
	local selected = Store.SelectedItem
	if not list or not selected then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local button = Instance.new("TextButton")
			button.Name = "Player_" .. player.UserId
			button.Size = UDim2.new(1, 0, 0, 36)
			button.BackgroundColor3 = Color3.fromRGB(16, 34, 57)
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.Text = "Gift to " .. player.DisplayName
			button.TextColor3 = Color3.fromRGB(241, 245, 251)
			button.TextSize = 16
			button.ZIndex = 31
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = button
			Store.BindButtonFeedback(button)
			button.Activated:Connect(function()
				Store.GiftRequest:Fire(selected.Category, selected.Name, player.UserId)
				if Store.DetailStatus then
					Store.DetailStatus.Text = "Sending gift..."
				end
			end)
			button.Parent = list
		end
	end

	if #Players:GetPlayers() <= 1 and Store.DetailStatus then
		Store.DetailStatus.Text = "No other players are currently available."
	end
	list.Visible = not list.Visible
end

function Store.SetCardSelected(card, isSelected)
	local accent = card and card:FindFirstChild("SelectionAccent")
	if not accent or not accent:IsA("GuiObject") then
		return
	end

	local normalColor = Store.CardAccentColors[card] or accent.BackgroundColor3
	Store.CardAccentColors[card] = normalColor
	local selectedCategory = card:GetAttribute("ViewCategory") or card:GetAttribute("SourceCategory")
	local targetColor = isSelected and (CATEGORY_COLORS[selectedCategory] or Color3.fromRGB(96, 172, 255))
		or normalColor

	accent.Visible = true
	TweenService:Create(accent, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = targetColor,
	}):Play()
end

function Store.SetItemCardHoverState(card, isHovered)
	if not card then
		return
	end

	local style = Store.CardHoverStyles[card]
	if not style then
		return
	end

	local hoverInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local targetTransparency = style.BackgroundTransparency
	if isHovered then
		targetTransparency = math.max(0, style.BackgroundTransparency - 0.2)
	end
	TweenService:Create(card, hoverInfo, {
		BackgroundTransparency = targetTransparency,
	}):Play()
	TweenService:Create(style.Scale, hoverInfo, {
		Scale = isHovered and ITEM_CARD_HOVER_SCALE or ITEM_CARD_REST_SCALE,
	}):Play()
end

local function getOwnershipOverlaySize(frame)
	local originalSize = Store.CardOverlaySizes[frame]
	if not originalSize then
		originalSize = frame.Size
		Store.CardOverlaySizes[frame] = originalSize
	end
	return originalSize
end

function Store.TweenOwnershipOverlay(frame, collapsed, immediate)
	if not frame or not frame:IsA("GuiObject") then
		return
	end

	local originalSize = getOwnershipOverlaySize(frame)
	local targetSize = originalSize
	if collapsed then
		targetSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)
	end
	local activeTween = Store.CardOverlayTweens and Store.CardOverlayTweens[frame]
	if activeTween then
		activeTween:Cancel()
		Store.CardOverlayTweens[frame] = nil
	end

	if immediate then
		frame.Size = targetSize
		return
	end

	local tweenInfo
	if collapsed then
		tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	else
		tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	local tween = TweenService:Create(frame, tweenInfo, { Size = targetSize })
	Store.CardOverlayTweens[frame] = tween
	tween.Completed:Once(function()
		if Store.CardOverlayTweens and Store.CardOverlayTweens[frame] == tween then
			Store.CardOverlayTweens[frame] = nil
		end
	end)
	tween:Play()
end

function Store.SetOwnershipOverlayHovered(card, isHovered)
	if not card then
		return
	end

	card:SetAttribute("OwnershipOverlayHovered", isHovered)
	for _, frameName in ipairs({ "PurchasedFrame", "EquippedFrame" }) do
		local frame = card:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") and frame.Visible then
			Store.TweenOwnershipOverlay(frame, isHovered, false)
		end
	end
end

function Store.UpdateCardOwnership(card, itemData)
	if not card then
		return
	end

	local itemState = Store.OwnedItems[card.Name]
	local isOwned = itemState and itemState.Owned == true
	local isEquipped = isOwned and itemState.Equipped == true
	local isHovered = card:GetAttribute("OwnershipOverlayHovered") == true
	local purchasedFrame = card:FindFirstChild("PurchasedFrame")
	local equippedFrame = card:FindFirstChild("EquippedFrame")

	if purchasedFrame and purchasedFrame:IsA("GuiObject") then
		purchasedFrame.Visible = isOwned and not isEquipped
		Store.TweenOwnershipOverlay(purchasedFrame, isHovered and purchasedFrame.Visible, true)
	end
	if equippedFrame and equippedFrame:IsA("GuiObject") then
		equippedFrame.Visible = isEquipped
		Store.TweenOwnershipOverlay(equippedFrame, isHovered and equippedFrame.Visible, true)
	end

	local cost = card:FindFirstChild("Cost")
	if not cost then
		return
	end
	local coinFrame = cost:FindFirstChild("CoinFrame")
	local robuxFrame = cost:FindFirstChild("RobuxFrame")
	if coinFrame then
		coinFrame.Visible = not isOwned and itemData.Price ~= nil
	end
	if robuxFrame then
		robuxFrame.Visible = not isOwned and itemData.RobuxAssetId ~= nil
	end
end

function Store.CreateShopItem(itemName, itemData, category, viewCategory)
	local card = Store.ShopBox:Clone()
	card.Name = itemName
	card.Visible = true
	card.Active = true
	card:SetAttribute("IsTemplate", nil)
	card:SetAttribute("SourceCategory", category)
	card:SetAttribute("ViewCategory", viewCategory)
	card.Parent = Store.ItemBox

	local cardScale = card:FindFirstChildOfClass("UIScale")
	if not cardScale then
		cardScale = Instance.new("UIScale")
		cardScale.Name = "UIScale"
		cardScale.Parent = card
	end
	cardScale.Scale = ITEM_CARD_REST_SCALE
	Store.CardHoverStyles[card] = {
		BackgroundTransparency = card.BackgroundTransparency,
		Scale = cardScale,
	}

	card.ItemName.Text = itemName
	card.ItemDescription.Text = buildDescriptionText(itemData)
	applyRarity(card.ItemRarity, itemData)

	local newLabel = card:FindFirstChild("NewLabel", true)
	if newLabel then
		newLabel.Visible = itemData.New == true
	end

	local cost = card:FindFirstChild("Cost")
	local currency = Store:GetCurrencyConfig(itemName)
	if cost then
		local coinFrame = cost:FindFirstChild("CoinFrame")
		local robuxFrame = cost:FindFirstChild("RobuxFrame")
		if coinFrame then
			coinFrame.Visible = itemData.Price ~= nil
			local coinLabel = coinFrame:FindFirstChild("CoinLabel")
			if coinLabel then
				coinLabel.Text = string.format("%s%s", currency.prefix, tostring(itemData.Price or 0))
			end
		end
		if robuxFrame then
			robuxFrame.Visible = itemData.RobuxAssetId ~= nil
			local robuxCost = robuxFrame:FindFirstChild("RobuxCost", true)
			if robuxCost and itemData.RobuxAssetId then
				robuxCost.Text = Store:GetRobuxPriceText(itemData.RobuxAssetId, itemName, itemData)
			end
		end
	end

	local viewport = card:FindFirstChild("ItemFrame")
	local viewportObject = itemData.Object
	if not viewportObject and category == "Cosmetics" then
		viewportObject = Store:GetCosmeticViewportObject(itemName)
	end
	if viewport and viewportObject then
		Store.SetupViewportFrame(viewport, viewportObject)
		Store.ConfigureViewportForItem(viewport, itemName, category)
	end

	local connection = card.Activated:Connect(function()
		local selected = Store.SelectedItem
		if selected and selected.Name == itemName and Store.DetailPanel and Store.DetailPanel.Visible then
			Store.HideItemDetails(false)
			return
		end

		for _, loadedCard in ipairs(Store.LoadedBoxes) do
			Store.SetCardSelected(loadedCard, loadedCard == card)
		end
		Store:ShowItemDetails(itemName, category, itemData, viewCategory)
	end)
	table.insert(Store.Connections, connection)
	table.insert(
		Store.Connections,
		card.MouseEnter:Connect(function()
			playUiSound("ButtonHover")
			Store.SetItemCardHoverState(card, true)
			Store.SetOwnershipOverlayHovered(card, true)
		end)
	)
	table.insert(
		Store.Connections,
		card.MouseLeave:Connect(function()
			Store.SetItemCardHoverState(card, false)
			Store.SetOwnershipOverlayHovered(card, false)
		end)
	)
	table.insert(
		Store.Connections,
		card.MouseButton1Down:Connect(function()
			playUiSound("ClickDown")
		end)
	)
	table.insert(
		Store.Connections,
		card.MouseButton1Up:Connect(function()
			playUiSound("ClickUp")
		end)
	)

	local accent = card:FindFirstChild("SelectionAccent")
	if accent and accent:IsA("GuiObject") then
		local rarity = getRarity(itemData)
		local accentColor = (rarity and rarity.PrimaryColor) or accent.BackgroundColor3
		accent.BackgroundColor3 = accentColor
		Store.CardAccentColors[card] = accentColor
		accent.Visible = true
	end
	Store.UpdateCardOwnership(card, itemData)

	return card
end

function Store.CreateShopItemLegacy(itemName, itemData, category)
	local shopBox = Store.ShopBox:Clone()
	shopBox.Parent = Store.ItemBox
	shopBox.Visible = true
	shopBox.Name = itemName
	shopBox.Active = true
	local detailsConnection = shopBox.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Store:ShowItemDetails(itemName, category, itemData)
		end
	end)
	table.insert(Store.Connections, detailsConnection)

	local itemNameLabel = shopBox:FindFirstChild("ItemName")
	local actionButton = shopBox:FindFirstChild("Price") or shopBox:FindFirstChild("ActionButton")
	local viewportFrame = shopBox:FindFirstChild("ViewportFrame")
	local descriptionLabel = shopBox:FindFirstChild("Description", true)
	local levelLabel = shopBox:FindFirstChild("LevelLabel", true)
	local rarityLabel = shopBox:FindFirstChild("RarityLabel", true)
	local slotLabel = shopBox:FindFirstChild("DropChance", true)
	local rarityAccent = shopBox:FindFirstChild("RarityAccent", true)
	local viewportObject = itemData.Object
	if not viewportObject and category == "Cosmetics" then
		viewportObject = Store:GetCosmeticViewportObject(itemName)
	end

	if itemNameLabel then
		itemNameLabel.Text = itemName
	end

	if descriptionLabel then
		local descText = buildDescriptionText(itemData)
		if descText ~= "" then
			descriptionLabel.Text = descText
			descriptionLabel.TextTransparency = 0
			descriptionLabel.Visible = true
			descriptionLabel.TextScaled = false
			descriptionLabel.TextSize = 17

			local textSizeConstraint = descriptionLabel:FindFirstChild("UITextSizeConstraint")
			if not textSizeConstraint then
				textSizeConstraint = Instance.new("UITextSizeConstraint")
				textSizeConstraint.MaxTextSize = 17
				textSizeConstraint.MinTextSize = 10
				textSizeConstraint.Parent = descriptionLabel
			end
		else
			descriptionLabel.Text = ""
		end
	end

	if levelLabel then
		levelLabel.Text = itemData.Gamepass and "GAMEPASS" or "SHOP ITEM"
	end
	if rarityLabel then
		applyRarity(rarityLabel, itemData)
	end
	if slotLabel then
		slotLabel.Text = itemData.Slot and string.upper(itemData.Slot) or "COLLECTIBLE"
	end
	if rarityAccent and rarityAccent:IsA("GuiObject") then
		local rarity = getRarity(itemData)
		rarityAccent.BackgroundColor3 = (rarity and rarity.PrimaryColor) or Color3.new(1, 1, 1)
	end

	if actionButton then
		actionButton:SetAttribute("ItemName", itemName)
		actionButton:SetAttribute("Category", category)

		actionButton.Position = actionButton.Position + UDim2.new(0, 0, -0.02, 0)

		local buttonScale = actionButton:FindFirstChild("UIScale")
		if not buttonScale then
			buttonScale = Instance.new("UIScale")
			buttonScale.Name = "UIScale"
			buttonScale.Scale = 1
			buttonScale.Parent = actionButton
		end

		local hoverEnter = actionButton.MouseEnter:Connect(function()
			local hoverTween = TweenService:Create(
				buttonScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1.03 }
			)
			hoverTween:Play()
		end)

		local hoverLeave = actionButton.MouseLeave:Connect(function()
			local leaveTween = TweenService:Create(
				buttonScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
			leaveTween:Play()
		end)

		table.insert(Store.Connections, hoverEnter)
		table.insert(Store.Connections, hoverLeave)

		local conn = actionButton.Activated:Connect(function()
			local clickTween = TweenService:Create(
				buttonScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 0.95 }
			)
			clickTween:Play()
			clickTween.Completed:Connect(function()
				local bounceTween = TweenService:Create(
					buttonScale,
					TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1 }
				)
				bounceTween:Play()
			end)
			Store:OnActionButtonClick(itemName, category, itemData)
		end)
		table.insert(Store.Connections, conn)

		if itemData.RobuxAssetId then
			local robuxConn = actionButton.MouseButton2Click:Connect(function()
				Store:PromptRobuxPurchase(itemData, itemName)
			end)
			table.insert(Store.Connections, robuxConn)
		end
	end

	if actionButton and itemData.RobuxAssetId then
		local robuxButton = shopBox:FindFirstChild("RobuxButton")
		if not robuxButton then
			robuxButton = actionButton:Clone()
			robuxButton.Name = "RobuxButton"
			robuxButton.Parent = shopBox
			robuxButton:SetAttribute("ItemName", itemName)
			robuxButton:SetAttribute("Category", category)
		end

		robuxButton.Text = Store:GetRobuxPriceText(itemData.RobuxAssetId, itemName, itemData)
		robuxButton.AnchorPoint = actionButton.AnchorPoint
		robuxButton.Size = UDim2.new(
			actionButton.Size.X.Scale,
			actionButton.Size.X.Offset,
			actionButton.Size.Y.Scale * 0.5,
			actionButton.Size.Y.Offset * 0.5
		)
		local sizeConstraint = robuxButton:FindFirstChildOfClass("UISizeConstraint")
		if sizeConstraint then
			sizeConstraint.MaxSize = Vector2.new(sizeConstraint.MaxSize.X, sizeConstraint.MaxSize.Y * 0.5)
			sizeConstraint.MinSize = Vector2.new(sizeConstraint.MinSize.X, sizeConstraint.MinSize.Y * 0.5)
		end
		robuxButton.Position = actionButton.Position + UDim2.new(0, 0, actionButton.Size.Y.Scale + 0.02, 0)

		local robuxScale = robuxButton:FindFirstChild("UIScale")
		if not robuxScale then
			robuxScale = Instance.new("UIScale")
			robuxScale.Name = "UIScale"
			robuxScale.Scale = 1
			robuxScale.Parent = robuxButton
		end

		local robuxHoverEnter = robuxButton.MouseEnter:Connect(function()
			local hoverTween = TweenService:Create(
				robuxScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1.03 }
			)
			hoverTween:Play()
		end)

		local robuxHoverLeave = robuxButton.MouseLeave:Connect(function()
			local leaveTween = TweenService:Create(
				robuxScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
			leaveTween:Play()
		end)

		table.insert(Store.Connections, robuxHoverEnter)
		table.insert(Store.Connections, robuxHoverLeave)

		local robuxClick = robuxButton.Activated:Connect(function()
			local clickTween = TweenService:Create(
				robuxScale,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 0.95 }
			)
			clickTween:Play()
			clickTween.Completed:Connect(function()
				local bounceTween = TweenService:Create(
					robuxScale,
					TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1 }
				)
				bounceTween:Play()
			end)
			Store:PromptRobuxPurchase(itemData, itemName)
		end)
		table.insert(Store.Connections, robuxClick)
	end

	if actionButton then
		Store.UpdateButtonState(actionButton, itemName, itemData)
	end

	if viewportFrame and viewportObject then
		Store.SetupViewportFrame(viewportFrame, viewportObject)
		if viewportFrame.CurrentCamera then
			local camera = viewportFrame.CurrentCamera
			local zoomMultiplier = (category == "Cosmetics") and 2 or 1
			if itemName and string.find(string.lower(itemName), "mask") then
				zoomMultiplier = 1.1
			elseif itemData.Slot == "Plushie" then
				zoomMultiplier = 0.8
			elseif itemData.Slot == "Tool" then
				zoomMultiplier = 1.25
			end

			local distance = (camera:GetAttribute("Distance") or 5) * zoomMultiplier
			local height = (camera:GetAttribute("Height") or 0) * zoomMultiplier

			camera:SetAttribute("Distance", distance)
			camera:SetAttribute("Height", height)
			camera.CFrame = CFrame.new(Vector3.new(distance, height * 1.5, distance), Vector3.new(0, 0, 0))
		end
		Store.ConfigureViewportForItem(viewportFrame, itemName, category)
	elseif viewportFrame and itemData.RobuxAssetId then
		Store.SetupViewportFrameIcon(viewportFrame, itemData.RobuxAssetId)

		viewportFrame.BackgroundTransparency = 0.7
		viewportFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
		viewportFrame.BorderSizePixel = 0

		local uiCorner = viewportFrame:FindFirstChild("UICorner")
		if not uiCorner then
			uiCorner = Instance.new("UICorner")
			uiCorner.CornerRadius = UDim.new(0, 12)
			uiCorner.Parent = viewportFrame
		end

		local uiStroke = viewportFrame:FindFirstChild("UIStroke")
		if not uiStroke then
			uiStroke = Instance.new("UIStroke")
			uiStroke.Color = Color3.fromRGB(60, 120, 180)
			uiStroke.Thickness = 1
			uiStroke.Transparency = 0.3
			uiStroke.Parent = viewportFrame
		end
	end

	return shopBox
end

function Store.ConfigureViewportForItem(viewportFrame, itemName, category)
	local worldModel = viewportFrame and viewportFrame:FindFirstChildOfClass("WorldModel")
	local camera = viewportFrame and viewportFrame.CurrentCamera
	if not worldModel or not camera then
		return
	end

	local lowerName = string.lower(itemName or "")
	local yaw = 0
	if category == "Cosmetics" then
		yaw = math.pi
	elseif lowerName == "scud" then
		yaw = math.pi
	elseif string.find(lowerName, "mask", 1, true) then
		yaw = math.rad(-90)
	end

	local rotation = CFrame.Angles(0, yaw, 0)
	local minPos = Vector3.new(math.huge, math.huge, math.huge)
	local maxPos = Vector3.new(-math.huge, -math.huge, -math.huge)
	local partCount = 0

	for _, part in ipairs(worldModel:GetDescendants()) do
		if part:IsA("BasePart") then
			partCount += 1
			if yaw ~= 0 then
				part.CFrame = rotation * part.CFrame
			end
			if string.find(lowerName, "mask", 1, true) and part:IsA("MeshPart") then
				part.DoubleSided = true
			end

			local half = part.Size * 0.5
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local point = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						minPos = Vector3.new(
							math.min(minPos.X, point.X),
							math.min(minPos.Y, point.Y),
							math.min(minPos.Z, point.Z)
						)
						maxPos = Vector3.new(
							math.max(maxPos.X, point.X),
							math.max(maxPos.Y, point.Y),
							math.max(maxPos.Z, point.Z)
						)
					end
				end
			end
		end
	end

	if partCount == 0 then
		return
	end
	local center = (minPos + maxPos) * 0.5
	local radius = math.max((maxPos - minPos).Magnitude * 0.5, 0.5)
	local distance = (radius / math.tan(math.rad(camera.FieldOfView * 0.5))) * 1.2
	local direction = Vector3.new(1, 0.48, 1).Unit
	camera:SetAttribute("Distance", distance)
	camera:SetAttribute("Height", direction.Y * distance)
	camera.CFrame = CFrame.lookAt(center + direction * distance, center)
end

function Store.SetupViewportFrame(viewportFrame, modelObject)
	if not viewportFrame then
		return
	end

	for _, child in viewportFrame:GetChildren() do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "WorldModel"
	worldModel.Parent = viewportFrame

	if not modelObject then
		return
	end

	local models = {}
	if typeof(modelObject) == "table" then
		for _, obj in pairs(modelObject) do
			if typeof(obj) == "Instance" then
				table.insert(models, obj)
			end
		end
	elseif typeof(modelObject) == "Instance" then
		models = { modelObject }
	else
		return
	end

	if #models == 0 then
		return
	end

	local clonedModels = {}
	for _, obj in ipairs(models) do
		local model = obj:Clone()
		model.Parent = worldModel

		for _, descendant in model:GetDescendants() do
			if descendant:IsA("MeshPart") or descendant:IsA("Part") or descendant:IsA("UnionOperation") then
				descendant.Anchored = true
				descendant.CanCollide = false
			elseif descendant:IsA("SpecialMesh") then
				local part = descendant.Parent
				if part and part:IsA("Part") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
		end

		table.insert(clonedModels, model)
	end

	local minPos = Vector3.new(math.huge, math.huge, math.huge)
	local maxPos = Vector3.new(-math.huge, -math.huge, -math.huge)

	local function expandBounds(cframe, size)
		local sx, sy, sz = size.X / 2, size.Y / 2, size.Z / 2
		local corners = {
			Vector3.new(-sx, -sy, -sz),
			Vector3.new(-sx, -sy, sz),
			Vector3.new(-sx, sy, -sz),
			Vector3.new(-sx, sy, sz),
			Vector3.new(sx, -sy, -sz),
			Vector3.new(sx, -sy, sz),
			Vector3.new(sx, sy, -sz),
			Vector3.new(sx, sy, sz),
		}

		for _, corner in ipairs(corners) do
			local world = cframe:PointToWorldSpace(corner)
			minPos = Vector3.new(math.min(minPos.X, world.X), math.min(minPos.Y, world.Y), math.min(minPos.Z, world.Z))
			maxPos = Vector3.new(math.max(maxPos.X, world.X), math.max(maxPos.Y, world.Y), math.max(maxPos.Z, world.Z))
		end
	end

	for _, model in clonedModels do
		if model:IsA("Model") then
			local cframe, size = model:GetBoundingBox()
			expandBounds(cframe, size)
		elseif model:IsA("BasePart") then
			expandBounds(model.CFrame, model.Size)
		else
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					expandBounds(descendant.CFrame, descendant.Size)
				end
			end
		end
	end

	if minPos.X == math.huge then
		return
	end

	local modelSize = maxPos - minPos
	local modelCenter = (maxPos + minPos) / 2

	for _, model in clonedModels do
		if model:IsA("Model") then
			model:PivotTo(model:GetPivot() - modelCenter)
		elseif model:IsA("BasePart") then
			model.CFrame = model.CFrame - modelCenter
		else
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.CFrame = descendant.CFrame - modelCenter
				end
			end
		end
	end

	local camera = Instance.new("Camera")
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	camera.FieldOfView = 60
	local offset = 1.5

	local maxDimension = math.max(modelSize.X, offset, modelSize.Z)
	local baseDistance = 5
	if maxDimension > 0 then
		baseDistance = (maxDimension / 2) / math.tan(math.rad(camera.FieldOfView / 2))
		baseDistance = baseDistance * 1.2
	end

	local angleRadians = math.rad(15)
	local height = baseDistance * math.sin(angleRadians)
	local radius = baseDistance * math.cos(angleRadians)

	camera:SetAttribute("Distance", radius)
	camera:SetAttribute("Height", height)

	local cameraPos = Vector3.new(radius, height, radius)
	camera.CFrame = CFrame.new(cameraPos, Vector3.new(0, 0, 0))

	local light = viewportFrame:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Brightness = 1
		light.Range = 30
		light.Parent = viewportFrame
	end

	viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-1, -1, -2)
end

function Store.BuildCategoryCards(categoryName, yieldBetweenCards)
	local cached = Store.CategoryCardCache[categoryName]
	if cached then
		return cached
	end
	local activeBuild = Store.CategoryBuildEvents[categoryName]
	if activeBuild then
		activeBuild.Event:Wait()
		return Store.CategoryCardCache[categoryName] or {}
	end

	local buildComplete = Instance.new("BindableEvent")
	Store.CategoryBuildEvents[categoryName] = buildComplete
	local cards = {}
	for _, item in ipairs(Store:GetViewCategoryItems(categoryName)) do
		local card = Store.CreateShopItem(item.Name, item.Data, item.Category, categoryName)
		card.Visible = false
		table.insert(cards, card)
		if yieldBetweenCards then
			RunService.Heartbeat:Wait()
		end
	end
	Store.CategoryCardCache[categoryName] = cards
	Store.CategoryBuildEvents[categoryName] = nil
	buildComplete:Fire()
	buildComplete:Destroy()
	return cards
end

function Store.DisplayCategory(categoryName)
	if not STORE_VIEW_CATEGORIES[categoryName] then
		warn("Store view category not found:", categoryName)
		return
	end

	Store.CategoryTransitionId += 1
	local transitionId = Store.CategoryTransitionId
	Store.ItemBox.CanvasPosition = Vector2.zero
	Store.HideItemDetails(true)
	Store.CurrentCategory = categoryName
	Store.UpdateCategorySelection(categoryName)

	local pageScale = Store.ItemBox:FindFirstChild("CategoryTransitionScale")
	if not pageScale then
		pageScale = Instance.new("UIScale")
		pageScale.Name = "CategoryTransitionScale"
		pageScale.Scale = 1
		pageScale.Parent = Store.ItemBox
	end

	TweenService
		:Create(pageScale, TweenInfo.new(0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.975 })
		:Play()

	task.delay(0.045, function()
		if transitionId ~= Store.CategoryTransitionId then
			return
		end

		for _, card in ipairs(Store.LoadedBoxes) do
			if card and card.Parent then
				card.Visible = false
			end
		end

		local cards = Store.BuildCategoryCards(categoryName, false)
		Store.LoadedBoxes = cards
		for index, card in ipairs(cards) do
			if card and card.Parent then
				local cardScale = card:FindFirstChildOfClass("UIScale")
				if not cardScale then
					cardScale = Instance.new("UIScale")
					cardScale.Parent = card
				end
				cardScale.Scale = 0
				card.Visible = true
				Store.SetCardSelected(card, false)
				task.delay((index - 1) * 0.012, function()
					if transitionId ~= Store.CategoryTransitionId or not card.Parent or not card.Visible then
						return
					end
					TweenService:Create(
						cardScale,
						TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = ITEM_CARD_REST_SCALE }
					):Play()
				end)
			end
		end

		pageScale.Scale = 0.975
		TweenService
			:Create(pageScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
end

function Store.DisplayCategoryLegacy(categoryName)
	if not Store.StoreItems or not Store.StoreItems.Categories[categoryName] then
		warn("Category not found:", categoryName)
		return
	end

	if Store.ItemBox:IsA("ScrollingFrame") then
		Store.ItemBox.CanvasPosition = Vector2.new(0, 0)
	elseif Store.ItemBox.Parent and Store.ItemBox.Parent:IsA("ScrollingFrame") then
		Store.ItemBox.Parent.CanvasPosition = Vector2.new(0, 0)
	end

	for _, box in Store.LoadedBoxes do
		if box and box.Parent then
			box:Destroy()
		end
	end
	Store.LoadedBoxes = {}

	local categoryData = Store.StoreItems.Categories[categoryName]

	local sortedItems = {}
	for itemName, itemData in pairs(categoryData) do
		if not itemData.Hidden then
			table.insert(sortedItems, { Name = itemName, Data = itemData })
		end
	end
	table.sort(sortedItems, function(a, b)
		local orderA = a.Data.SortOrder or 1000
		local orderB = b.Data.SortOrder or 1000

		if orderA ~= orderB then
			return orderA < orderB
		end

		if a.Data.Price ~= b.Data.Price then
			return a.Data.Price < b.Data.Price
		end

		return a.Name < b.Name
	end)

	if #sortedItems == 0 then
		local shopBox = Store.ShopBox:Clone()
		shopBox.Parent = Store.ItemBox
		shopBox.Visible = true
		shopBox.Name = "ComingSoon"

		local itemNameLabel = shopBox:FindFirstChild("ItemName")
		if itemNameLabel then
			itemNameLabel.Text = "Coming Soon"
		end

		local descriptionLabel = shopBox:FindFirstChild("Description", true)
		if descriptionLabel then
			descriptionLabel.Text = "Check back later for new items!"
			descriptionLabel.Visible = true
		end

		local actionButton = shopBox:FindFirstChild("Price") or shopBox:FindFirstChild("ActionButton")
		if actionButton then
			actionButton.Visible = false
		end

		local viewportFrame = shopBox:FindFirstChild("ViewportFrame")
		if viewportFrame then
			viewportFrame:Destroy()
		end

		table.insert(Store.LoadedBoxes, shopBox)
	end

	for i, item in ipairs(sortedItems) do
		local shopBox = Store.CreateShopItem(item.Name, item.Data, categoryName)
		table.insert(Store.LoadedBoxes, shopBox)

		shopBox.Visible = true
		local scale = shopBox:FindFirstChild("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Parent = shopBox
		end
		scale.Scale = 0

		task.delay(i * 0.05, function()
			if shopBox and shopBox.Parent then
				TweenService
					:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
					:Play()
			end
		end)
	end

	Store.CurrentCategory = categoryName
	Store.UpdateCategorySelection(categoryName)
	print("Displaying category:", categoryName)
end

function Store.UpdateCategorySelection(selectedCategory)
	for categoryName, _ in pairs(Store.Categories) do
		Store.UpdateCategoryButtonState(categoryName, categoryName == selectedCategory)
	end
end

function Store.UpdateCategoryButtonState(categoryName, isSelected)
	local categoryButton = Store.Categories[categoryName]
	local style = Store.CategoryButtonStyles[categoryName]
	if not categoryButton or not style then
		return
	end
	do
		categoryButton:SetAttribute("IsSelected", isSelected)
		local accent = style.SelectionAccent or categoryButton:FindFirstChild("SelectionAccent")
		if accent then
			accent.Visible = true
			local baseColor = style.SelectionAccentColor3 or accent.BackgroundColor3
			local targetColor = isSelected and baseColor:Lerp(Color3.new(1, 1, 1), 0.35) or baseColor
			TweenService:Create(
				accent,
				TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundColor3 = targetColor }
			):Play()
		end
		if style.Label then
			style.Label.Font = isSelected and Enum.Font.GothamBold or style.LabelFont
			style.Label.TextColor3 = isSelected and UIColors.TextLight or style.LabelTextColor3
		end
		if style.Icon then
			style.Icon.ImageTransparency = isSelected and 0 or style.IconImageTransparency
		end
		local buttonScale = categoryButton:FindFirstChild("UIScale")
		if buttonScale then
			buttonScale.Scale = isSelected and 1.02 or 1
		end
		return
	end

	local uiStroke = categoryButton:FindFirstChildOfClass("UIStroke")
	local buttonScale = categoryButton:FindFirstChild("UIScale")

	local targetTransparency = style.BackgroundTransparency
	local targetColor = style.BackgroundColor3
	local targetTextColor = style.TextColor3
	local targetFont = style.Font
	local targetStrokeColor = style.StrokeColor3
	local targetStrokeTransparency = style.StrokeTransparency
	local targetImageColor = style.ImageColor3
	local targetImageTransparency = style.ImageTransparency
	local targetLabelTextColor = style.LabelTextColor3
	local targetLabelFont = style.LabelFont
	local targetIconImageColor = style.IconImageColor3
	local targetIconImageTransparency = style.IconImageTransparency
	local targetScale = 1

	if isSelected then
		if categoryName ~= "Cosmetics" then
			targetTransparency = math.max(0, style.BackgroundTransparency - 0.1)
			targetColor = UIColors.BackgroundAlt
		end
		targetTextColor = UIColors.TextLight
		targetFont = Enum.Font.GothamBold
		targetStrokeColor = UIColors.StrokeSelected
		targetStrokeTransparency = 0
		targetImageColor = UIColors.AccentAlt
		targetImageTransparency = 0
		targetLabelTextColor = UIColors.TextLight
		targetLabelFont = Enum.Font.GothamBold
		targetIconImageColor = UIColors.TextLight
		targetIconImageTransparency = 0
		targetScale = 1.02
	end

	categoryButton:SetAttribute("IsSelected", isSelected)
	categoryButton.BackgroundTransparency = targetTransparency
	categoryButton.BackgroundColor3 = targetColor

	if categoryButton:IsA("TextButton") then
		if targetTextColor then
			categoryButton.TextColor3 = targetTextColor
		end
		if targetFont then
			categoryButton.Font = targetFont
		end
	end

	if categoryButton:IsA("ImageButton") then
		if targetImageColor then
			categoryButton.ImageColor3 = targetImageColor
		end
		if targetImageTransparency ~= nil then
			categoryButton.ImageTransparency = targetImageTransparency
		end
	end

	if style.Label then
		if targetLabelTextColor then
			style.Label.TextColor3 = targetLabelTextColor
		end
		if targetLabelFont then
			style.Label.Font = targetLabelFont
		end
	end

	if style.Icon then
		if targetIconImageColor then
			style.Icon.ImageColor3 = targetIconImageColor
		end
		if targetIconImageTransparency ~= nil then
			style.Icon.ImageTransparency = targetIconImageTransparency
		end
	end

	if uiStroke then
		uiStroke.Color = targetStrokeColor
		uiStroke.Transparency = targetStrokeTransparency
	end

	if buttonScale then
		buttonScale.Scale = targetScale
	end
end

function Store._stopActiveTween()
	if Store._activeTween then
		Store._activeTween:Cancel()
		Store._activeTween = nil
	end
	if Store._activeTweenConnection then
		Store._activeTweenConnection:Disconnect()
		Store._activeTweenConnection = nil
	end
end

function Store._playScaleTween(targetScale, tweenInfo, onComplete)
	if not Store._scale then
		if onComplete then
			onComplete()
		end
		return
	end

	Store._stopActiveTween()

	local tween = TweenService:Create(Store._scale, tweenInfo, {
		Scale = targetScale,
	})
	Store._activeTween = tween
	Store._activeTweenConnection = tween.Completed:Connect(function()
		if Store._activeTween == tween then
			Store._stopActiveTween()
			if onComplete then
				onComplete()
			end
		end
	end)

	tween:Play()
end

function Store._getPanelHiddenPosition(dock, position)
	if dock == "Left" then
		return UDim2.new(-0.42, 0, position.Y.Scale, position.Y.Offset)
	end

	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale + 0.04, position.Y.Offset)
end

function Store._configurePanelControl(dock)
	if not Store.Interface or not Store.MainContainer then
		return nil
	end

	local defaultContainer = Store._defaultLayout and Store._defaultLayout.Container
	local targetPosition = defaultContainer and defaultContainer.Position or Store.MainContainer.Position
	local control = Store.PanelControl
	if not control then
		control = Store.Interface:Get(Store.MainContainer)
		Store.PanelControl = control
	end

	control.StartPosition = targetPosition
	control.HiddenPosition = Store._getPanelHiddenPosition(dock, targetPosition)
	control.TweenStyles = {
		InTweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		OutTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
	}
	control:CreateTweens()

	return control
end

function Store._showPanelControl(dock)
	local control = Store._configurePanelControl(dock)
	if not control then
		if Store.MainContainer then
			Store.MainContainer.Visible = true
		end
		return
	end

	Store.MainContainer.Position = control.Positions.Hidden
	if Store._scale then
		Store._scale.Scale = 1
	end
	control:Show()
end

function Store._hidePanelControl(onComplete)
	local control = Store.PanelControl
	if not control then
		if onComplete then
			onComplete()
		end
		return
	end

	control:Hide()
	if onComplete then
		onComplete()
	end
end

function Store._captureDefaultLayout()
	if Store._defaultLayout or not Store.Main or not Store.MainContainer then
		return
	end

	Store._defaultLayout = {
		Root = {
			AnchorPoint = Store.Main.AnchorPoint,
			Position = Store.Main.Position,
			Size = Store.Main.Size,
		},
		Container = {
			AnchorPoint = Store.MainContainer.AnchorPoint,
			Position = Store.MainContainer.Position,
			Size = Store.MainContainer.Size,
		},
	}
end

function Store._applyLayout(dock)
	if not Store.Main or not Store.MainContainer then
		return
	end
	Store.MainContainer:SetAttribute("Dock", dock or "Default")
end

function Store._lockLayoutForFrames(dock, frameCount)
	frameCount = frameCount or 12
	local token = {}
	Store._layoutLockToken = token

	task.spawn(function()
		for _ = 1, frameCount do
			if Store._layoutLockToken ~= token then
				return
			end
			Store._applyLayout(dock)
			task.wait()
		end
	end)
end

function Store._setHudHidden(hidden)
	local sideMenu = Store.Interface and Store.Interface.SideMenu
	if sideMenu then
		if hidden then
			if Store._hudState == nil then
				Store._hudState = {}
			end
			if Store._hudState.SideMenuWasVisible == nil then
				Store._hudState.SideMenuWasVisible = sideMenu._isVisible == true
			end
			if sideMenu.Hide then
				sideMenu.Hide()
			end
		elseif Store._hudState and Store._hudState.SideMenuWasVisible and sideMenu.Show then
			sideMenu.Show()
		end
	end

	local backpackController = Mince:Get("BackpackController")
	local backpack = backpackController and backpackController.BackpackMain
	if backpack and backpack.SetBackpackEnabled then
		if hidden then
			if Store._hudState == nil then
				Store._hudState = {}
			end
			if Store._hudState.BackpackWasEnabled == nil and backpack.GetBackpackEnabled then
				Store._hudState.BackpackWasEnabled = backpack:GetBackpackEnabled()
			end
			backpack:SetBackpackEnabled(false)
		elseif Store._hudState and Store._hudState.BackpackWasEnabled ~= nil then
			backpack:SetBackpackEnabled(Store._hudState.BackpackWasEnabled)
		end
	end

	if not hidden then
		Store._hudState = nil
	end
end

function Store._setCharacterObjectHidden(object, hidden)
	if not object then
		return
	end

	if not Store._otherPlayerVisibilityOriginals then
		Store._otherPlayerVisibilityOriginals = {}
	end

	local originals = Store._otherPlayerVisibilityOriginals
	if object:IsA("BasePart") then
		if hidden then
			if originals[object] == nil then
				originals[object] = object.LocalTransparencyModifier
			end
			object.LocalTransparencyModifier = 1
		elseif originals[object] ~= nil then
			object.LocalTransparencyModifier = originals[object]
			originals[object] = nil
		end
	elseif object:IsA("Decal") or object:IsA("Texture") then
		if hidden then
			if originals[object] == nil then
				originals[object] = object.Transparency
			end
			object.Transparency = 1
		elseif originals[object] ~= nil then
			object.Transparency = originals[object]
			originals[object] = nil
		end
	elseif
		object:IsA("BillboardGui")
		or object:IsA("SurfaceGui")
		or object:IsA("ParticleEmitter")
		or object:IsA("Trail")
		or object:IsA("Beam")
	then
		if hidden then
			if originals[object] == nil then
				originals[object] = object.Enabled
			end
			object.Enabled = false
		elseif originals[object] ~= nil then
			object.Enabled = originals[object]
			originals[object] = nil
		end
	end
end

function Store._setCharacterHidden(character, hidden)
	if not character then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		Store._setCharacterObjectHidden(descendant, hidden)
	end
end

function Store._bindOtherPlayerVisibility(player)
	if not Store._otherPlayerVisibilityConnections then
		Store._otherPlayerVisibilityConnections = {}
	end

	if Store._otherPlayerVisibilityConnections[player] then
		return
	end

	local connections = {}
	Store._otherPlayerVisibilityConnections[player] = connections

	local function bindCharacter(character)
		if not character then
			return
		end

		Store._setCharacterHidden(character, true)
		table.insert(
			connections,
			character.DescendantAdded:Connect(function(descendant)
				if Store._otherPlayersHidden then
					Store._setCharacterObjectHidden(descendant, true)
				end
			end)
		)
	end

	table.insert(
		connections,
		player.CharacterAdded:Connect(function(character)
			task.defer(bindCharacter, character)
		end)
	)

	if player.Character then
		bindCharacter(player.Character)
	end
end

function Store._restoreOtherPlayerVisibility()
	if Store._otherPlayerVisibilityConnections then
		for player, connections in pairs(Store._otherPlayerVisibilityConnections) do
			for _, connection in ipairs(connections) do
				if connection.Connected then
					connection:Disconnect()
				end
			end
			Store._otherPlayerVisibilityConnections[player] = nil
		end
	end

	if Store._otherPlayerVisibilityOriginals then
		for object, originalValue in pairs(Store._otherPlayerVisibilityOriginals) do
			if object and object.Parent then
				if object:IsA("BasePart") then
					object.LocalTransparencyModifier = originalValue
				elseif object:IsA("Decal") or object:IsA("Texture") then
					object.Transparency = originalValue
				elseif
					object:IsA("BillboardGui")
					or object:IsA("SurfaceGui")
					or object:IsA("ParticleEmitter")
					or object:IsA("Trail")
					or object:IsA("Beam")
				then
					object.Enabled = originalValue
				end
			end
			Store._otherPlayerVisibilityOriginals[object] = nil
		end
	end
end

function Store._setOtherPlayersHidden(hidden)
	if hidden then
		if Store._otherPlayersHidden then
			return
		end

		Store._otherPlayersHidden = true
		Store._otherPlayerVisibilityOriginals = Store._otherPlayerVisibilityOriginals or {}
		Store._otherPlayerVisibilityConnections = Store._otherPlayerVisibilityConnections or {}

		for _, player in ipairs(Players:GetPlayers()) do
			Store._bindOtherPlayerVisibility(player)
		end

		if not Store._otherPlayerAddedConnection then
			Store._otherPlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
				if Store._otherPlayersHidden then
					Store._bindOtherPlayerVisibility(player)
				end
			end)
		end
	else
		if not Store._otherPlayersHidden then
			return
		end

		Store._otherPlayersHidden = false
		if Store._otherPlayerAddedConnection then
			Store._otherPlayerAddedConnection:Disconnect()
			Store._otherPlayerAddedConnection = nil
		end
		Store._restoreOtherPlayerVisibility()
	end
end

function Store._releaseFocus()
	if Store._focusOwnerId then
		local focusCameraController = Mince:Get("FocusCameraController")
		if focusCameraController and focusCameraController.Release then
			focusCameraController:Release(Store._focusOwnerId)
		end
	end

	Store._focusOwnerId = nil
end

function Store._focusModel(model, options)
	if not model or not model:IsA("Model") then
		return
	end

	local focusCameraController = Mince:Get("FocusCameraController")
	if not focusCameraController or not focusCameraController.FocusModel then
		return
	end

	options = options or {}
	local ownerId = options.OwnerId or "StoreNpcFocus"
	local focused = focusCameraController:FocusModel(model, {
		OwnerId = ownerId,
		Context = "Store",
		Distance = options.Distance or model:GetAttribute("ShopCameraDistance") or 6,
		Height = options.Height or model:GetAttribute("ShopCameraHeight") or 1.6,
		SideOffset = options.SideOffset or model:GetAttribute("ShopCameraSideOffset") or 1.4,
		FocusHeight = options.FocusHeight or model:GetAttribute("ShopCameraFocusHeight") or 0.15,
		LookSideOffset = options.LookSideOffset or model:GetAttribute("ShopCameraLookSideOffset") or 0,
		LookHeightOffset = options.LookHeightOffset or model:GetAttribute("ShopCameraLookHeightOffset") or 0,
		FieldOfView = options.FieldOfView or model:GetAttribute("ShopCameraFieldOfView") or 82,
		Behind = options.Behind == true or model:GetAttribute("ShopCameraBehind") == true,
		LockCharacter = options.LockCharacter ~= false,
	})

	if focused then
		Store._focusOwnerId = ownerId
	end
end

function Store._prepareShowOptions(options)
	options = options or {}
	Store._onHidden = options.OnHidden or Store._onHidden
	Store._releaseFocusOnHide = options.ReleaseFocusOnHide == true or Store._releaseFocusOnHide == true

	if options.FocusModel then
		Store._focusModel(options.FocusModel, options.Camera)
	end
end

function Store.Show(options)
	options = options or {}
	if not Store.Gui then
		return
	end
	local dock = options.Dock or Store.DefaultDock

	Store._prepareShowOptions(options)
	Store._setHudHidden(true)
	Store._setOtherPlayersHidden(true)

	if Store._isVisible then
		Store.Gui.Enabled = true
		startMerchantMusic()
		Store._applyLayout(dock)
		if options.FocusModel then
			Store._focusModel(options.FocusModel, options.Camera)
		end
		return
	end

	Store._stopActiveTween()

	Store.Gui.Enabled = true
	startMerchantMusic()
	Store._applyLayout(dock)

	if options.FocusModel then
		Store._focusModel(options.FocusModel, options.Camera)
	end

	if Store.Main then
		Store.Main.Visible = true
	end

	Store._showPanelControl(dock)

	Store._isVisible = true

	Store.DisplayCategory(Store.CurrentCategory)
end

function Store.ShowDocked(options)
	options = options or {}
	options.Dock = options.Dock or "Left"

	if not Store.Gui then
		return
	end

	Store._stopActiveTween()
	Store._prepareShowOptions(options)
	Store._setHudHidden(true)
	Store._setOtherPlayersHidden(true)

	Store.Gui.Enabled = true
	startMerchantMusic()
	if Store.Main then
		Store.Main.Visible = true
	end

	Store._applyLayout(options.Dock)
	Store._showPanelControl(options.Dock)
	task.delay(0.28, function()
		if Store._isVisible then
			Store._lockLayoutForFrames(options.Dock)
		end
	end)

	Store._isVisible = true
	Store.DisplayCategory(Store.CurrentCategory)
end

function Store.Hide()
	if not Store.Gui then
		return
	end

	if not Store._isVisible and not Store.Gui.Enabled then
		return
	end

	stopMerchantMusic()
	Store._stopActiveTween()
	Store.HideItemDetails(true)

	local finalize = function()
		if Store.Gui then
			Store.Gui.Enabled = false
		end

		if Store.Main then
			Store.Main.Visible = false
		end

		if Store._scale then
			Store._scale.Scale = 0
		end
		Store._isVisible = false
		Store._layoutLockToken = nil
		Store._setHudHidden(false)
		Store._setOtherPlayersHidden(false)
		if Store._releaseFocusOnHide then
			Store._releaseFocus()
		end
		Store._releaseFocusOnHide = false
		if Store._onHidden then
			Store._onHidden()
			Store._onHidden = nil
		end
	end

	Store._hidePanelControl(finalize)
end

function Store.GetItemBox(itemName)
	if not itemName or not Store.LoadedBoxes then
		return nil
	end

	for _, shopBox in ipairs(Store.LoadedBoxes) do
		if shopBox and shopBox.Name == itemName then
			return shopBox
		end
	end

	return nil
end

function Store.GetItemButton(itemName)
	local shopBox = Store.GetItemBox(itemName)
	if not shopBox then
		return nil
	end

	return shopBox:FindFirstChild("Price") or shopBox:FindFirstChild("ActionButton")
end

function Store.IsVisible()
	return Store._isVisible == true
end

function Store:IsRobuxModifierDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

function Store:GetRobuxPriceText(assetId, itemName, itemData)
	if not assetId then
		return nil
	end

	if Store.RobuxPriceCache[assetId] ~= nil then
		local price = Store.RobuxPriceCache[assetId]
		if price and price > 0 then
			return "R$" .. tostring(price)
		end
		return "R$?"
	end

	if not Store.RobuxPricePending[assetId] then
		Store.RobuxPricePending[assetId] = true
		task.spawn(function()
			local success, info =
				pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId, Enum.InfoType.Asset)
			local price = success and info and info.PriceInRobux or 0
			Store.RobuxPriceCache[assetId] = price
			Store.RobuxPricePending[assetId] = nil

			local function updateButton()
				local button = Store.GetItemButton(itemName)
				if button then
					Store.UpdateButtonState(button, itemName, itemData)
					return true
				end
				return false
			end

			if not updateButton() then
				task.defer(updateButton)
			end
		end)
	end

	return "R$..."
end

function Store:PromptRobuxPurchase(itemData, itemName)
	local assetId = itemData and itemData.RobuxAssetId
	if not assetId then
		return false
	end

	local success, err = pcall(function()
		MarketplaceService:PromptPurchase(Players.LocalPlayer, assetId)
	end)

	if not success then
		warn("PromptPurchase failed for", itemName, err)
		if Store.Interface and Store.Interface.Notify then
			Store.Interface.Notify("Robux purchase failed. Please try again.", "Error", 4)
		end
	end

	return success
end

function Store.UpdateButtonState(button, itemName, itemData)
	local itemState = Store.OwnedItems[itemName]

	if not button or not button:IsA("GuiButton") then
		return
	end

	if button.AnchorPoint ~= Vector2.new(0.5, 0.5) then
		local currentPos = button.Position
		local absolutePos = Vector2.new(
			currentPos.X.Scale * button.Parent.AbsoluteSize.X + currentPos.X.Offset,
			currentPos.Y.Scale * button.Parent.AbsoluteSize.Y + currentPos.Y.Offset
		)
		local adjustedPos = absolutePos + Vector2.new(button.AbsoluteSize.X * 0.5, button.AbsoluteSize.Y * 0.5)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position =
			UDim2.new(adjustedPos.X / button.Parent.AbsoluteSize.X, 0, adjustedPos.Y / button.Parent.AbsoluteSize.Y, 0)
	end

	local baseColor
	local strokeColor
	local textColor = Color3.fromRGB(255, 255, 255)

	if itemState and itemState.Owned then
		if itemState.Equipped then
			button.Text = "EQUIPPED"
			baseColor = Color3.fromRGB(39, 174, 96)
			strokeColor = Color3.fromRGB(46, 204, 113)
			button.Font = Enum.Font.GothamBold
		else
			button.Text = "EQUIP"
			baseColor = Color3.fromRGB(41, 128, 185)
			strokeColor = Color3.fromRGB(52, 152, 219)
			button.Font = Enum.Font.GothamBold
		end
	else
		local requiresGamepass = false
		local passDef = itemData.Gamepass

		if passDef then
			if type(passDef) == "string" then
				for _, config in pairs(Mince.Config) do
					if
						type(config) == "table"
						and (config.Key == passDef or config.Name == passDef)
						and config.EntitlementAttribute
					then
						passDef = config
						break
					end
				end
			end

			if type(passDef) == "table" and passDef.EntitlementAttribute then
				if not Players.LocalPlayer:GetAttribute(passDef.EntitlementAttribute) then
					requiresGamepass = true
				end
			end
		end

		if requiresGamepass then
			local passName = (type(passDef) == "table" and (passDef.Name or passDef.Key)) or "GAME"
			button.Text = string.upper("BUY " .. passName .. " PASS")
			baseColor = Color3.fromRGB(155, 89, 182)
			strokeColor = Color3.fromRGB(142, 68, 173)
			button.Font = Enum.Font.GothamBlack
		elseif passDef or itemData.Price == 0 then
			button.Text = "EQUIP"
			baseColor = Color3.fromRGB(41, 128, 185)
			strokeColor = Color3.fromRGB(52, 152, 219)
			button.Font = Enum.Font.GothamBold
		else
			local currency = Store:GetCurrencyConfig(itemName)
			button.Text = currency.prefix .. tostring(itemData.Price)
			baseColor = Color3.fromRGB(211, 84, 0)
			strokeColor = Color3.fromRGB(230, 126, 34)
			button.Font = Enum.Font.GothamBlack
		end

		local robuxButton = button.Parent and button.Parent:FindFirstChild("RobuxButton")
		if robuxButton and itemData.RobuxAssetId and not requiresGamepass then
			robuxButton.Visible = true
			robuxButton.Text = Store:GetRobuxPriceText(itemData.RobuxAssetId, itemName, itemData)
		elseif robuxButton then
			robuxButton.Visible = false
		end
	end

	button.BackgroundColor3 = baseColor
	button.TextColor3 = textColor

	button.TextTransparency = 0
	button.BorderSizePixel = 0
	button.TextScaled = true

	local textSizeConstraint = button:FindFirstChild("UITextSizeConstraint")
	if not textSizeConstraint then
		textSizeConstraint = Instance.new("UITextSizeConstraint")
		textSizeConstraint.MaxTextSize = 20
		textSizeConstraint.MinTextSize = 10
		textSizeConstraint.Parent = button
	end

	local uiCorner = button:FindFirstChild("UICorner")
	if not uiCorner then
		uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(0, 8)
		uiCorner.Parent = button
	end

	local uiStroke = button:FindFirstChild("UIStroke")
	if not uiStroke then
		uiStroke = Instance.new("UIStroke")
		uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		uiStroke.Thickness = 2
		uiStroke.Parent = button
	end
	uiStroke.Color = strokeColor
	uiStroke.Transparency = 0

	local uiGradient = button:FindFirstChild("UIGradient")
	if not uiGradient then
		uiGradient = Instance.new("UIGradient")
		uiGradient.Rotation = 90
		uiGradient.Parent = button
	end

	uiGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.85, 0.85, 0.85)),
	})
end

function Store:OnActionButtonClick(itemName, category, itemData)
	local itemState = Store.OwnedItems[itemName]
	local currentBalance = category == "Cosmetics" and Store.EcoBalance or Store.Balance

	if itemData.RobuxAssetId and Store:IsRobuxModifierDown() then
		Store:PromptRobuxPurchase(itemData, itemName)
		return
	end

	if not itemState or not itemState.Owned then
		if itemData.Gamepass then
			local passDef = itemData.Gamepass
			if type(passDef) == "string" then
				for _, config in pairs(Mince.Config) do
					if
						type(config) == "table"
						and (config.Key == passDef or config.Name == passDef)
						and config.EntitlementAttribute
					then
						passDef = config
						break
					end
				end
			end

			if type(passDef) == "table" and passDef.EntitlementAttribute then
				if not Players.LocalPlayer:GetAttribute(passDef.EntitlementAttribute) then
					local passId = passDef.Id or passDef.GamepassId

					if RunService:IsStudio() and passId then
						local success, owns = pcall(function()
							return MarketplaceService:UserOwnsGamePassAsync(Players.LocalPlayer.UserId, passId)
						end)

						if success and owns then
							Players.LocalPlayer:SetAttribute(passDef.EntitlementAttribute, true)

							for _, shopBox in pairs(Store.LoadedBoxes) do
								if shopBox and shopBox.Parent then
									local actionButton = shopBox:FindFirstChild("Price")
										or shopBox:FindFirstChild("ActionButton")
									if actionButton and actionButton:GetAttribute("ItemName") == itemName then
										Store.UpdateButtonState(actionButton, itemName, itemData)
										break
									end
								end
							end
							return
						end
					end

					if passId then
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, passId)
					else
						warn("Gamepass ID not found for", itemName)
					end
					return
				end
			end
		end

		if currentBalance >= itemData.Price then
			Store.PurchaseRequest:Fire(category, itemName)
			print(`Requesting purchase: {itemName}`)

			if itemData.Gamepass or itemData.Price == 0 then
				Store.PendingAutoEquip = {
					ItemName = itemName,
					Category = category,
					Slot = itemData.Slot,
				}
			end
		else
			if itemData.RobuxAssetId then
				Store:PromptRobuxPurchase(itemData, itemName)
			end
			local currency = Store:GetCurrencyConfig(itemName)
			Store:OnPurchaseResult(
				false,
				`Need ${currency.prefix}${itemData.Price}, have ${currency.prefix}${currentBalance}`,
				itemName
			)
		end
		return
	end

	if itemState.Equipped then
		local dependentItems = {}
		for catName, items in pairs(Store.StoreItems.Categories) do
			for dependentItemName, dependentItemData in pairs(items) do
				if dependentItemData.Prerequisites then
					for _, prereqName in ipairs(dependentItemData.Prerequisites) do
						if prereqName == itemName then
							local dependentState = Store.OwnedItems[dependentItemName]
							if dependentState and dependentState.Equipped then
								table.insert(dependentItems, {
									name = dependentItemName,
									category = catName,
									data = dependentItemData,
								})
							end
						end
					end
				end
			end
		end

		for _, dependent in ipairs(dependentItems) do
			Store.UnequipRequest:Fire(dependent.name)
			print(`Auto-unequipping dependent item: {dependent.name}`)
		end

		Store.UnequipRequest:Fire(itemName)
		print(`Requesting unequip: {itemName}`)
		return
	end

	if itemData.Prerequisites then
		for _, prereqName in ipairs(itemData.Prerequisites) do
			local prereqState = Store.OwnedItems[prereqName]
			if prereqState and prereqState.Owned and not prereqState.Equipped then
				local prereqCategory = nil
				local prereqData = nil
				for cat, items in pairs(Store.StoreItems.Categories) do
					if items[prereqName] then
						prereqCategory = cat
						prereqData = items[prereqName]
						break
					end
				end
				if prereqCategory and prereqData then
					Store.EquipRequest:Fire(prereqCategory, prereqName, prereqData.Slot)
					print(`Auto-equipping prerequisite: {prereqName}`)
				end
			end
		end
	end

	Store.EquipRequest:Fire(category, itemName, itemData.Slot)
	print(`Requesting equip: {itemName}`)
end

function Store:OnPurchaseResult(success, message, itemName)
	if success then
		Store.PlayPurchaseEffect(itemName)
		if Store.Interface and Store.Interface.Notify then
			Store.Interface.Notify(`{itemName} purchased!`, "Success", 3)
		end
		Store.RequestInventory:Fire()
		if Store.PendingAutoEquip and Store.PendingAutoEquip.ItemName == itemName then
			local info = Store.PendingAutoEquip
			Store.EquipRequest:Fire(info.Category, info.ItemName, info.Slot)
			Store.PendingAutoEquip = nil
		end
	else
		Store.PendingAutoEquip = nil
		local currency = Store:GetCurrencyConfig(itemName)
		local symbolPattern = currency.prefix:gsub("(%W)", "%%%1")
		local need, have = message:match("Need " .. symbolPattern .. "(%d+), have " .. symbolPattern .. "(%d+)")
		local isCosmetics = Store:GetItemCategory(itemName) == "Cosmetics"
		local currencyLabel = isCosmetics and Store.EcoSymbol or "coins"
		local earnTip = isCosmetics and "cleaning the ocean" or "scanning new species"
		local earnTipCapitalized = earnTip:sub(1, 1):upper() .. earnTip:sub(2)

		local function notifyRandom(messages, duration)
			Store.Interface.Notify(messages[math.random(1, #messages)], "Info", duration)
		end

		if need and have then
			need = tonumber(need)
			have = tonumber(have)

			local shortage = need - have
			local messages = {
				`You're ${shortage} short! Go ${earnTip} to earn ${currencyLabel}! 🐟`,
				`Not enough ${currencyLabel}! Need ${need} but only have ${have}. Try ${earnTip}! 🔍`,
				`You're broke! Short by ${shortage} ${currencyLabel}. Check your achievements! 🏆`,
				`Need ${shortage} more ${currencyLabel}! Explore deeper waters for rare fish! 🌊`,
				`Oops! ${shortage} ${currencyLabel} short. Complete achievements to earn more! ⭐`,
				`Can't afford it! Need ${need}, have ${have}. ${earnTipCapitalized}! 📖`,
			}
			notifyRandom(messages, 5)
		else
			Store.Interface.Notify(`Not enough ${currencyLabel}! {message}`, "Info", 4)
		end
	end
	Store:RefreshDetailPanel()
end

function Store:OnEquipResult(success, message, itemName)
	print(`Equip result: {success}, {message}, {itemName}`)

	if success then
		if message and message:lower():find("unequip") then
			local unequipMessages = {
				`{itemName} unequipped! 👋`,
				`{itemName} removed! ✓`,
				`Unequipped {itemName}! 🎒`,
				`{itemName} stored away! 📦`,
			}
			local randomMessage = unequipMessages[math.random(1, #unequipMessages)]
			Store.Interface.Notify(randomMessage, "Info", 3)
		else
			local equipMessages = {
				`{itemName} equipped! ✨`,
				`Now wearing {itemName}! 🎯`,
				`{itemName} equipped successfully! ⚡`,
				`{itemName} is ready to use! 🚀`,
			}
			local randomMessage = equipMessages[math.random(1, #equipMessages)]
			Store.Interface.Notify(randomMessage, "Success", 3)
		end
	else
		Store.Interface.Notify(`Failed to equip {itemName}: {message}`, "Error", 4)
	end
	Store:RefreshDetailPanel()
end

function Store:UpdateInventory(inventoryData)
	Store.OwnedItems = inventoryData.OwnedItems or {}
	Store.Balance = inventoryData.Balance or 0
	Store.EcoBalance = inventoryData.EcoBalance or Store.EcoBalance

	for _, cards in pairs(Store.CategoryCardCache) do
		for _, card in ipairs(cards) do
			if card and card.Parent then
				local category = card:GetAttribute("SourceCategory")
				local itemData = category
					and Store.StoreItems.Categories[category]
					and Store.StoreItems.Categories[category][card.Name]
				if itemData then
					Store.UpdateCardOwnership(card, itemData)
				end
			end
		end
	end

	for _, shopBox in pairs(Store.LoadedBoxes) do
		if shopBox and shopBox.Parent then
			local actionButton = shopBox:FindFirstChild("Price") or shopBox:FindFirstChild("ActionButton")
			local descriptionLabel = shopBox:FindFirstChild("Description", true)

			if actionButton then
				local itemName = actionButton:GetAttribute("ItemName")
				local category = actionButton:GetAttribute("Category")

				if itemName and category then
					local itemData = Store.StoreItems.Categories[category]
						and Store.StoreItems.Categories[category][itemName]
					if itemData then
						Store.UpdateButtonState(actionButton, itemName, itemData)

						if descriptionLabel then
							local descText = buildDescriptionText(itemData)
							if descText ~= "" then
								descriptionLabel.Text = descText
								descriptionLabel.TextTransparency = 0
								descriptionLabel.Visible = true
							end
						end
					end
				end
			end
		end
	end
	Store:RefreshDetailPanel()
end

return Store
