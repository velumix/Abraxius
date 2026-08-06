local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Marketplace = require(Modules.Marketplace)
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)
local MarketplaceProducts = Mince.Config.MarketplaceProducts
	or require(ReplicatedStorage.Runtime.Config.Shared.MarketplaceProducts)

local GamepassSlots = {}
for _, config in pairs(Mince.Config) do
	if type(config) == "table" and config.StoreSlot and config.GamepassId then
		if not config.StoreSlot.type then
			config.StoreSlot.type = "Gamepass"
		end
		if config.EntitlementAttribute then
			config.StoreSlot.EntitlementAttribute = config.EntitlementAttribute
		end
		table.insert(GamepassSlots, config.StoreSlot)
	end
end

table.sort(GamepassSlots, function(a, b)
	if a.price ~= b.price then
		return (a.price or 0) < (b.price or 0)
	end
	return (a.name or "") < (b.name or "")
end)

local CurrencyProducts = {}
for _, product in ipairs(MarketplaceProducts.DeveloperProducts) do
	if product.CurrencyAmount then
		table.insert(CurrencyProducts, {
			coins = product.CurrencyAmount,
			id = product.Id,
		})
	end
end

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local FADE_IN_DURATION = 0.3
local FADE_OUT_DURATION = 0.2
local BUTTON_HOVER_DURATION = 0.2
local BUTTON_CLICK_DURATION = 0.1

