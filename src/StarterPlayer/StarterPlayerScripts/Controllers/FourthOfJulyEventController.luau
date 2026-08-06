local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local FourthOfJulyEventController = Knit.CreateController({
	Name = "FourthOfJulyEventController",
})

function FourthOfJulyEventController:KnitStart()
	local playerGui = Knit.Player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("4thOfJulyEvent")
	if gui and gui:IsA("ScreenGui") then
		gui.Enabled = false
	end
end

--[[ Event ended; old 4th of July merchant/crate UI body retained only for reference.
local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local MarketplaceService = game:GetService("MarketplaceService")
	local TweenService = game:GetService("TweenService")
	local SoundService = game:GetService("SoundService")
	local RunService = game:GetService("RunService")
	
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("4thOfJulyEvent")
	local frame = gui:WaitForChild("HolderFrame"):WaitForChild("4thOfJulyEvent")
	local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
	
	local FireworkMerchantConfig = require(ReplicatedStorage:WaitForChild("FireworkMerchantConfig"))
	local FireworkCrateConfig = require(ReplicatedStorage:WaitForChild("FireworkCrateConfig"))
	local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
	local KnifeImages = require(ReplicatedStorage:WaitForChild("KnifeImages"))
	local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))
	local TitleManager = require(ReplicatedStorage:WaitForChild("TitleManager"))
	local PoseConfig = require(ReplicatedStorage:WaitForChild("PoseConfig"))
	local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
	
	local PurchaseFX
	pcall(function()
		PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX"))
	end)
	
	local FIREWORK_PACKS = {
		{ productId = 3607832624, amount = 250, card = "1" },
		{ productId = 3607832643, amount = 900, card = "2" },
		{ productId = 3607832659, amount = 3000, card = "3" },
	}
	local CRATE_ROLL_DURATION = 3
	local CRATE_MIN_DELAY = 0.05
	local CRATE_MAX_DELAY = 0.35
	local CRATE_SCALE_UP = 1.15
	local GRAND_PRIZE_SLOT = 1
	local GRAND_PRIZE_ZINDEX = 20
	local COIN_ICON = "rbxassetid://112989444573172"
	local FIREWORK_ICON = "rbxassetid://97593273862463"
	
	local buttons = frame:WaitForChild("Buttons")
	local tabs = {
		Merchant = frame:WaitForChild("MerchantTab"),
		Crate = frame:WaitForChild("CratesTab"),
		Currency = frame:WaitForChild("CurrencyPurchaseTab"),
	}
	local crateTab = tabs.Crate
	local merchantTab = tabs.Merchant
	local currencyTab = tabs.Currency
	local fireworkBalance = 0
	local crateSpins = 0
	local rolling = false
	
	local function formatNumber(n)
		local s = tostring(math.floor(tonumber(n) or 0))
		return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
	end
	
	local function setText(label, text)
		if not label then return end
		if label:IsA("TextLabel") or label:IsA("TextButton") then
			label.Text = text
		end
		local top = label:FindFirstChild("Top")
		if top and top:IsA("TextLabel") then
			top.Text = text
		end
	end
	
	local function setNestedText(parent, childName, text)
		local child = parent and parent:FindFirstChild(childName)
		setText(child, text)
	end
	
	local function playClick()
		local s = SoundService:FindFirstChild("Click") or SoundService:FindFirstChild("ButtonClick")
		if s and s:IsA("Sound") then s:Play() end
	end
	
	local function promptProduct(productId)
		if PurchaseFX and PurchaseFX.prompt then
			PurchaseFX.prompt()
		end
		MarketplaceService:PromptProductPurchase(player, productId)
	end
	
	local productPriceCache = {}
	local productPriceCallbacks = {}

	local function fetchProductPrice(productId, callback)
		if productPriceCache[productId] ~= nil then
			callback(productPriceCache[productId])
			return
		end

		productPriceCallbacks[productId] = productPriceCallbacks[productId] or {}
		table.insert(productPriceCallbacks[productId], callback)
		if #productPriceCallbacks[productId] > 1 then
			return
		end

		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			local price = ok and info and info.PriceInRobux
			productPriceCache[productId] = price or false
			local callbacks = productPriceCallbacks[productId] or {}
			productPriceCallbacks[productId] = nil
			for _, pendingCallback in ipairs(callbacks) do
				pendingCallback(price)
			end
		end)
	end

	local function applyPrice(label, productId, prefix)
		if not label then return end
		setText(label, utf8.char(0xE002) .. "...")
		fetchProductPrice(productId, function(price)
			if price then
				setText(label, (prefix or "") .. utf8.char(0xE002) .. tostring(price))
			end
		end)
	end
	
	local function updateCurrencyLabels()
		for _, holder in ipairs({ frame:FindFirstChild("CurrencyHolder"), crateTab:FindFirstChild("CurrencyHolder") }) do
			local label = holder and holder:FindFirstChild("CurrencyLabel")
			setText(label, formatNumber(fireworkBalance))
		end
	end
	
	local function updateSpinButton()
		local button = crateTab:FindFirstChild("BuyButton")
		if not button then return end
		local title = button:FindFirstChild("Title")
		local icon = button:FindFirstChild("Icon")
		if crateSpins > 0 then
			setText(title, "Spin (" .. formatNumber(crateSpins) .. ")")
			if icon then icon.Visible = false end
		else
			setText(title, "Spin: " .. formatNumber(FireworkCrateConfig.COST))
			if icon then icon.Visible = true end
		end
	end
	
	local function resolveDisplay(item)
		if item.itemType == "coins" then
			return item.name or ("$" .. formatNumber(item.amount or 0) .. " Coins"), COIN_ICON, nil
		elseif item.itemType == "knife" then
			local def = KnifeSkinManager.getSkin(item.id)
			local image = KnifeImages.get(item.id) or (def and def.icon)
			return item.name or (def and KnifeSkinManager.displayName(def.name)) or tostring(item.id), image, def and KnifeSkinManager.getTemplate(item.id)
		elseif item.itemType == "killeffect" then
			local def = KillEffectManager.getEffect(item.id)
			return item.name or (def and def.name) or tostring(item.id), def and def.icon, nil
		elseif item.itemType == "title" then
			local def = TitleManager.getTitle(item.id)
			return item.name or (def and def.name) or tostring(item.id), nil, nil
		elseif item.itemType == "pose" then
			local def = PoseConfig.getPose(item.id)
			return item.name or (def and def.name) or tostring(item.id), def and def.icon, nil
		end
		return item.name or tostring(item.id or "Reward"), nil, nil
	end
	
	local function clearViewport(icon)
		local existing = icon and icon.Parent and icon.Parent:FindFirstChild("ItemViewport")
		if existing then existing:Destroy() end
	end

	local function clearTitlePreview(icon)
		local existing = icon and icon.Parent and icon.Parent:FindFirstChild("TitlePreview")
		if existing then existing:Destroy() end
	end
	
	local function renderViewport(icon, modelTemplate)
		if not icon or not modelTemplate then return false end
		clearViewport(icon)
		icon.Visible = false
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "ItemViewport"
		viewport.BackgroundTransparency = 1
		viewport.Size = icon.Size
		viewport.Position = icon.Position
		viewport.AnchorPoint = icon.AnchorPoint
		viewport.ZIndex = icon.ZIndex
		viewport.Parent = icon.Parent
	
		local camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	
		local model = modelTemplate:Clone()
		model.Parent = viewport
		local cf, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(35), 0))
		local radius = math.max(size.X, size.Y, size.Z, 1)
		camera.CFrame = CFrame.new(Vector3.new(0, radius * 0.2, radius * 2.5), Vector3.new(0, 0, 0))
		return true
	end
	
	local function renderIcon(icon, item, scale)
		if not icon then return end
		local displayName, image, model = resolveDisplay(item)
		local uiScale = icon:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Parent = icon
		end
		uiScale.Scale = scale or 1
		if item.itemType == "title" then
			clearViewport(icon)
			clearTitlePreview(icon)
			icon.Image = ""
			icon.Visible = false

			local label = Instance.new("TextLabel")
			label.Name = "TitlePreview"
			label.BackgroundTransparency = 1
			label.Size = icon.Size
			label.Position = icon.Position
			label.AnchorPoint = icon.AnchorPoint
			label.ZIndex = icon.ZIndex
			label.Font = Enum.Font.GothamBlack
			label.Text = displayName
			label.TextScaled = true
			label.TextWrapped = true
			label.TextColor3 = TitleManager.titleColor(item.id)
			label.Parent = icon.Parent
		elseif image and image ~= "" then
			clearViewport(icon)
			clearTitlePreview(icon)
			icon.Image = image
			icon.Visible = true
		elseif not renderViewport(icon, model) then
			clearViewport(icon)
			clearTitlePreview(icon)
			icon.Image = FIREWORK_ICON
			icon.Visible = true
		end
	end
	
	local function selectTab(name)
		for tabName, tabFrame in pairs(tabs) do
			tabFrame.Visible = tabName == name
			local button = buttons:FindFirstChild(tabName)
			local overlay = button and button:FindFirstChild("SelectedOverlay")
			if overlay then overlay.Visible = tabName == name end
		end
		playClick()
	end

	local function openFireworkCurrencyPage()
		gui.Enabled = true
		for tabName, tabFrame in pairs(tabs) do
			tabFrame.Visible = tabName == "Currency"
			local button = buttons:FindFirstChild(tabName)
			local overlay = button and button:FindFirstChild("SelectedOverlay")
			if overlay then overlay.Visible = tabName == "Currency" end
		end
	end
	
	local function setupTabs()
		for name in pairs(tabs) do
			local button = buttons:FindFirstChild(name)
			if button and button:IsA("GuiButton") then
				button.MouseButton1Click:Connect(function()
					selectTab(name)
				end)
			end
		end
		local close = frame:FindFirstChild("CloseButton")
		if close and close:IsA("GuiButton") then
			close.MouseButton1Click:Connect(function()
				gui.Enabled = false
			end)
		end
		
		local currencyHolder = frame:FindFirstChild("CurrencyHolder")
		local currencyBuy = currencyHolder and currencyHolder:FindFirstChild("BuyButton")
		if currencyBuy and currencyBuy:IsA("GuiButton") then
			currencyBuy.MouseButton1Click:Connect(function()
				selectTab("Currency")
			end)
		end
		selectTab("Merchant")
	end
	
	local function firstTemplate(scroll)
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("Frame") and child.Name == "Template" then
				return child
			end
		end
		return nil
	end
	
	local InventoryUpdate = remotes:WaitForChild("InventoryUpdate")
	local ownedSets = { knife = {}, killeffect = {}, pose = {}, title = {} }
	local merchantEntries = {}

	local function isBlocked(item)
		if item.repeatable then return false end
		local set = ownedSets[item.itemType]
		return set ~= nil and set[item.id] == true
	end

	local BUY_OWNED_COLOR = Color3.fromRGB(90, 90, 90)
	local function refreshMerchantOwnership()
		for _, entry in ipairs(merchantEntries) do
			local blocked = isBlocked(entry.item)
			entry.buy.Active = not blocked
			entry.buy.AutoButtonColor = not blocked
			entry.buy.ImageColor3 = blocked and BUY_OWNED_COLOR or Color3.new(1, 1, 1)
			if entry.buyPrice then
				setText(entry.buyPrice, blocked and "Owned" or entry.buyText)
			end
			if entry.costLabel then
				setText(entry.costLabel, formatNumber(entry.item.cost))
			end
		end
	end

	local function applyOwnership(state)
		if type(state) ~= "table" then return end
		local knife = {}
		for _, it in ipairs(state.items or {}) do
			if it.skinId then knife[it.skinId] = true end
		end
		ownedSets.knife = knife
		local ke = {}
		for _, it in ipairs((state.killEffects and state.killEffects.items) or {}) do
			if it.owned then ke[it.id] = true end
		end
		ownedSets.killeffect = ke
		local pose = {}
		for _, it in ipairs((state.poses and state.poses.items) or {}) do
			if it.owned then pose[it.id] = true end
		end
		ownedSets.pose = pose
		local title = {}
		for _, it in ipairs((state.titles and state.titles.items) or {}) do
			if it.owned then title[it.id] = true end
		end
		ownedSets.title = title
		refreshMerchantOwnership()
	end

	local function setupMerchant()
		local scroll = merchantTab:WaitForChild("MerchantScrollingFrame")
		local slots = {}
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("Frame") and child.Name == "Template" then
				table.insert(slots, child)
			end
		end
		table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	
		for i, item in ipairs(FireworkMerchantConfig.ITEMS) do
			local slot = slots[i]
			if not slot and slots[1] then
				slot = slots[1]:Clone()
				slot.Parent = scroll
			end
			if slot then
				slot.Name = item.id
				slot.LayoutOrder = i
				slot.Visible = true
				local displayItem = { itemType = item.itemType, id = item.id, name = item.name }
				local name = resolveDisplay(displayItem)
				setNestedText(slot, "ItemName", name)
				renderIcon(slot:FindFirstChild("ItemIcon"), displayItem, displayItem.itemType == "knife" and 2 or 1)
				local costLabel
				for _, child in ipairs(slot:GetChildren()) do
					if child:IsA("TextLabel") and child.Name == "Title" and child.Text ~= "Price:" then
						costLabel = child
					end
				end
				setText(costLabel, formatNumber(item.cost))
				local buy = slot:FindFirstChild("Buy")
				if buy and buy:IsA("GuiButton") then
					local buyPrice = buy:FindFirstChild("Price")
					table.insert(merchantEntries, { item = item, buy = buy, costLabel = costLabel, buyPrice = buyPrice, buyText = (buyPrice and buyPrice.Text) or "Buy" })
					buy:SetAttribute("UISoundsBound", true)
					buy.MouseEnter:Connect(function() if not isBlocked(item) then UISounds.hover() end end)
					UISounds.bindTween(buy, function() return not isBlocked(item) end)
					buy.MouseButton1Click:Connect(function()
						if isBlocked(item) then
							return
						end
						remotes.FireworkPurchase:FireServer(item.id)
					end)
				end
			end
		end
		refreshMerchantOwnership()
	end
	
	local function setupCurrencyPacks()
		local content = currencyTab:FindFirstChild("Content")
		if not content then return end

		local basePack = FIREWORK_PACKS[1]
		local function updateDiscount(pack, price)
			local basePrice = productPriceCache[basePack.productId]
			if type(basePrice) ~= "number" or type(price) ~= "number" or pack == basePack then
				return
			end

			local card = content:FindFirstChild(pack.card)
			local buy = card and card:FindFirstChild("BuyButton")
			local buyDiscount = buy and buy:FindFirstChild("Discount")
			local cardDiscount = card and card:FindFirstChild("Discount")

			local originalPrice = basePrice * (pack.amount / basePack.amount)
			local savings = math.max(0, 1 - (price / originalPrice))
			local savingsPercent = savings * 100
			local roundedPercent = if pack.card == "2" then math.ceil(savingsPercent) else math.floor(savingsPercent)
			local originalText = utf8.char(0xE002) .. tostring(math.ceil(originalPrice))
			local percentText = tostring(roundedPercent) .. "%"

			setText(buyDiscount, originalText)
			setText(buyDiscount and buyDiscount:FindFirstChild("Percent"), percentText)
			setText(cardDiscount and cardDiscount:FindFirstChild("Percent"), percentText)
		end

		local function refreshDiscounts()
			for _, pack in ipairs(FIREWORK_PACKS) do
				local price = productPriceCache[pack.productId]
				if type(price) == "number" then
					updateDiscount(pack, price)
				end
			end
		end

		for _, pack in ipairs(FIREWORK_PACKS) do
			local card = content:FindFirstChild(pack.card)
			if card then
				for _, label in ipairs(card:GetChildren()) do
					if label:IsA("TextLabel") and label.Name == "Title" and label.Text:find("^%+") then
						setText(label, "+" .. formatNumber(pack.amount))
					end
				end
				local buy = card:FindFirstChild("BuyButton")
				if buy and buy:IsA("GuiButton") then
					local txt = buy:FindFirstChild("Txt")
					applyPrice(txt, pack.productId)
					fetchProductPrice(pack.productId, function(price)
						updateDiscount(pack, price)
						refreshDiscounts()
					end)
					buy.MouseButton1Click:Connect(function()
						promptProduct(pack.productId)
					end)
				end
			end
		end
	end
	
	local function setRewardTileZIndex(tile, zIndex)
		if not tile or not tile:IsA("GuiObject") then return end
		tile.ZIndex = zIndex
		for _, descendant in ipairs(tile:GetDescendants()) do
			if descendant:IsA("GuiObject") then
				descendant.ZIndex = zIndex
			end
		end
	end

	local function centeredCrateOrder(items)
		local rarestIdx, rarestChance = 1, math.huge
		for i, it in ipairs(items) do
			if (it.chance or math.huge) < rarestChance then
				rarestChance = it.chance
				rarestIdx = i
			end
		end
		local order = { items[rarestIdx] }
		for i, it in ipairs(items) do
			if i ~= rarestIdx then
				table.insert(order, it)
			end
		end
		return order
	end
	local crateDisplayOrder = centeredCrateOrder(FireworkCrateConfig.ITEMS)

	local function setupRewardTiles()
		local rewards = crateTab:WaitForChild("Rewards")
		for slot, item in ipairs(crateDisplayOrder) do
			local tile = rewards:FindFirstChild(tostring(slot))
			if tile then
				tile:SetAttribute("RewardIndex", slot)
				setRewardTileZIndex(tile, slot == GRAND_PRIZE_SLOT and GRAND_PRIZE_ZINDEX or 1)
				local name = resolveDisplay(item)
				setNestedText(tile, "ItemName", name)
				setNestedText(tile, "ChanceLabel", tostring(item.chance) .. "%")
				renderIcon(tile:FindFirstChild("ItemIcon"), item, item.itemType == "knife" and 2 or 1)
				local highlight = tile:FindFirstChild("SlotHighlight")
				if highlight then highlight.Visible = false end
			end
		end
		for _, d in ipairs(crateTab:GetDescendants()) do
			if d.Name == "ShowOdds" and d:IsA("GuiObject") then
				d.Visible = false
			end
		end
	
		local upcoming = crateTab:FindFirstChild("UpcomingRewards")
		if upcoming then
			local slots = {}
			for _, child in ipairs(upcoming:GetChildren()) do
				if child:IsA("ImageLabel") and child.Name == "Template" then table.insert(slots, child) end
			end
			for i, slot in ipairs(slots) do
				local item = FireworkCrateConfig.ITEMS[((i - 1) % #FireworkCrateConfig.ITEMS) + 1]
				renderIcon(slot:FindFirstChild("ItemIcon"), item)
			end
		end
	end
	
	local function setupOddsPopup()
		local popup = crateTab:WaitForChild("OddsPopUp")
		local content = popup:WaitForChild("Content")
		local template = content:WaitForChild("Template")
		template.Visible = false
		for i, item in ipairs(FireworkCrateConfig.ITEMS) do
			local row = template:Clone()
			row.Name = tostring(i)
			row.LayoutOrder = i
			row.Visible = true
			renderIcon(row:FindFirstChild("Icon"), item)
			setNestedText(row, "ChanceLabel", tostring(item.chance) .. "%")
			row.Parent = content
		end
		local close = popup:FindFirstChild("Close")
		if close and close:IsA("GuiButton") then
			close.MouseButton1Click:Connect(function()
				popup.Visible = false
			end)
		end
		popup.Visible = false
	end
	
	local function rewardFrameForResult(result)
		for slot, item in ipairs(crateDisplayOrder) do
			if item.itemType == result.itemType and (item.id == result.id or item.name == result.name) then
				return crateTab.Rewards:FindFirstChild(tostring(slot))
			end
		end
		return crateTab.Rewards:FindFirstChild("1")
	end
	
	local function completeRoll()
		rolling = false
		updateSpinButton()
	end
	
	local function animateCrateRoll(result)
		local rewardsContainer = crateTab:FindFirstChild("Rewards")
		if not rewardsContainer then completeRoll(); return end
		local rewardFrames = {}
		for _, child in ipairs(rewardsContainer:GetChildren()) do
			if child:IsA("GuiObject") then table.insert(rewardFrames, child) end
		end
		table.sort(rewardFrames, function(a, b) return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0) end)
		local finalFrame = rewardFrameForResult(result)
		if #rewardFrames == 0 or not finalFrame then completeRoll(); return end
	
		for _, child in ipairs(rewardFrames) do
			local highlight = child:FindFirstChild("SlotHighlight")
			if highlight then highlight.Visible = false end
		end
	
		local startTime = tick()
		local currentIndex = 1
		while true do
			local elapsed = tick() - startTime
			local progress = math.clamp(elapsed / CRATE_ROLL_DURATION, 0, 1)
			local eased = 1 - (1 - progress) ^ 3
			local delayTime = CRATE_MIN_DELAY + (CRATE_MAX_DELAY - CRATE_MIN_DELAY) * eased
			local tile = rewardFrames[currentIndex]
			local highlight = tile:FindFirstChild("SlotHighlight")
			if highlight then highlight.Visible = true end
			local originalSize = tile.Size
			local biggerSize = UDim2.new(originalSize.X.Scale * CRATE_SCALE_UP, originalSize.X.Offset, originalSize.Y.Scale * CRATE_SCALE_UP, originalSize.Y.Offset)
			local grow = TweenService:Create(tile, TweenInfo.new(delayTime * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = biggerSize })
			local shrink = TweenService:Create(tile, TweenInfo.new(delayTime * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = originalSize })
			grow:Play(); grow.Completed:Wait(); shrink:Play()
			task.wait(delayTime * 0.5)
			if highlight then highlight.Visible = false end
			currentIndex += 1
			if currentIndex > #rewardFrames then currentIndex = 1 end
			if progress >= 1 then break end
		end
	
		local finalHighlight = finalFrame:FindFirstChild("SlotHighlight")
		if finalHighlight then finalHighlight.Visible = true end
		local originalSize = finalFrame.Size
		local bigSize = UDim2.new(originalSize.X.Scale * 1.35, originalSize.X.Offset, originalSize.Y.Scale * 1.35, originalSize.Y.Offset)
		local finalGrow = TweenService:Create(finalFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = bigSize })
		finalGrow:Play(); finalGrow.Completed:Wait()
		local pulse = TweenService:Create(finalFrame, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = UDim2.new(bigSize.X.Scale * 1.05, bigSize.X.Offset, bigSize.Y.Scale * 1.05, bigSize.Y.Offset),
		})
		pulse:Play()
		task.wait(1)
		pulse:Cancel()
		local shrink = TweenService:Create(finalFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = originalSize })
		shrink:Play(); shrink.Completed:Wait()
		if finalHighlight then finalHighlight.Visible = false end
		completeRoll()
	end
	
	local function setupCrateControls()
		local stateRemote = remotes:WaitForChild("FireworkCrateGetState")
		local ok, state = pcall(function()
			return stateRemote:InvokeServer()
		end)
		if ok and type(state) == "table" then
			crateSpins = tonumber(state.spins) or crateSpins
			fireworkBalance = tonumber(state.fireworks) or fireworkBalance
		end
		updateSpinButton()
	
		local spinButton = crateTab:FindFirstChild("BuyButton")
		if spinButton and spinButton:IsA("GuiButton") then
			spinButton.MouseButton1Click:Connect(function()
				if rolling then return end
				rolling = true
				updateSpinButton()
				remotes.FireworkCratePurchase:FireServer(true)
			end)
		end

	end
	
	remotes:WaitForChild("FireworkUpdate").OnClientEvent:Connect(function(amount)
		fireworkBalance = tonumber(amount) or 0
		updateCurrencyLabels()
	end)
	
	remotes:WaitForChild("FireworkCrateSpinUpdate").OnClientEvent:Connect(function(amount)
		crateSpins = tonumber(amount) or 0
		updateSpinButton()
	end)
	
	remotes:WaitForChild("FireworkCrateResult").OnClientEvent:Connect(function(result)
		if type(result) ~= "table" then return end
		task.spawn(animateCrateRoll, result)
	end)
	
	remotes:WaitForChild("FireworkCratePurchase").OnClientEvent:Connect(function(success, reason)
		if success == false then
			rolling = false
			updateSpinButton()
			if reason == "insufficient" then
				openFireworkCurrencyPage()
			end
			warn("[4thOfJulyEvent] crate purchase failed: " .. tostring(reason))
		end
	end)
	
	remotes:WaitForChild("FireworkPurchase").OnClientEvent:Connect(function(_itemId, ok, reason)
		if not ok then
			if reason == "insufficient" then
				openFireworkCurrencyPage()
			end
			warn("[4thOfJulyEvent] merchant purchase failed: " .. tostring(reason))
		end
	end)
	
	local openEvent = gui:FindFirstChild("Open4thOfJulyEvent") or Instance.new("BindableEvent")
	openEvent.Name = "Open4thOfJulyEvent"
	openEvent.Parent = gui
	openEvent.Event:Connect(function(tabName)
		gui.Enabled = true
		selectTab(tabs[tabName] and tabName or "Merchant")
	end)
	
	setupTabs()
	setupMerchant()
	setupCurrencyPacks()
	setupRewardTiles()
	setupOddsPopup()
	setupCrateControls()
	updateCurrencyLabels()
	updateSpinButton()

	InventoryUpdate.OnClientEvent:Connect(applyOwnership)
	task.spawn(function()
		local invAction = remotes:WaitForChild("InventoryAction", 10)
		if invAction and invAction:IsA("RemoteEvent") then
			invAction:FireServer("request")
		end
	end)

	UISounds.bindAll(frame)
	
	local function setupLobbyTrigger()
		local lobbyInteractives = workspace:WaitForChild("LobbyInteractives", 30)
		local trigger = lobbyInteractives and lobbyInteractives:WaitForChild("4thOfJulyEvent", 30)
		if not trigger or not trigger:IsA("BasePart") then
			warn("[4thOfJulyEvent] workspace.LobbyInteractives.4thOfJulyEvent trigger not found")
			return
		end
	
		local closeButton = frame:FindFirstChild("CloseButton")
		local inRange = false
		local dismissedInRange = false
		local padding = 1
	
		if closeButton and closeButton:IsA("GuiButton") then
			closeButton.MouseButton1Click:Connect(function()
				if inRange then
					dismissedInRange = true
				end
			end)
		end
	
		RunService.Heartbeat:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not trigger.Parent then
				return
			end
	
			local localPos = trigger.CFrame:PointToObjectSpace(root.Position)
			local halfX = trigger.Size.X / 2 + padding
			local halfZ = trigger.Size.Z / 2 + padding
			local nowInRange = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
	
			if nowInRange and not inRange then
				inRange = true
				if not dismissedInRange then
					gui.Enabled = true
					selectTab("Merchant")
				end
			elseif not nowInRange and inRange then
				inRange = false
				dismissedInRange = false
				gui.Enabled = false
			end
		end)
	end
	
	setupLobbyTrigger()
	
end
]]

return FourthOfJulyEventController
