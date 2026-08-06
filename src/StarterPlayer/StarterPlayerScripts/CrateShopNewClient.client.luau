local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local BoostConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BoostConfig"))
local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))
local KnifeIcon = require(ReplicatedStorage:WaitForChild("KnifeIcon"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local Luck = require(ReplicatedStorage:WaitForChild("SparkMod"):WaitForChild("Luck"))
local PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local Products = Constants.Products

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local CoinPurchase = Remotes:WaitForChild("CoinPurchase")
local KillEffectCratePurchase = Remotes:WaitForChild("KillEffectCratePurchase")
local PolicyUpdate = Remotes:WaitForChild("PolicyUpdate")

local RESTRICT_ATTR = "PaidRandomRestricted"
local paidRandomRestricted = player:GetAttribute(RESTRICT_ATTR)
if paidRandomRestricted == nil then
	paidRandomRestricted = true
end
local function isRestricted()
	return paidRandomRestricted == true
end

local CRATE_PRODUCTS = {
	["Wooden Crate"] = Products.WoodenCrate,
	["Silver Crate"] = Products.SilverCrate,
	["Golden Crate"] = Products.GoldenCrate,
	["Brainrot Crate"] = Products.BrainrotCrate,
	["Kawaii Kitchen Crate"] = Products.KawaiiKitchenCrate,
	["Backrooms Crate"] = Products.BackroomsCrate,
	["Sports Crate"] = 3607710172,  -- weekly RobuxCase: rotates via RobuxCase model attr ProductId1 (kept inline)
	["Elemental Crate"] = Products.ElementalCrateX1,
}
local CRATE_PRODUCTS_3 = {
	["Sports Crate"] = 3607710201,  -- RobuxCase model attr ProductId3
	["Elemental Crate"] = Products.ElementalCrateX3,
}
local CRATE_PRODUCTS_10 = {
	["Sports Crate"] = 3607721077,  -- RobuxCase model attr ProductId10
	["Elemental Crate"] = Products.ElementalCrateX10,
}
local KE_CRATE_PRODUCTS = {
	["Novice Crate"] = Products.NoviceCrate,
	["Emotional Crate"] = Products.EmotionalCrate,
}

local CRATE_ORDER = { "Wooden Crate", "Silver Crate", "Golden Crate", "Brainrot Crate", "Kawaii Kitchen Crate", "Backrooms Crate", "Sports Crate", "Elemental Crate" }

local CRATE_DISPLAY_NAMES = {
	["Wooden Crate"] = "Basic Crate",
	["Silver Crate"] = "Graffiti Crate",
	["Golden Crate"] = "Cosmic Crate",
	["Brainrot Crate"] = "Brainrot Crate",
	["Kawaii Kitchen Crate"] = "Kawaii Crate",
	["Backrooms Crate"] = "Backrooms Crate",
	["Sports Crate"] = "Sports Crate",
	["Elemental Crate"] = "Elemental Crate",
}

local KE_CRATE_DISPLAY_NAMES = {
	["Novice Crate"] = "Novice Crate",
	["Emotional Crate"] = "Emotional Crate",
}

local SECRET_ICON = "rbxassetid://77573523807035"

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("CratesShop")
local holder = gui:WaitForChild("HolderFrame")

local shopFrame = holder:WaitForChild("WeaponCratesShop")
local mainScroll = shopFrame:WaitForChild("ScrollingFrame")
local closeButton = shopFrame:WaitForChild("CloseButton")

local keShopFrame = holder:WaitForChild("KillEffectCratesShop")
local keScroll = keShopFrame:WaitForChild("ScrollingFrame")
local keCloseButton = keShopFrame:WaitForChild("CloseButton")
local keLeftoverPanel = keShopFrame:FindFirstChild("KnifePercentages")
if keLeftoverPanel then
	keLeftoverPanel.Visible = false
end

local detail = holder:WaitForChild("Percentages")

local tabButtons = holder:WaitForChild("Buttons")
local knivesTab = tabButtons:WaitForChild("Knives")
local killEffectsTab = tabButtons:WaitForChild("KillEffects")

local TILE_TO_CRATE = {
	Basic = "Wooden Crate",
	Grafiti = "Silver Crate",
	Cosmic = "Golden Crate",
	Brainrot = "Brainrot Crate",
	Kawaii = "Kawaii Kitchen Crate",
	BR = "Backrooms Crate",
	Sports = "Sports Crate",
	Elemental = "Elemental Crate",
}

local KE_TILE_TO_CRATE = {
	Novice = "Novice Crate",
	Emotional = "Emotional Crate",
}

local detailScroll = detail:WaitForChild("ScrollingFrame"):WaitForChild("ScrollingFrame")
local knifeTemplate = detailScroll:WaitForChild("ItemFrame")
knifeTemplate.Visible = false

local purchaseButtons = detail:WaitForChild("Buttons")
local robuxBtn = purchaseButtons:WaitForChild("RobuxButton")
local robuxBtn3 = purchaseButtons:FindFirstChild("RobuxButton3")
if not robuxBtn3 then
	robuxBtn3 = robuxBtn:Clone()
	robuxBtn3.Name = "RobuxButton3"
	robuxBtn3.Parent = purchaseButtons
end
local robuxBtn10 = purchaseButtons:FindFirstChild("RobuxButton10")
if not robuxBtn10 then
	robuxBtn10 = robuxBtn3:Clone()
	robuxBtn10.Name = "RobuxButton10"
	robuxBtn10.Parent = purchaseButtons
end
robuxBtn10.Visible = false
local coinBtn = purchaseButtons:WaitForChild("CoinsButton")
local robuxPriceLabel = robuxBtn:WaitForChild("Price")
local robuxPriceLabel3 = robuxBtn3:WaitForChild("Price")
local robuxPriceLabel10 = robuxBtn10:WaitForChild("Price")
local coinPriceLabel = coinBtn:WaitForChild("Price")
local detailCrateName = detail:FindFirstChild("CrateName")

local selectedCrate = nil
local selectedKind = "knife"
local lastOpenedKind = "knife"

local function formatNumber(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function formatChance(p)
	local pct = p * 100
	if pct >= 1 then
		return string.format("%.1f%%", pct)
	elseif pct >= 0.1 then
		return string.format("%.2f%%", pct)
	else
		return string.format("%.3f%%", pct)
	end
end

local function currentLuckMultiplier()
	local multiplier = Luck:GetEffective(BoostConfig.Channel)
	if type(multiplier) == "number" and multiplier > 1 then
		return multiplier
	end
	return 1
end

local function setLabelText(label, text)
	if not label then
		return
	end
	label.Text = text
	local top = label:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then
		top.Text = text
	end
end

local function setPlainLabelText(label, text)
	if label then
		label.Text = text
	end
end

coinPriceLabel.Text = ""
robuxPriceLabel.Text = ""
robuxPriceLabel3.Text = ""
robuxPriceLabel10.Text = ""

local function formatRemaining(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%dd %dh %dm %ds", days, hours, mins, secs)
end

local function limitedTimerText(crateName)
	local expiry = KnifeSkinManager.crateExpiry(crateName)
	if not expiry then
		return nil
	end
	local remaining = expiry - os.time()
	if remaining <= 0 then
		return "LIMITED: EXPIRED"
	end
	return "LIMITED: " .. formatRemaining(remaining)
end

local BUTTON_ROW_Y = 0.899647415
local DEFAULT_BTN_W = 0.28
local DEFAULT_BTN_X = { [coinBtn] = 0.23, [robuxBtn] = 0.55, [robuxBtn3] = 0.84 }
local function layoutPriceButtons()
	if robuxBtn10.Visible then
		local order = { coinBtn, robuxBtn, robuxBtn3, robuxBtn10 }
		local visible = {}
		for _, b in ipairs(order) do
			if b.Visible then
				visible[#visible + 1] = b
			end
		end
		local n = #visible
		if n == 0 then
			return
		end
		local width = n <= 3 and DEFAULT_BTN_W or (0.9 / n)
		for i, b in ipairs(visible) do
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Size = UDim2.new(width, 0, b.Size.Y.Scale, b.Size.Y.Offset)
			b.Position = UDim2.new((i - 0.5) / n, 0, BUTTON_ROW_Y, 0)
		end
	else
		for _, b in ipairs({ coinBtn, robuxBtn, robuxBtn3 }) do
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Size = UDim2.new(DEFAULT_BTN_W, 0, b.Size.Y.Scale, b.Size.Y.Offset)
			b.Position = UDim2.new(DEFAULT_BTN_X[b], 0, BUTTON_ROW_Y, 0)
		end
	end
end

local function refreshPriceButtons()
	if not selectedCrate then
		return
	end
	local coinPrice, productId, productId3, productId10
	if selectedKind == "killeffect" then
		coinPrice = KillEffectManager.cratePrice(selectedCrate)
		productId = KE_CRATE_PRODUCTS[selectedCrate]
		productId3 = nil
		productId10 = nil
	else
		coinPrice = KnifeSkinManager.crateCoinPrice(selectedCrate)
		productId = CRATE_PRODUCTS[selectedCrate]
		productId3 = CRATE_PRODUCTS_3[selectedCrate]
		productId10 = CRATE_PRODUCTS_10[selectedCrate]
	end
	coinBtn.Visible = coinPrice ~= nil
	setLabelText(coinPriceLabel, coinPrice and ("$" .. formatNumber(coinPrice)) or "")
	local canShowRobux = not isRestricted()
	robuxBtn.Visible = (productId ~= nil) and canShowRobux
	robuxBtn3.Visible = (productId3 ~= nil) and canShowRobux
	robuxBtn10.Visible = (productId10 ~= nil) and canShowRobux
	if productId and canShowRobux then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				local prefix = (productId3 or productId10) and "x1 " or ""
				setLabelText(robuxPriceLabel, prefix .. utf8.char(0xE002) .. " " .. info.PriceInRobux)
			end
		end)
	end
	if productId3 and canShowRobux then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId3, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				setLabelText(robuxPriceLabel3, "x3 " .. utf8.char(0xE002) .. " " .. info.PriceInRobux)
			end
		end)
	end
	if productId10 and canShowRobux then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId10, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				setLabelText(robuxPriceLabel10, "x10 " .. utf8.char(0xE002) .. " " .. info.PriceInRobux)
			end
		end)
	end
	layoutPriceButtons()
end

local function clearKnifeRows()
	for _, c in ipairs(detailScroll:GetChildren()) do
		if c:IsA("GuiObject") and c.Name == "KnifeRow" then
			c:Destroy()
		end
	end
end

local function buildOddsRows(crateName, kind)
	clearKnifeRows()
	local odds, rarityRank, rarityColor
	if kind == "killeffect" then
		odds = KillEffectManager.getCrateOdds(crateName)
		rarityRank = KillEffectManager.rarityRank
		rarityColor = KillEffectManager.rarityColor
	else
		odds = KnifeSkinManager.getCrateOdds(crateName, true, currentLuckMultiplier())
		rarityRank = KnifeSkinManager.rarityRank
		rarityColor = KnifeSkinManager.rarityColor
	end
	table.sort(odds, function(a, b)
		local ra, rb = rarityRank(a.rarity), rarityRank(b.rarity)
		if ra ~= rb then
			return ra < rb
		end
		return a.chance > b.chance
	end)
	for i, item in ipairs(odds) do
		local row = knifeTemplate:Clone()
		row.Name = "KnifeRow"
		row.Visible = true
		row.LayoutOrder = i
		local slot = row:FindFirstChild("SlotSquare")
		if slot then
			local icon = slot:FindFirstChild("KnifeIcon")
			if kind == "killeffect" then
				if icon then
					KnifeIcon.render(icon, nil)
					if item.icon and item.icon ~= "" then
						icon.Image = item.icon
						icon.Visible = true
					else
						icon.Image = ""
						icon.Visible = false
					end
				end
				setLabelText(slot:FindFirstChild("KnifeName"), item.name or "")
			else
				local isSecret = (item.rarity == "Secret")
				if icon then
					icon.Visible = true
					if isSecret then
						KnifeIcon.render(icon, nil)
						icon.Image = SECRET_ICON
					else
						icon.Image = ""
						KnifeIcon.render(icon, item.id)
					end
				end
				local displayName = isSecret and "SECRET" or KnifeSkinManager.displayName(item.name or "")
				setLabelText(slot:FindFirstChild("KnifeName"), displayName)
			end
			setLabelText(slot:FindFirstChild("KnifeChance"), formatChance(item.chance))
			local grad = slot:FindFirstChild("KnifeBackGroundColor")
			if grad and grad:IsA("UIGradient") then
				grad.Color = ColorSequence.new(rarityColor(item.rarity))
			end
			local stroke = row:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = rarityColor(item.rarity)
			end
		end
		row.Parent = detailScroll
	end
end

local function openDetail(crateName, kind)
	selectedCrate = crateName
	selectedKind = kind or "knife"
	if detailCrateName then
		local display
		if selectedKind == "killeffect" then
			display = KE_CRATE_DISPLAY_NAMES[crateName] or crateName
		else
			display = CRATE_DISPLAY_NAMES[crateName] or crateName
		end
		setLabelText(detailCrateName, display)
	end
	buildOddsRows(crateName, selectedKind)
	refreshPriceButtons()
	detail.Visible = true
end

local function refreshOpenKnifeDetail()
	if selectedCrate and selectedKind ~= "killeffect" and detail.Visible then
		buildOddsRows(selectedCrate, selectedKind)
	end
end

local function closeDetail()
	selectedCrate = nil
	detail.Visible = false
	clearKnifeRows()
end

local SHIMMER_SLIDE = 0.4
local SHIMMER_TIME = 1.6
local function animateBadgeShimmer(tile)
	local top = tile:FindFirstChild("Top")
	local grad = top and top:FindFirstChildOfClass("UIGradient")
	if not grad then
		return
	end
	if grad:GetAttribute("ShimmerAnim") then
		return
	end
	grad:SetAttribute("ShimmerAnim", true)
	grad.Offset = Vector2.new(-SHIMMER_SLIDE, grad.Offset.Y)
	TweenService:Create(
		grad,
		TweenInfo.new(SHIMMER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector2.new(SHIMMER_SLIDE, grad.Offset.Y) }
	):Play()
end

local SHIMMER_RANGE = 0.5
local SHIMMER_TIME = 1.6
local function animateBadgeGradient(tile)
	local top = tile:FindFirstChild("Top")
	local grad = top and top:FindFirstChildOfClass("UIGradient")
	if not grad then
		return
	end
	if grad:GetAttribute("ShimmerAnim") then
		return
	end
	grad:SetAttribute("ShimmerAnim", true)
	grad.Offset = Vector2.new(-SHIMMER_RANGE, grad.Offset.Y)
	TweenService:Create(
		grad,
		TweenInfo.new(SHIMMER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector2.new(SHIMMER_RANGE, grad.Offset.Y) }
	):Play()
end

local CRATE_ICONS = {
	["Wooden Crate"] = "rbxassetid://107463946938232",
	["Silver Crate"] = "rbxassetid://112997424817621",
	["Golden Crate"] = "rbxassetid://85303150305408",
	["Brainrot Crate"] = "rbxassetid://127169457762280",
	["Kawaii Kitchen Crate"] = "rbxassetid://109653623709295",
	["Backrooms Crate"] = "rbxassetid://136555916823868",
	-- ["Sports Crate"] = "rbxassetid://REPLACE_ME",  -- TODO: add real Sports Crate icon asset (tile icon is blank until then)
}
local KE_CRATE_ICONS = {}

local function setupTilesFor(scroll, tileMap, kind)
	if not scroll:FindFirstChildWhichIsA("UIPadding") then
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = scroll
	end
	for tileName, crateName in pairs(tileMap) do
		local tile = scroll:FindFirstChild(tileName)
		if tile then
			local hasPool, displayName, coinPrice, productId, iconImage
			if kind == "killeffect" then
				hasPool = KillEffectManager.getCratePool(crateName) ~= nil
				displayName = KE_CRATE_DISPLAY_NAMES[crateName] or crateName
				coinPrice = KillEffectManager.cratePrice(crateName)
				productId = KE_CRATE_PRODUCTS[crateName]
				iconImage = KE_CRATE_ICONS[crateName]
			else
				hasPool = KnifeSkinManager.getCratePool(crateName) ~= nil
				displayName = CRATE_DISPLAY_NAMES[crateName] or crateName
				coinPrice = KnifeSkinManager.crateCoinPrice(crateName)
				productId = CRATE_PRODUCTS[crateName]
				iconImage = CRATE_ICONS[crateName]
			end
			tile.Visible = hasPool
			if hasPool then
				setLabelText(tile:FindFirstChild("CrateName"), displayName)
				setLabelText(tile:FindFirstChild("CoinPrice"), coinPrice and (formatNumber(coinPrice) .. " Coins") or "")
				local timerLabel = tile:FindFirstChild("LimitedTimer")
				if timerLabel then
					local text = kind == "knife" and limitedTimerText(crateName) or nil
					timerLabel.Visible = text ~= nil
					if text then
						setPlainLabelText(timerLabel, text)
					end
				end
				local robuxLabel = tile:FindFirstChild("RobuxPrice")
				if robuxLabel then
					if productId and not isRestricted() then
						robuxLabel.Visible = true
						task.spawn(function()
							local ok, info = pcall(function()
								return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
							end)
							if ok and info and info.PriceInRobux then
								setLabelText(robuxLabel, utf8.char(0xE002) .. " " .. info.PriceInRobux)
							end
						end)
					else
						robuxLabel.Visible = false
					end
				end
				local icon = tile:FindFirstChild("Icon")
				if icon and icon:IsA("ImageLabel") and iconImage and iconImage ~= "" then
					icon.Image = iconImage
				end
				animateBadgeGradient(tile)
				animateBadgeShimmer(tile)
				local bg = tile:FindFirstChild("Background")
				if bg and bg:IsA("GuiButton") and not bg:GetAttribute("Wired") then
					bg:SetAttribute("Wired", true)
					UISounds.bindButton(bg, { tween = false })

					local HOVER, PRESS = 1.06, 0.94
					local TW = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local scale = tile:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
					scale.Scale = 1
					scale.Parent = tile
					local hovering = false
					local function to(v)
						TweenService:Create(scale, TW, { Scale = v }):Play()
					end
					bg.MouseEnter:Connect(function()
						hovering = true
						to(HOVER)
					end)
					bg.MouseLeave:Connect(function()
						hovering = false
						to(1)
					end)
					bg.MouseButton1Down:Connect(function()
						to(PRESS)
					end)
					bg.MouseButton1Up:Connect(function()
						to(hovering and HOVER or 1)
					end)

					bg.MouseButton1Click:Connect(function()
						UISounds.select()
						openDetail(crateName, kind)
					end)
				end
			end
		end
	end
end

local function setupCrateTiles()
	setupTilesFor(mainScroll, TILE_TO_CRATE, "knife")
	setupTilesFor(keScroll, KE_TILE_TO_CRATE, "killeffect")
end

local function refreshLimitedTimers()
	for tileName, crateName in pairs(TILE_TO_CRATE) do
		local tile = mainScroll:FindFirstChild(tileName)
		local timerLabel = tile and tile:FindFirstChild("LimitedTimer")
		if timerLabel then
			local text = limitedTimerText(crateName)
			timerLabel.Visible = text ~= nil
			if text then
				setLabelText(timerLabel, text)
			end
		end
	end
end

local function selectTab(kind)
	local knives = (kind ~= "killeffect")
	shopFrame.Visible = knives
	keShopFrame.Visible = not knives
	local knivesOverlay = knivesTab:FindFirstChild("SelectedOverlay")
	if knivesOverlay then
		knivesOverlay.Visible = knives
	end
	local keOverlay = killEffectsTab:FindFirstChild("SelectedOverlay")
	if keOverlay then
		keOverlay.Visible = not knives
	end
	closeDetail()
end

local function openShop()
	if gui.Enabled then
		return
	end
	UISounds.select()
	selectTab(lastOpenedKind)
	gui.Enabled = true
end
local function closeShop()
	UISounds.close()
	closeDetail()
	gui.Enabled = false
end

closeButton.MouseButton1Click:Connect(closeShop)
UISounds.bindTween(closeButton)
closeButton.MouseEnter:Connect(function()
	UISounds.play("hover")
end)

keCloseButton.MouseButton1Click:Connect(closeShop)
UISounds.bindTween(keCloseButton)
keCloseButton.MouseEnter:Connect(function()
	UISounds.play("hover")
end)

knivesTab.MouseButton1Click:Connect(function()
	UISounds.select()
	selectTab("knife")
end)
killEffectsTab.MouseButton1Click:Connect(function()
	UISounds.select()
	selectTab("killeffect")
end)
UISounds.bindButton(knivesTab)
UISounds.bindButton(killEffectsTab)

local openEvent = gui:FindFirstChild("OpenCrateShop")
if not openEvent then
	openEvent = Instance.new("BindableEvent")
	openEvent.Name = "OpenCrateShop"
	openEvent.Parent = gui
end
openEvent.Event:Connect(openShop)
local closeEvent = gui:FindFirstChild("CloseCrateShop")
if not closeEvent then
	closeEvent = Instance.new("BindableEvent")
	closeEvent.Name = "CloseCrateShop"
	closeEvent.Parent = gui
end
closeEvent.Event:Connect(function()
	closeDetail()
	gui.Enabled = false
end)

robuxBtn.Visible = not isRestricted()
UISounds.bindButton(robuxBtn)
UISounds.bindButton(robuxBtn3)
UISounds.bindButton(robuxBtn10)
UISounds.bindButton(coinBtn)

local function promptCrateProduct(productId)
	if isRestricted() then
		return
	end
	if not selectedCrate then
		return
	end
	if player:GetAttribute("Unboxing") then
		UISounds.error()
		return
	end
	if not productId then
		return
	end
	UISounds.click()
	PurchaseFX.prompt()
	MarketplaceService:PromptProductPurchase(player, productId)
end

robuxBtn.MouseButton1Click:Connect(function()
	local products = selectedKind == "killeffect" and KE_CRATE_PRODUCTS or CRATE_PRODUCTS
	promptCrateProduct(products[selectedCrate])
end)

robuxBtn3.MouseButton1Click:Connect(function()
	promptCrateProduct(CRATE_PRODUCTS_3[selectedCrate])
end)

robuxBtn10.MouseButton1Click:Connect(function()
	promptCrateProduct(CRATE_PRODUCTS_10[selectedCrate])
end)

coinBtn.MouseButton1Click:Connect(function()
	if not selectedCrate then
		return
	end
	if player:GetAttribute("Unboxing") then
		UISounds.error()
		return
	end
	UISounds.click()
	if selectedKind == "killeffect" then
		KillEffectCratePurchase:FireServer(selectedCrate)
	else
		CoinPurchase:FireServer(selectedCrate)
	end
end)

local SoundService = game:GetService("SoundService")
local function playCoinReward()
	local tmpl = SoundService:FindFirstChild("CoinReward")
	if not tmpl or not tmpl:IsA("Sound") then
		return
	end
	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then
		s.SoundGroup = sfx
	end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
		if s then
			s:Destroy()
		end
	end)
end

CoinPurchase.OnClientEvent:Connect(function(crateName, success, reason)
	if success then
		playCoinReward()
	else
		UISounds.error()
	end
end)

KillEffectCratePurchase.OnClientEvent:Connect(function(crateName, success, reason)
	if success then
		playCoinReward()
	else
		UISounds.error()
	end
end)

local function onLuckChanged(channel)
	if channel == BoostConfig.Channel then
		refreshOpenKnifeDetail()
	end
end

Luck:Init()
task.spawn(function()
	Luck:GetEffectiveAsync(BoostConfig.Channel)
	Luck:ListModifiersAsync(BoostConfig.Channel)
	refreshOpenKnifeDetail()
end)
Luck.ChannelChanged:Connect(onLuckChanged)
Luck.ModifierApplied:Connect(function(modifier)
	if modifier.channel == BoostConfig.Channel then
		refreshOpenKnifeDetail()
	end
end)
Luck.ModifierRemoved:Connect(onLuckChanged)

player:GetAttributeChangedSignal("Unboxing"):Connect(function()
	if player:GetAttribute("Unboxing") then
		lastOpenedKind = selectedKind
		if gui.Enabled then
			gui.Enabled = false
		end
	end
end)

local function onRestrictionChanged()
	robuxBtn.Visible = not isRestricted()
	if selectedCrate then
		refreshPriceButtons()
	end
	setupCrateTiles()
end
player:GetAttributeChangedSignal(RESTRICT_ATTR):Connect(function()
	paidRandomRestricted = player:GetAttribute(RESTRICT_ATTR) and true or false
	onRestrictionChanged()
end)
PolicyUpdate.OnClientEvent:Connect(function(restricted)
	paidRandomRestricted = restricted and true or false
	onRestrictionChanged()
end)

task.spawn(function()
	while true do
		refreshLimitedTimers()
		task.wait(1)
	end
end)

setupCrateTiles()
detail.Visible = false
selectTab("knife")
gui.Enabled = false

local TRIGGER_PADDING = 1

task.spawn(function()
	local container = workspace:WaitForChild("LobbyInteractives", 30)
	local pad = container and container:WaitForChild("CratePad", 30)
	if not pad then
		for _ = 1, 30 do
			pad = container and container:FindFirstChild("CratePad", true)
			if pad then
				break
			end
			task.wait(1)
		end
	end
	if not pad then
		warn("[CrateShopNewClient] CratePad not found in Workspace (after waiting for stream-in)")
		return
	end

	local inRange = false
	local dismissedInRange = false
	closeButton.MouseButton1Click:Connect(function()
		if inRange then
			dismissedInRange = true
		end
	end)
	keCloseButton.MouseButton1Click:Connect(function()
		if inRange then
			dismissedInRange = true
		end
	end)
	closeEvent.Event:Connect(function()
		if inRange then
			dismissedInRange = true
		end
	end)
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		if not pad.Parent then
			return
		end
		local localPos = pad.CFrame:PointToObjectSpace(hrp.Position)
		local halfX = pad.Size.X / 2 + TRIGGER_PADDING
		local halfZ = pad.Size.Z / 2 + TRIGGER_PADDING
		local nowInRange = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
		if nowInRange and not inRange then
			inRange = true
			if not dismissedInRange and not player:GetAttribute("Unboxing") then
				openShop()
			end
		elseif not nowInRange and inRange then
			inRange = false
			dismissedInRange = false
			closeDetail()
			gui.Enabled = false
		end
	end)
end)