local TWEEN_INFO_IN = TweenInfo.new(FADE_IN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_OUT = TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local BACKING_TWEEN_INFO_IN = TweenInfo.new(FADE_IN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BACKING_TWEEN_INFO_OUT = TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(BUTTON_HOVER_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local BUTTON_CLICK_TWEEN_INFO = TweenInfo.new(BUTTON_CLICK_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local ZERO_SIZE = UDim2.new(0, 0, 0, 0)
local CENTER_POSITION = UDim2.fromScale(0.5, 0.5)
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)

local BUTTON_HOVER_SCALE = 1.15
local BUTTON_CLICK_SCALE = 0.85

local BUTTON_HOVER_COLOR = UIColors.ButtonHoverAlt
local BUTTON_CLICK_COLOR = UIColors.ButtonClick

local EXIT_BUTTON_NORMAL_COLOR = UIColors.ExitNormal
local EXIT_BUTTON_HOVER_COLOR = UIColors.ExitHover
local EXIT_BUTTON_CLICK_COLOR = UIColors.ExitClick

local GUI = PlayerGui:WaitForChild("Shop", 10)
local Main = GUI:WaitForChild("Main")

local originalSizes = {}
local originalPositions = {}
local originalColors = {}
local currentTweens = {}
local shopConnections = {}

local function formatNumber(n)
	return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local Shop = {
	Tweens = {
		Show = {},
		Hide = {},
	},
	GamepassCards = {},
	DonationButtons = {},
	DonationContainer = nil,
	GamepassContainer = nil,
	BackButton = nil,
	ExitButton = nil,
	Container = nil,
	UIAspectRatioConstraint = nil,
	Initialized = false,
	PurchaseEvents = nil,
	PurchasePromptEvent = nil,
	PurchaseResultEvent = nil,
	_purchaseResultConnection = nil,
}

local function validateProduct(id, infoType, label)
	if not id then
		return false, "Missing product ID"
	end

	if RunService:IsStudio() then
		return true, nil
	end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType or Enum.InfoType.Product)
	end)

	if not success then
		warn(string.format("[Shop] Could not verify %s (ID: %s) - proceeding anyway", label or "product", tostring(id)))
		return true, nil
	end

	if info.IsForSale == false then
		return false, "Item is not currently for sale"
	end

	if info.CanBeSoldInThisGame == false then
		return false, "Item is restricted to this experience"
	end

	return true, nil
end

local AnimatedBackground = require(ReplicatedStorage.Modules.UI.Effects.AnimatedBackground)
local BackgroundEffect = AnimatedBackground.new(function()
	return Shop.IsVisible()
end, function()
	return Main.AbsoluteSize.Y
end)

function Shop.GetAvailableGamepasses()
	local gamepassIds = {}
	for _, slot in ipairs(GamepassSlots) do
		if slot.id then
			table.insert(gamepassIds, slot.id)
		end
	end
	table.sort(gamepassIds)
	return gamepassIds
end

function Shop.GetAvailableProducts()
	local productIds = {}
	for _, slot in ipairs(CurrencyProducts) do
		if slot.id then
			table.insert(productIds, slot.id)
		end
	end
	table.sort(productIds)
	return productIds
end

local function cleanupTweens(...)
	local specificKeys = { ... }
	if #specificKeys > 0 then
		for _, key in ipairs(specificKeys) do
			if currentTweens[key] then
				currentTweens[key]:Cancel()
				currentTweens[key] = nil
			end
		end
	else
		for key, tween in pairs(currentTweens) do
			if tween and typeof(tween) == "Instance" then
				tween:Cancel()
			end
			currentTweens[key] = nil
		end
		currentTweens = {}
	end
end

local function addShopConnection(connection)
	if connection and typeof(connection) == "RBXScriptConnection" then
		table.insert(shopConnections, connection)
	end
end

local function cleanupShopConnections()
	for i = #shopConnections, 1, -1 do
		local connection = shopConnections[i]
		if connection then
			connection:Disconnect()
		end
		shopConnections[i] = nil
	end
end

function Shop:Build()
	self.Container = Main:FindFirstChild("Container")
	self.UIAspectRatioConstraint = Main:FindFirstChild("UIAspectRatioConstraint")
	self.BackButton = Main:FindFirstChild("Back")
	self.ExitButton = Main:FindFirstChild("Exit")

	self.GamepassCards = {}
	self.CurrencyButtons = {}
	self.GamepassContainer = nil
	self.CurrencyContainer = nil
	self.CurrencyTemplate = nil

	if self.Container then
		local donationsGroup = self.Container:FindFirstChild("Donations")
		if donationsGroup then
			local frame = donationsGroup:FindFirstChild("Frame")
			if frame then
				self.CurrencyContainer = frame:FindFirstChild("DonationContainer")
			end
		end

		if not self.CurrencyContainer then
			self.CurrencyContainer = self.Container:FindFirstChild("DonationContainer", true)
		end

		if self.CurrencyContainer then
			self.CurrencyTemplate = self.CurrencyContainer:FindFirstChild("CurrencyTemplate")

			if self.CurrencyTemplate then
				self.CurrencyTemplate.Visible = false

				for _, child in pairs(self.CurrencyContainer:GetChildren()) do
					if
						child ~= self.CurrencyTemplate
						and not child:IsA("UIListLayout")
						and not child:IsA("UIGridLayout")
						and not child:IsA("UIPadding")
					then
						child:Destroy()
					end
				end

				for i, product in ipairs(CurrencyProducts) do
					local button = self.CurrencyTemplate:Clone()
					button.Name = "Product_" .. product.coins
					button.LayoutOrder = i
					button.Visible = true
					button.Parent = self.CurrencyContainer

					button:SetAttribute("ProductId", product.id)
					button:SetAttribute("Coins", product.coins)

					local listLayout = button:FindFirstChildOfClass("UIListLayout")
					if listLayout then
						listLayout.Padding = UDim.new(0, 15)
						listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
						listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
					end

					local padding = button:FindFirstChildOfClass("UIPadding")
					if not padding then
						padding = Instance.new("UIPadding")
						padding.PaddingLeft = UDim.new(0.15, 0)
						padding.Parent = button
					end

					local textLabel = button:FindFirstChild("TextLabel")
					if textLabel then
						textLabel.Size = UDim2.fromScale(0.6, 0.8)
						textLabel.TextXAlignment = Enum.TextXAlignment.Left
						textLabel.Text = formatNumber(product.coins) .. " Coins"
					end

					table.insert(self.CurrencyButtons, button)
				end
			end
		end

		self.GamepassContainer = self.Container:FindFirstChild("Passes", true) or self.Container

		local template = nil
		if self.GamepassContainer then
			for _, child in ipairs(self.GamepassContainer:GetChildren()) do
				if child:IsA("GuiObject") and child.Name:match("^Gamepass") then
					template = child
					break
				end
			end
		end

		if template then
			template.Visible = false

			for _, child in ipairs(self.GamepassContainer:GetChildren()) do
				local isLayout = child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding")
				if child ~= template and child:IsA("GuiObject") and child.Name:match("^Gamepass") and not isLayout then
					child:Destroy()
				end
			end

			for i = 1, #GamepassSlots do
				local card = template:Clone()
				card.Name = "Gamepass_" .. i
				card.LayoutOrder = i
				card.Visible = true
				card.Parent = self.GamepassContainer
				table.insert(self.GamepassCards, card)
			end
		end
	end

	self:CreateTweens()
	BackgroundEffect:AddAll(self.Container or Main)
	self.Initialized = true
end

function Shop:CreateTweens()
	self.Tweens.Show.Main = TweenService:Create(Main, TWEEN_INFO_IN, {
		Size = originalSizes.Main or Main.Size,
		Position = originalPositions.Main or Main.Position,
	})

	self.Tweens.Hide.Main = TweenService:Create(Main, TWEEN_INFO_OUT, {
		Size = ZERO_SIZE,
		Position = CENTER_POSITION,
	})

	if self.Container then
		self.Tweens.Show.Container = TweenService:Create(self.Container, BACKING_TWEEN_INFO_IN, {
			Size = originalSizes.Container or self.Container.Size,
			Position = originalPositions.Container or self.Container.Position,
		})

		self.Tweens.Hide.Container = TweenService:Create(self.Container, BACKING_TWEEN_INFO_OUT, {
			Size = ZERO_SIZE,
			Position = CENTER_POSITION,
		})
	else
		self.Tweens.Show.Container = nil
		self.Tweens.Hide.Container = nil
	end
end

function Shop:ConnectNav()
	if self.BackButton then
		addShopConnection(self.BackButton.MouseButton1Click:Connect(function()
			Shop.Hide()
		end))
		Shop.HoverEffect(self.BackButton, "back")
	end

	local exitButton = self.ExitButton and self.ExitButton:FindFirstChildOfClass("ImageButton")
	if exitButton then
		addShopConnection(exitButton.MouseButton1Click:Connect(function()
			Shop.Hide()
		end))
		Shop.HoverEffect(exitButton, "exit", EXIT_BUTTON_HOVER_COLOR, EXIT_BUTTON_CLICK_COLOR)
	end
end

function Shop:ConnectGamepasses()
	for i, card in ipairs(self.GamepassCards) do
		local purchaseButton = card:FindFirstChild("ImageButton", true)
		if purchaseButton then
			addShopConnection(purchaseButton.MouseButton1Click:Connect(function()
				Shop.BuyGamepass(i, card)
			end))
			Shop.HoverEffect(purchaseButton, "gamepass_" .. i)
		end

		if card:IsA("GuiButton") then
			addShopConnection(card.MouseButton1Click:Connect(function()
				Shop.ClickGamepass(i, card)
			end))
			Shop.HoverEffect(card, "gamepass_card_" .. i)
		end
	end
end

function Shop:ConnectCurrency()
	for i, button in ipairs(self.CurrencyButtons) do
		addShopConnection(button.MouseButton1Click:Connect(function()
			Shop.BuyCurrency(button)
		end))
		Shop.HoverEffect(button, "currency_" .. i)
	end
end

function Shop.HoverEffect(button, buttonKey, hoverColor, clickColor)
	if not button then
		return
	end

	local originalSize = button.Size
	local originalColor = button.BackgroundColor3

	originalColors[buttonKey] = originalColor

	hoverColor = hoverColor or BUTTON_HOVER_COLOR
	clickColor = clickColor or BUTTON_CLICK_COLOR

	local hoverSize = UDim2.new(
		originalSize.X.Scale * BUTTON_HOVER_SCALE,
		originalSize.X.Offset,
		originalSize.Y.Scale * BUTTON_HOVER_SCALE,
		originalSize.Y.Offset
	)
	local clickSize = UDim2.new(
		originalSize.X.Scale * BUTTON_CLICK_SCALE,
		originalSize.X.Offset,
		originalSize.Y.Scale * BUTTON_CLICK_SCALE,
		originalSize.Y.Offset
	)

	addShopConnection(button.MouseEnter:Connect(function()
		cleanupTweens(buttonKey .. "_hoverOut")
		button.BackgroundColor3 = hoverColor

		currentTweens[buttonKey .. "_hoverIn"] = TweenService:Create(button, BUTTON_HOVER_TWEEN_INFO, {
			Size = hoverSize,
		})

		addShopConnection(currentTweens[buttonKey .. "_hoverIn"].Completed:Connect(function()
			currentTweens[buttonKey .. "_hoverIn"] = nil
		end))
		currentTweens[buttonKey .. "_hoverIn"]:Play()
	end))

	addShopConnection(button.MouseLeave:Connect(function()
		cleanupTweens(buttonKey .. "_hoverIn", buttonKey .. "_clickUp")
		button.BackgroundColor3 = originalColor

		currentTweens[buttonKey .. "_hoverOut"] = TweenService:Create(button, BUTTON_HOVER_TWEEN_INFO, {
			Size = originalSize,
		})

		addShopConnection(currentTweens[buttonKey .. "_hoverOut"].Completed:Connect(function()
			currentTweens[buttonKey .. "_hoverOut"] = nil
		end))
		currentTweens[buttonKey .. "_hoverOut"]:Play()
	end))

	addShopConnection(button.MouseButton1Down:Connect(function()
		cleanupTweens(buttonKey .. "_hoverIn")
		button.BackgroundColor3 = clickColor

		currentTweens[buttonKey .. "_clickDown"] = TweenService:Create(button, BUTTON_CLICK_TWEEN_INFO, {
			Size = clickSize,
		})

		addShopConnection(currentTweens[buttonKey .. "_clickDown"].Completed:Connect(function()
			currentTweens[buttonKey .. "_clickDown"] = nil
		end))
		currentTweens[buttonKey .. "_clickDown"]:Play()
	end))

	addShopConnection(button.MouseButton1Up:Connect(function()
		cleanupTweens(buttonKey .. "_clickDown")
		button.BackgroundColor3 = hoverColor

		currentTweens[buttonKey .. "_clickUp"] = TweenService:Create(button, BUTTON_CLICK_TWEEN_INFO, {
			Size = hoverSize,
		})

		addShopConnection(currentTweens[buttonKey .. "_clickUp"].Completed:Connect(function()
			currentTweens[buttonKey .. "_clickUp"] = nil
		end))
		currentTweens[buttonKey .. "_clickUp"]:Play()
	end))
end

local purchaseDebounce = false

function Shop.BuyGamepass(gamepassIndex, _gamepassCard)
	if purchaseDebounce then
		return
	end
	purchaseDebounce = true
	task.delay(1, function()
		purchaseDebounce = false
	end)

	print("Gamepass purchase attempt for index:", gamepassIndex)

	local item = GamepassSlots[gamepassIndex]
	if not item then
		warn("No item configured for gamepass index:", gamepassIndex)
		return
	end

	print("Attempting to purchase", item.name, "(" .. item.type .. "):", item.id)

	local player = Players.LocalPlayer
	if not player then
		warn("No local player to prompt purchase")
		return
	end

	local infoType = item.type == "Gamepass" and Enum.InfoType.GamePass or Enum.InfoType.Product
	local isValid, reason = validateProduct(item.id, infoType, item.name)
	if not isValid and reason then
		Shop.UI.Notify(string.format("%s is unavailable: %s", item.name or "Purchase", reason), "Error")
		return
	end

	if item.type == "Gamepass" then
		Marketplace.PromptPurchase(item.id, Enum.InfoType.GamePass)
	else
		Marketplace.PromptPurchase(item.id, Enum.InfoType.Product)
	end
end

function Shop.ClickGamepass(gamepassIndex, gamepassCard)
	Shop.BuyGamepass(gamepassIndex, gamepassCard)
end

function Shop.BuyCurrency(button)
	if purchaseDebounce then
		return
	end
	purchaseDebounce = true
	task.delay(1, function()
		purchaseDebounce = false
	end)

	local productId = button and button:GetAttribute("ProductId")
	local coins = button and button:GetAttribute("Coins")
	local label = string.format("%s Coins", coins or "Unknown")

	if not productId then
		Shop.UI.Notify("Product unavailable", "Error")
		return
	end

	local player = Players.LocalPlayer
	if not player then
		warn("No local player to prompt purchase")
		return
	end

	print("Currency purchase attempt:", coins, "-> Product ID:", productId)

	if not RunService:IsStudio() then
		local isValid, reason = validateProduct(productId, Enum.InfoType.Product, label)
		if not isValid and reason then
			Shop.UI.Notify(string.format("Unavailable: %s", reason), "Error")
			return
		end
	end

	local success, errorMsg = pcall(function()
		Marketplace.PromptPurchase(productId, Enum.InfoType.Product)
	end)

	if not success then
		warn("PromptProductPurchase failed:", errorMsg)
		Shop.UI.Notify("Purchase prompt failed: " .. tostring(errorMsg), "Error")
		return
	end
end

function Shop:ResetButtonStates()
	if not self.Initialized then
		return
	end

	local exitFrame = self.ExitButton
	local exitButton = exitFrame and exitFrame:FindFirstChildOfClass("ImageButton")
	if exitButton then
		local originalColor = originalColors["exit"] or EXIT_BUTTON_NORMAL_COLOR
		exitButton.BackgroundColor3 = originalColor
	end
end

function Shop.Show()
	cleanupTweens()

	if not Shop.Initialized then
		error("Shop.Init must be called before Shop.Show")
	end

	if not Shop.Tweens or not Shop.Tweens.Show.Main then
		error("Shop tweens not properly initialized")
	end

	BackgroundEffect:RefreshAll()

	if not originalSizes.Main then
		originalSizes.Main = Main.Size
		originalPositions.Main = Main.Position
	end

	if Shop.Container and not originalSizes.Container then
		originalSizes.Container = Shop.Container.Size
		originalPositions.Container = Shop.Container.Position
	end

	GUI.Enabled = true
	Main.Visible = true

	Main.Size = ZERO_SIZE
	Main.Position = CENTER_POSITION
	Main.AnchorPoint = CENTER_ANCHOR

	if Shop.Container then
		Shop.Container.Size = ZERO_SIZE
		Shop.Container.Position = CENTER_POSITION
		Shop.Container.AnchorPoint = CENTER_ANCHOR
	end

	currentTweens.showMain = Shop.Tweens.Show.Main

	addShopConnection(Shop.Tweens.Show.Main.Completed:Connect(function()
		currentTweens.showMain = nil
	end))

	if Shop.Container and Shop.Tweens.Show.Container then
		currentTweens.showContainer = Shop.Tweens.Show.Container
		addShopConnection(Shop.Tweens.Show.Container.Completed:Connect(function()
			currentTweens.showContainer = nil
		end))
		Shop.Tweens.Show.Container:Play()
	end

	Shop.Tweens.Show.Main:Play()
	Shop.UI.ScreenShown:Fire("Shop", true)
	return true
end

function Shop.Hide()
	cleanupTweens()

	if not Shop.Initialized then
		error("Shop.Init must be called before Shop.Hide")
	end

	if not Shop.Tweens or not Shop.Tweens.Hide.Main then
		error("Shop hide tweens not properly initialized")
	end

	if Shop.Container and Shop.Tweens.Hide.Container then
		currentTweens.hideContainer = Shop.Tweens.Hide.Container
		addShopConnection(Shop.Tweens.Hide.Container.Completed:Connect(function()
			currentTweens.hideContainer = nil
		end))
		Shop.Tweens.Hide.Container:Play()
	end

	currentTweens.hideMain = Shop.Tweens.Hide.Main

	addShopConnection(Shop.Tweens.Hide.Main.Completed:Connect(function()
		if currentTweens.hideMain == Shop.Tweens.Hide.Main then
			GUI.Enabled = false
			Main.Visible = false
		end
		currentTweens.hideMain = nil
	end))

	Shop.Tweens.Hide.Main:Play()
	Shop.UI.ScreenShown:Fire("Shop", false)
	Shop:ResetButtonStates()

	return true
end

function Shop.Toggle()
	cleanupTweens()
	local isCurrentlyVisible = Shop.IsVisible()

	if isCurrentlyVisible then
		Shop.Hide()
	else
		Shop.Show()
	end
	return not isCurrentlyVisible
end

function Shop.IsVisible()
	return GUI.Enabled and Main.Visible
end

function Shop.Cleanup()
	cleanupTweens()
	cleanupShopConnections()
	BackgroundEffect:Clear()
	Shop.Initialized = false
	Shop.Container = nil
	Shop.BackButton = nil
	Shop.ExitButton = nil
	Shop.GamepassCards = {}
	Shop.CurrencyButtons = {}
	Shop.CurrencyContainer = nil
	Shop.GamepassContainer = nil
	Shop.UIAspectRatioConstraint = nil
	Shop.Tweens.Show = {}
	Shop.Tweens.Hide = {}
	originalSizes = {}
	originalPositions = {}
	originalColors = {}
	currentTweens = {}
	shopConnections = {}
	Shop.PurchaseEvents = nil
	Shop.PurchasePromptEvent = nil
	Shop.PurchaseResultEvent = nil
	Shop._purchaseResultConnection = nil
end

local GamepassInfoCache = {}

function Shop:UpdateGamepassVisuals()
	for i, card in ipairs(self.GamepassCards) do
		local item = GamepassSlots[i]
		if not item or not item.id then
			continue
		end

		local descriptionLabel = card:FindFirstChild("Description", true)
		if descriptionLabel and descriptionLabel:IsA("TextLabel") then
			if item.description then
				descriptionLabel.Text = item.description
			end
		end

		task.spawn(function()
			local info = GamepassInfoCache[item.id]
			if not info then
				local success, result = pcall(function()
					return MarketplaceService:GetProductInfo(item.id, Enum.InfoType.GamePass)
				end)
				if success then
					info = result
					GamepassInfoCache[item.id] = info
				else
					warn("Shop: Failed to fetch gamepass info for ID:", item.id)
					return
				end
			end

			local isOwned = false
			if item.EntitlementAttribute then
				isOwned = LocalPlayer:GetAttribute(item.EntitlementAttribute) == true
			end

			if not isOwned then
				local ownedSuccess, ownedResult = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, item.id)
				end)
				if ownedSuccess and ownedResult then
					isOwned = true
				end
			end

			if info then
				local priceLabel = card:FindFirstChild("Price", true)
					or card:FindFirstChild("Cost", true)
					or card:FindFirstChild("Amount", true)
				if priceLabel and priceLabel:IsA("TextLabel") then
					if isOwned then
						priceLabel.Text = "Owned"
					else
						priceLabel.Text = info.PriceInRobux and tostring(info.PriceInRobux) or "N/A"
					end
				end

				local purchaseButton = card:FindFirstChild("ImageButton", true)
				if purchaseButton then
					if isOwned then
						local btnLabel = purchaseButton:FindFirstChildOfClass("TextLabel")
						if btnLabel then
							btnLabel.Text = "Owned"
						end
						local btnIcon = purchaseButton:FindFirstChildOfClass("ImageLabel")
						if btnIcon then
							btnIcon.Visible = false
						end
					else
						local btnLabel = purchaseButton:FindFirstChildOfClass("TextLabel")
						if btnLabel then
							btnLabel.Text = info.PriceInRobux and tostring(info.PriceInRobux) or "N/A"
						end
						local btnIcon = purchaseButton:FindFirstChildOfClass("ImageLabel")
						if btnIcon then
							btnIcon.Visible = true
						end
					end
				end

				local nameLabel = card:FindFirstChild("Title", true)
					or card:FindFirstChild("Name", true)
					or card:FindFirstChild("Header", true)
				if nameLabel and nameLabel:IsA("TextLabel") then
					nameLabel.Text = info.Name
				end

				local iconImage = card:FindFirstChild("GamepassIcon", true)
					or card:FindFirstChild("Icon", true)
					or card:FindFirstChild("Image", true)
					or card:FindFirstChild("ImageLabel", true)
				if iconImage and iconImage:IsA("ImageLabel") then
					if iconImage.Parent ~= purchaseButton then
						iconImage.Image = "rbxassetid://" .. tostring(info.IconImageAssetId)
					end
				end
			end
		end)
	end
end

local ProductInfoCache = {}

local UserProfile = require(ReplicatedStorage.Runtime.Source.UserProfile)

function Shop:UpdateCurrencyVisuals()
	for _, button in ipairs(self.CurrencyButtons) do
		local productId = button:GetAttribute("ProductId")
		if not productId then
			continue
		end

		task.spawn(function()
			local info = ProductInfoCache[productId]
			if not info then
				local success, result = pcall(function()
					return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
				end)
				if success then
					info = result
					ProductInfoCache[productId] = info
				else
					warn("Shop: Failed to fetch product info for ID:", productId)
					return
				end
			end

			if info then
				local textLabel = button:FindFirstChild("TextLabel")
				if textLabel then
					local coins = button:GetAttribute("Coins") or 0
					local price = info.PriceInRobux and formatNumber(info.PriceInRobux) or "N/A"
					textLabel.Text = string.format("%s Coins\nR$ %s", formatNumber(coins), price)
				end
			end
		end)
	end
end

function Shop.Init(UI)
	Shop.Interface = UI
	Shop.UI = UI
	Shop:Build()
	Shop:ConnectNav()
	Shop:ConnectGamepasses()
	Shop:ConnectCurrency()
	Shop.SetupCrossUIListeners(UI)
	Shop.SetupPurchaseNetworking()
	Shop:UpdateGamepassVisuals()
	Shop:UpdateCurrencyVisuals()

	UserProfile:Upon("Currency", function()
		Shop:UpdateCurrencyVisuals()
	end)
end

function Shop.SetupCrossUIListeners(UI)
	task.spawn(function()
		if UI.WaitUntilLoaded then
			UI.WaitUntilLoaded()
		elseif UI.LoadedSignal then
			UI.LoadedSignal:Wait()
		elseif not UI.Loaded then
			while not UI.Loaded do
				task.wait()
			end
		end
		addShopConnection(UI.ScreenShown:Connect(function(componentName, isVisible)
			if isVisible and componentName ~= "Shop" and Shop.IsVisible() then
				Shop.Hide()
			end
		end))
	end)
end

function Shop.SetupPurchaseNetworking()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		print(
			"PromptProductPurchaseFinished:",
			"userId:",
			userId,
			"productId:",
			productId,
			"wasPurchased:",
			wasPurchased
		)

		if userId == LocalPlayer.UserId and wasPurchased then
			Shop.UI.Notify("Purchase successful! Thank you!", "Success")
			print("Purchase completed successfully for product:", productId)
		end
	end)

	Marketplace.PromptPurchaseFinished:Connect(function(player, _gamepassId, infoType)
		if player == LocalPlayer and infoType == Enum.InfoType.GamePass then
			Shop.UI.Notify("Gamepass purchased successfully!", "Success")
		end
	end)
end

return Shop
