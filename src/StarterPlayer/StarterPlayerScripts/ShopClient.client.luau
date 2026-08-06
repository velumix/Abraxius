-- ShopClient: drives the new consolidated Shop UI (StarterGui.Shop), opened by the Store button in
-- the Hud, the ShopPad, or the LimitedTimePad. Wires every purchase button (gamepasses, coin packs,
-- the Blackhole Seer Pack) with ownership/price display and the paid-random policy gate.
--
-- New layout (StarterGui.Shop):
--   Shop (ScreenGui, ResetOnSpawn=false) -> HolderFrame -> Shop -> {CloseButton, ContainerScroll}
--   ContainerScroll children:
--     Vip (VIP gamepass)            -> BuyButton (Price label, layered with .Top)
--     Gamepasses -> SeekerGamepass / CoinsGamepass -> BuyButton
--     CoinsDevProduct -> 500Coins / 1KCoins / 5KCoins / 10KCoins -> BuyButton
--     SpecialKnife (Blackhole Seer Pack bundle) -> BuyButton
-- The whole UI is shown/hidden via the ScreenGui's .Enabled (there is no "Dim" frame like the old one).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local SEEKER_GAMEPASS_ID = Constants.Gamepasses.SEEKER
local DOUBLE_COINS_GAMEPASS_ID = Constants.Gamepasses.DOUBLE_COINS
local VIP_GAMEPASS_ID = Constants.Gamepasses.VIP

local Products = Constants.Products

local ROBUX_GLYPH = utf8.char(0xE002)  -- Roblox's built-in Robux glyph (preferred over "R$")

-- The Sports Crate promo tile (below) shows its reward pool as live knife viewports + odds.
local KnifeIcon = require(ReplicatedStorage:WaitForChild("KnifeIcon"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local SECRET_ICON = "rbxassetid://77573523807035"  -- mystery "?" shown for the collapsed Secret slot
local function formatChance(p)
	local pct = (p or 0) * 100
	if pct >= 1 then
		return string.format("%.1f%%", pct)
	elseif pct >= 0.1 then
		return string.format("%.2f%%", pct)
	else
		return string.format("%.3f%%", pct)
	end
end

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("Shop")
local frame = gui:WaitForChild("HolderFrame"):WaitForChild("Shop")
local scroll = frame:WaitForChild("ContainerScroll")

-- start hidden; open()/close() toggle the ScreenGui's Enabled (the GUI persists, ResetOnSpawn=false)
gui.Enabled = false

-- Set a price/owned string on a BuyButton's layered Price label (Price + its .Top overlay).
local function setPriceLabel(buyBtn, text)
	local price = buyBtn and buyBtn:FindFirstChild("Price")
	if not price then return end
	price.Text = text
	local top = price:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then top.Text = text end
end

-- ===== Paid-random-item (loot box) policy gate =====
-- For players whose region/age restricts paid random items, the crate economy is kept EARN-ONLY:
-- they must have NO way to buy coins with Robux (otherwise coin-bought crates would count as paid
-- random items). So for restricted players we hide every Robux->coins path in this shop:
--   * the coin packs (500/1000/5000/10000 Coins).
-- The Blackhole Seer Pack stays available to everyone: it's NOT a paid random item (fixed knife +
-- a mutation that's freely obtainable in normal play), and its bundled coins are withheld server-side
-- for restricted players, so it isn't a Robux->coins path for them.
-- The gamepasses (2x Seeker, Double Coins, VIP) are NOT coin-buying paths and stay available
-- (Double Coins only multiplies EARNED coins; it can't be used to purchase coins).
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local PolicyUpdate = Remotes:WaitForChild("PolicyUpdate")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate")
local RESTRICT_ATTR = "PaidRandomRestricted"
local LIMITED_STOCK_SKIN_ID = "frozen"
local paidRandomRestricted = player:GetAttribute(RESTRICT_ATTR)
if paidRandomRestricted == nil then paidRandomRestricted = true end  -- fail closed until resolved
local function isRestricted() return paidRandomRestricted == true end

local ownsLimitedStockWeapon = false
local refreshSpecialKnife2Availability
local function stateOwnsSkin(state, skinId)
	if type(state) ~= "table" or type(state.items) ~= "table" then
		return false
	end
	for _, item in ipairs(state.items) do
		if item.skinId == skinId then
			return true
		end
	end
	return false
end
InventoryUpdate.OnClientEvent:Connect(function(state)
	ownsLimitedStockWeapon = stateOwnsSkin(state, LIMITED_STOCK_SKIN_ID)
	if refreshSpecialKnife2Availability then
		refreshSpecialKnife2Availability()
	end
end)

-- buttons that represent a Robux->coins path; hidden for restricted players. Collected as wired.
local coinPurchaseButtons = {}
local function applyCoinButtonVisibility()
	for _, btn in ipairs(coinPurchaseButtons) do
		if btn and btn.Parent then btn.Visible = not isRestricted() end
	end
end
player:GetAttributeChangedSignal(RESTRICT_ATTR):Connect(function()
	paidRandomRestricted = player:GetAttribute(RESTRICT_ATTR) and true or false
	applyCoinButtonVisibility()
end)
PolicyUpdate.OnClientEvent:Connect(function(restricted)
	paidRandomRestricted = restricted and true or false
	applyCoinButtonVisibility()
end)

-- ===== Open / close =====
-- Scroll so a given section (a direct child of ContainerScroll, found via a descendant marker name)
-- is brought to the top of the view.
local function scrollToSection(markerPredicate)
	local hit
	for _, d in ipairs(scroll:GetDescendants()) do
		if markerPredicate(d) then hit = d break end
	end
	if not hit then return end
	local section = hit
	while section.Parent and section.Parent ~= scroll do section = section.Parent end
	if section.Parent ~= scroll then return end
	task.defer(function()
		local targetY = scroll.CanvasPosition.Y + (section.AbsolutePosition.Y - scroll.AbsolutePosition.Y)
		local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
		scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.clamp(targetY, 0, maxY))
	end)
end

-- Scroll so the coin packs are in view (the CoinsDevProduct section holds the 500/1K/5K/10K frames).
local function scrollToCoins()
	scrollToSection(function(d) return d.Name:match("Coins$") ~= nil end)
end

-- Scroll to the Blackhole Seer Pack (now the SpecialKnife section).
local function scrollToBlackhole()
	scrollToSection(function(d) return d.Name == "SpecialKnife" end)
end

local function scrollToSpecialKnife2()
	scrollToSection(function(d) return d.Name == "SpecialKnife2" end)
end

local function open(section)
	UISounds.select()
	gui.Enabled = true
	if section == "coins" then
		scrollToCoins()
	elseif section == "blackhole" then
		scrollToBlackhole()
	elseif section == "frozenknife" or section == "frozen" then
		scrollToSpecialKnife2()
	else
		scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, 0)  -- default: top
	end
end
local function close() UISounds.close(); gui.Enabled = false end

local exit = frame:FindFirstChild("CloseButton")
if exit then
	exit.MouseButton1Click:Connect(close)
	UISounds.bindTween(exit)
	exit.MouseEnter:Connect(function() UISounds.play("hover") end)
	exit:SetAttribute("UISoundsBound", true)
end
-- clicking outside intentionally does NOT close it (consistent with settings)

-- events so the HUD can open/close the shop
local openEvent = gui:FindFirstChild("OpenShop")
if not openEvent then openEvent = Instance.new("BindableEvent"); openEvent.Name = "OpenShop"; openEvent.Parent = gui end
openEvent.Event:Connect(function(section) open(section) end)
local closeEvent = gui:FindFirstChild("CloseShop")
if not closeEvent then closeEvent = Instance.new("BindableEvent"); closeEvent.Name = "CloseShop"; closeEvent.Parent = gui end
closeEvent.Event:Connect(function() gui.Enabled = false end)

-- ===== gamepass purchases (shared helper) =====
-- Wire one gamepass BuyButton: hover/click sounds, ownership tracking (shows "Owned" + skips
-- re-purchase), live Robux price on the layered Price label, and the purchase prompt. Replaces the
-- three near-identical Seeker/DoubleCoins/VIP blocks.
local function wireGamepass(buyBtn, gamepassId)
	if not buyBtn then return end
	UISounds.bindTween(buyBtn)
	buyBtn.MouseEnter:Connect(function() UISounds.play("hover") end)
	buyBtn:SetAttribute("UISoundsBound", true)

	local owns = false
	local function refreshOwned()
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
		end)
		if ok then owns = result end
		if owns then setPriceLabel(buyBtn, "Owned") end
	end
	refreshOwned()

	buyBtn.MouseButton1Click:Connect(function()
		UISounds.click()
		if owns then
			setPriceLabel(buyBtn, "Owned")  -- already owned (e.g. the game owner): nothing to buy
			return
		end
		PurchaseFX.prompt()
		MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	end)

	-- reflect a completed purchase this session
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, wasPurchased)
		if plr == player and passId == gamepassId and wasPurchased then
			owns = true
			setPriceLabel(buyBtn, "Owned")
		end
	end)

	-- show the real price (unless owned)
	task.spawn(function()
		if owns then return end
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(gamepassId, Enum.InfoType.GamePass)
		end)
		if ok and info and not owns then
			setPriceLabel(buyBtn, info.PriceInRobux and (ROBUX_GLYPH .. " " .. info.PriceInRobux) or "Buy")
		end
	end)
end

local gamepassesSection = scroll:FindFirstChild("Gamepasses")
local seekerFrame = gamepassesSection and gamepassesSection:FindFirstChild("SeekerGamepass")
local coinsFrame = gamepassesSection and gamepassesSection:FindFirstChild("CoinsGamepass")
local vipFrame = scroll:FindFirstChild("Vip")

wireGamepass(seekerFrame and seekerFrame:FindFirstChild("BuyButton"), SEEKER_GAMEPASS_ID)
wireGamepass(coinsFrame and coinsFrame:FindFirstChild("BuyButton"), DOUBLE_COINS_GAMEPASS_ID)
wireGamepass(vipFrame and vipFrame:FindFirstChild("BuyButton"), VIP_GAMEPASS_ID)

-- give hover sound + tween to every other button in the shop (purchase buttons, etc.)
UISounds.bindAll(frame)

-- ===== Proximity: open the shop when the player stands on the ShopPad, close when they leave =====
local RunService = game:GetService("RunService")
local TRIGGER_PADDING = 1  -- small leeway (studs) beyond the pad's edges; set to 0 for strict

-- ShopPad now lives in the central Workspace.LobbyInteractives folder (move that folder's contents
-- when the lobby changes; scripts never need re-pointing). Recursive find = robust to any nesting.
local interactives = workspace:WaitForChild("LobbyInteractives", 30)
local pad = interactives and interactives:FindFirstChild("ShopPad", true)
if not pad then
	local waited = 0
	while interactives and not pad and waited < 30 do task.wait(0.2); waited += 0.2; pad = interactives:FindFirstChild("ShopPad", true) end
end
if pad then
	local inRange = false           -- currently within the pad footprint?
	local dismissedInRange = false  -- did the player manually close it while still on the pad?

	local function onClosed()
		if inRange then dismissedInRange = true end
	end
	if exit then exit.MouseButton1Click:Connect(onClosed) end
	closeEvent.Event:Connect(onClosed)

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		-- check against the pad's actual footprint (its X/Z bounds), not a radius
		local localPos = pad.CFrame:PointToObjectSpace(hrp.Position)
		local halfX = pad.Size.X / 2 + TRIGGER_PADDING
		local halfZ = pad.Size.Z / 2 + TRIGGER_PADDING
		local nowInRange = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ

		if nowInRange and not inRange then
			inRange = true
			if not dismissedInRange then open() end
		elseif not nowInRange and inRange then
			inRange = false
			dismissedInRange = false
			gui.Enabled = false
		end
	end)
else
	warn("[ShopClient] ShopPad not found in Workspace")
end

-- ===== Proximity: LimitedTimePad opens the shop scrolled to the Blackhole Seer Pack =====
local limitedPad = workspace:WaitForChild("LobbyInteractives"):FindFirstChild("LimitedTimePad", true)
if limitedPad then
	local inRange2 = false
	local dismissed2 = false
	local function onClosed2() if inRange2 then dismissed2 = true end end
	if exit then exit.MouseButton1Click:Connect(onClosed2) end
	closeEvent.Event:Connect(onClosed2)

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local localPos = limitedPad.CFrame:PointToObjectSpace(hrp.Position)
		local halfX = limitedPad.Size.X / 2 + TRIGGER_PADDING
		local halfZ = limitedPad.Size.Z / 2 + TRIGGER_PADDING
		local nowInRange = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
		if nowInRange and not inRange2 then
			inRange2 = true
			if not dismissed2 then open("blackhole") end
		elseif not nowInRange and inRange2 then
			inRange2 = false
			dismissed2 = false
			gui.Enabled = false
		end
	end)
else
	warn("[ShopClient] LimitedTimePad not found in Workspace")
end

-- ===== Coin dev products (instant-grant coin packs) =====
-- Each coin frame (named like "500Coins") has Content.RobuxButton; clicking it prompts the
-- matching dev product. The server's ProcessReceipt grants the coins.
-- coin frame names match the new CoinsDevProduct layout (500Coins / 1KCoins / 5KCoins / 10KCoins)
local COIN_PRODUCTS = {
	["500Coins"] = Products.Coins500,
	["1KCoins"]  = Products.Coins1K,
	["5KCoins"]  = Products.Coins5K,
	["10KCoins"] = Products.Coins10K,
}

local coinsDevSection = scroll:FindFirstChild("CoinsDevProduct")

local function wireCoinButton(frameName, productId)
	local coinFrame = coinsDevSection and coinsDevSection:FindFirstChild(frameName)
	if not coinFrame then
		warn("[ShopClient] coin frame not found: " .. frameName)
		return
	end
	local btn = coinFrame:FindFirstChild("BuyButton")
	if not btn then
		warn("[ShopClient] BuyButton not found in " .. frameName)
		return
	end

	UISounds.bindTween(btn)
	btn.MouseEnter:Connect(function() UISounds.play("hover") end)
	btn:SetAttribute("UISoundsBound", true)

	-- coin packs are a Robux->coins path; hide for restricted players (keeps coins earn-only)
	table.insert(coinPurchaseButtons, btn)
	btn.Visible = not isRestricted()

	-- show the real Robux price on the layered Price label (matches the other shop buttons)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			setPriceLabel(btn, ROBUX_GLYPH .. " " .. info.PriceInRobux)
		end
	end)

	btn.MouseButton1Click:Connect(function()
		if isRestricted() then return end  -- buying coins with Robux disabled for restricted players
		UISounds.click()
		PurchaseFX.prompt()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end

for frameName, productId in pairs(COIN_PRODUCTS) do
	wireCoinButton(frameName, productId)
end

-- ===== Animate the "BEST DEAL!" badge gradient on the 10K coin pack =====
-- Slide the badge's UIGradient Offset side to side (a back-and-forth color shimmer), matching the
-- crate-shop badge animation. Guarded by an attribute so it only ever starts one tween per gradient.
local TweenService = game:GetService("TweenService")
local BADGE_SHIMMER_RANGE = 0.5   -- how far the gradient offset slides each way (0..1 of the band)
local BADGE_SHIMMER_TIME = 1.6    -- seconds for one side of the slide
local function animateBadgeGradient(grad)
	if not grad or grad:GetAttribute("ShimmerAnim") then return end
	grad:SetAttribute("ShimmerAnim", true)
	grad.Offset = Vector2.new(-BADGE_SHIMMER_RANGE, grad.Offset.Y)
	TweenService:Create(
		grad,
		TweenInfo.new(BADGE_SHIMMER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector2.new(BADGE_SHIMMER_RANGE, grad.Offset.Y) }
	):Play()
end
do
	-- the "BEST DEAL!" badge is the Title.Top label that carries a UIGradient on the 10K coin pack
	local tenK = coinsDevSection and coinsDevSection:FindFirstChild("10KCoins")
	local title = tenK and tenK:FindFirstChild("Title")
	if title then
		for _, lbl in ipairs(title:GetChildren()) do
			if lbl:IsA("TextLabel") then
				local grad = lbl:FindFirstChildOfClass("UIGradient")
				if grad then animateBadgeGradient(grad) end
			end
		end
	end
end

-- ===== Animate the SpecialKnife2 badge gradients (KnifeIcon + MutationIcon + pack title) =====
-- Same side-to-side shimmer as the crate-shop "NEW!" badge: run the shared animateBadgeGradient on
-- each Title.Top UIGradient so their color band drifts back and forth forever.
do
	local sk2 = scroll:FindFirstChild("SpecialKnife2")
	if sk2 then
		for _, iconName in ipairs({ "KnifeIcon", "MutationIcon" }) do
			local icon = sk2:FindFirstChild(iconName)
			local title = icon and icon:FindFirstChild("Title")
			local top = title and title:FindFirstChild("Top")
			local grad = top and top:FindFirstChildOfClass("UIGradient")
			if grad then animateBadgeGradient(grad) end
		end
		-- every direct Title child's Top gradient (covers SpecialKnife2.Title.Top.UIGradient -- the pack title)
		for _, child in ipairs(sk2:GetChildren()) do
			if child.Name == "Title" and child:IsA("TextLabel") then
				local top = child:FindFirstChild("Top")
				local grad = top and top:FindFirstChildOfClass("UIGradient")
				if grad then animateBadgeGradient(grad) end
			end
		end
	end
end

-- ===== Animate the SpecialKnife (Galaxy Seer pack) badge gradients =====
-- Same shimmer as above, applied to this tile's title gradients:
--   * SpecialKnife.Title.Top.UIGradient        (the pack/knife title -- there can be more than one
--                                                Title child, so we animate every direct Title's Top)
--   * SpecialKnife.MutationIcon.Title.Top.UIGradient  (the "Mutation" label)
do
	local sp = scroll:FindFirstChild("SpecialKnife")
	if sp then
		-- every direct Title child's Top gradient (covers SpecialKnife.Title.Top.UIGradient)
		for _, child in ipairs(sp:GetChildren()) do
			if child.Name == "Title" and child:IsA("TextLabel") then
				local top = child:FindFirstChild("Top")
				local grad = top and top:FindFirstChildOfClass("UIGradient")
				if grad then animateBadgeGradient(grad) end
			end
		end
		-- the MutationIcon's title gradient
		local mi = sp:FindFirstChild("MutationIcon")
		local miTitle = mi and mi:FindFirstChild("Title")
		local miTop = miTitle and miTitle:FindFirstChild("Top")
		local miGrad = miTop and miTop:FindFirstChildOfClass("UIGradient")
		if miGrad then animateBadgeGradient(miGrad) end
	end
end

-- ===== Blackhole Seer Pack dev product =====
-- Grants 1x Blackhole Seer + a guaranteed random mutation + 1000 coins (server's ProcessReceipt).
local LIMITED_TIME_PACK_PRODUCT = Constants.LimitedTimePack.Product
do
	local sp = scroll:FindFirstChild("SpecialKnife")
	local btn = sp and sp:FindFirstChild("BuyButton")
	if not btn then
		warn("[ShopClient] SpecialKnife (Blackhole Seer Pack) BuyButton not found")
	else
		UISounds.bindTween(btn)
		btn.MouseEnter:Connect(function() UISounds.play("hover") end)
		btn:SetAttribute("UISoundsBound", true)

		-- The Blackhole Seer Pack is PURCHASABLE BY EVERYONE. It is NOT a paid random item: the knife is
		-- fixed (Blackhole Seer) and the mutation is the same free roll any player can get in normal play,
		-- just granted guaranteed. The only paid-policy concern is the bundled 1000 coins, which the
		-- SERVER withholds from restricted players (CoinManager.creditFromPack) — the knife + mutation are
		-- still granted to everyone. So this button stays visible and clickable for all players.
		btn.Visible = true

		-- FALSE-ADVERTISING FIX: restricted players don't receive the bundled 1,000 coins, so we must not
		-- ADVERTISE them either. Hide the coins portion of the pack art for restricted players: the
		-- CoinsIcon, its "+1,000 Coins" Title, and the "+" separator immediately before the CoinsIcon
		-- (the knife + "Random Mutation" portions stay shown, since those ARE granted). We resolve the
		-- right "+" by position: of the two "+" separators, the one whose X is just left of the CoinsIcon.
		local coinsIcon = sp:FindFirstChild("CoinsIcon")
		local coinsBonusParts = {}
		if coinsIcon then
			table.insert(coinsBonusParts, coinsIcon)
			-- find the "+" separator nearest to (and left of) the CoinsIcon
			local coinsX = coinsIcon.Position.X.Scale
			local bestPlus, bestDx = nil, math.huge
			for _, c in ipairs(sp:GetChildren()) do
				if c:IsA("TextLabel") and c.Name == "+" then
					local dx = coinsX - c.Position.X.Scale
					if dx > 0 and dx < bestDx then bestDx = dx; bestPlus = c end
				end
			end
			if bestPlus then table.insert(coinsBonusParts, bestPlus) end
		end
		local function applyPackCoinVisibility()
			-- read the attribute DIRECTLY (not the cached `paidRandomRestricted` local) so we never depend on
			-- the ORDER in which the policy-change signal handlers run — otherwise this could read a stale
			-- value if it fires before the handler that updates the local.
			local restricted = player:GetAttribute(RESTRICT_ATTR)
			if restricted == nil then restricted = true end  -- fail closed
			local show = not restricted
			for _, part in ipairs(coinsBonusParts) do
				if part and part.Parent then part.Visible = show end
			end
		end
		applyPackCoinVisibility()
		player:GetAttributeChangedSignal(RESTRICT_ATTR):Connect(applyPackCoinVisibility)
		PolicyUpdate.OnClientEvent:Connect(applyPackCoinVisibility)

		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(LIMITED_TIME_PACK_PRODUCT, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				setPriceLabel(btn, ROBUX_GLYPH .. " " .. info.PriceInRobux)
			end
		end)

		btn.MouseButton1Click:Connect(function()
			UISounds.click()
			PurchaseFX.prompt()
			MarketplaceService:PromptProductPurchase(player, LIMITED_TIME_PACK_PRODUCT)
		end)
	end
end

-- ===== SpecialKnife2 dev product =====
-- A second special-knife bundle tile. Wired the same way as the Blackhole pack above: live Robux
-- price on the layered Price label, hover/click sounds + the purchase prompt for its dev product.
local SPECIAL_KNIFE2_PRODUCT = Products.FrozenKnife
do
	local sp2 = scroll:FindFirstChild("SpecialKnife2")
	local btn = sp2 and sp2:FindFirstChild("BuyButton")
	if not btn then
		warn("[ShopClient] SpecialKnife2 BuyButton not found")
	else
		UISounds.bindTween(btn)
		btn.MouseEnter:Connect(function() UISounds.play("hover") end)
		btn:SetAttribute("UISoundsBound", true)
		btn.Visible = true

		local specialKnife2Stock = Remotes:WaitForChild("FrozenKnifeStock")
		local specialKnife2PriceText = nil
		local function specialKnife2SoldOut()
			return specialKnife2Stock.Value <= 0
		end
		refreshSpecialKnife2Availability = function()
			sp2.Visible = true
			btn.Active = not ownsLimitedStockWeapon and not specialKnife2SoldOut()
			btn.AutoButtonColor = btn.Active
			if ownsLimitedStockWeapon then
				setPriceLabel(btn, "Owned")
			elseif specialKnife2SoldOut() then
				setPriceLabel(btn, "Sold Out")
			elseif specialKnife2PriceText then
				setPriceLabel(btn, specialKnife2PriceText)
			end
		end
		refreshSpecialKnife2Availability()
		specialKnife2Stock.Changed:Connect(refreshSpecialKnife2Availability)
		task.spawn(function()
			while true do
				refreshSpecialKnife2Availability()
				task.wait(1)
			end
		end)

		-- FALSE-ADVERTISING FIX (same as the Blackhole pack): the bundled 1,000 coins are a Robux->coins
		-- path, which the SERVER withholds from players restricted from paid random items. So we must not
		-- ADVERTISE the coins to those players either: hide the CoinsIcon and the "+" separator immediately
		-- before it for restricted players (the knife + mutation-icon portions stay shown, since the knife
		-- IS granted to everyone). We resolve the right "+" by position: the one whose X is just left of the
		-- CoinsIcon.
		local coinsIcon = sp2:FindFirstChild("CoinsIcon")
		local coinsBonusParts = {}
		if coinsIcon then
			table.insert(coinsBonusParts, coinsIcon)
			local coinsX = coinsIcon.Position.X.Scale
			local bestPlus, bestDx = nil, math.huge
			for _, c in ipairs(sp2:GetChildren()) do
				if c:IsA("TextLabel") and c.Name == "+" then
					local dx = coinsX - c.Position.X.Scale
					if dx > 0 and dx < bestDx then bestDx = dx; bestPlus = c end
				end
			end
			if bestPlus then table.insert(coinsBonusParts, bestPlus) end
		end
		local function applyPack2CoinVisibility()
			-- read the attribute DIRECTLY (not the cached local) so we never depend on the ORDER the
			-- policy-change handlers run in.
			local restricted = player:GetAttribute(RESTRICT_ATTR)
			if restricted == nil then restricted = true end  -- fail closed
			local show = not restricted
			for _, part in ipairs(coinsBonusParts) do
				if part and part.Parent then part.Visible = show end
			end
		end
		applyPack2CoinVisibility()
		player:GetAttributeChangedSignal(RESTRICT_ATTR):Connect(applyPack2CoinVisibility)
		PolicyUpdate.OnClientEvent:Connect(applyPack2CoinVisibility)

		-- show the real Robux price on the layered Price label (matches the other shop buttons)
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(SPECIAL_KNIFE2_PRODUCT, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				setPriceLabel(btn, ROBUX_GLYPH .. " " .. info.PriceInRobux)
			end
		end)

		btn.MouseButton1Click:Connect(function()
			if ownsLimitedStockWeapon or specialKnife2SoldOut() then
				UISounds.error()
				refreshSpecialKnife2Availability()
				return
			end
			UISounds.click()
			PurchaseFX.prompt()
			MarketplaceService:PromptProductPurchase(player, SPECIAL_KNIFE2_PRODUCT)
		end)
	end
end

-- ===== Sports Crate (weekly RobuxCase loot box) =====
-- Buy1 / Buy3 / Buy10 prompt the weekly RobuxCase dev products (x1/x3/x10). The server's ProcessReceipt
-- reads the RobuxCase model attributes and opens the crate that many times. The RewardHolder shows the
-- crate's items + odds as live knife viewports (the Secret tier is hidden behind the mystery icon).
-- It's a paid random item, so the buy buttons are hidden for players restricted from paid random items.
local ROBUX_CRATE_NAME = "Elemental Crate"
local ROBUX_CRATE_PRODUCTS = {
	{ name = "Buy1", id = 3608973522 },
	{ name = "Buy3", id = 3608973496 },
	{ name = "Buy10", id = 3608973475 },
}
do
	local robuxCrate = scroll:FindFirstChild("ElementalCrate")
	if not robuxCrate then
		warn("[ShopClient] ElementalCrate frame not found")
	else
		-- populate the reward slots with the crate's items + odds (collapsed Secret -> one mystery slot)
		local rewardHolder = robuxCrate:FindFirstChild("RewardHolder")
		if rewardHolder then
			local slots = {}
			for _, c in ipairs(rewardHolder:GetChildren()) do
				if c:IsA("Frame") then table.insert(slots, c) end
			end
			table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			local odds = KnifeSkinManager.getCrateOdds(ROBUX_CRATE_NAME, true)
			table.sort(odds, function(a, b)
				local ra, rb = KnifeSkinManager.rarityRank(a.rarity), KnifeSkinManager.rarityRank(b.rarity)
				if ra ~= rb then return ra < rb end
				return a.chance > b.chance
			end)
			for i, slot in ipairs(slots) do
				local item = odds[i]
				slot.Visible = item ~= nil
				if item then
					local chanceLabel = slot:FindFirstChild("Chance")
					if chanceLabel then
						chanceLabel.Text = formatChance(item.chance)
						local top = chanceLabel:FindFirstChild("Top")
						if top and top:IsA("TextLabel") then top.Text = chanceLabel.Text end
					end
					local icon = slot:FindFirstChild("Icon")
					if icon then
						if item.rarity == "Secret" then
							KnifeIcon.render(icon, nil)  -- clear any viewport
							icon.Image = SECRET_ICON
						else
							icon.Image = ""
							KnifeIcon.render(icon, item.id)  -- live viewport of the knife model
						end
					end
				end
			end
		end

		-- wire the Buy1 / Buy3 / Buy10 buttons: live Robux price + purchase prompt
		local sportsBuyButtons = {}
		for _, prod in ipairs(ROBUX_CRATE_PRODUCTS) do
			local btn = robuxCrate:FindFirstChild(prod.name)
			if not btn then
				warn("[ShopClient] ElementalCrate " .. prod.name .. " button not found")
			else
				local productId = prod.id
				UISounds.bindTween(btn)
				btn.MouseEnter:Connect(function() UISounds.play("hover") end)
				btn:SetAttribute("UISoundsBound", true)
				table.insert(sportsBuyButtons, btn)
				task.spawn(function()
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
					end)
					if ok and info and info.PriceInRobux then
						setPriceLabel(btn, ROBUX_GLYPH .. " " .. info.PriceInRobux)
					end
				end)
				btn.MouseButton1Click:Connect(function()
					if isRestricted() then return end
					if player:GetAttribute("Unboxing") then UISounds.error(); return end
					UISounds.click()
					PurchaseFX.prompt()
					MarketplaceService:PromptProductPurchase(player, productId)
				end)
			end
		end

		-- paid-random gate: hide the buy buttons for restricted players (this is a loot box)
		local function applySportsVisibility()
			local restricted = player:GetAttribute(RESTRICT_ATTR)
			if restricted == nil then restricted = true end  -- fail closed
			for _, btn in ipairs(sportsBuyButtons) do
				if btn and btn.Parent then btn.Visible = restricted ~= true end
			end
		end
		applySportsVisibility()
		player:GetAttributeChangedSignal(RESTRICT_ATTR):Connect(applySportsVisibility)
		PolicyUpdate.OnClientEvent:Connect(applySportsVisibility)

		-- shimmer the LIMITED badge (matches the other promo tiles)
		local limitedInfo = robuxCrate:FindFirstChild("LimitedInfo")
		local liTop = limitedInfo and limitedInfo:FindFirstChild("Top")
		local liGrad = liTop and liTop:FindFirstChildOfClass("UIGradient")
		if liGrad then animateBadgeGradient(liGrad) end
	end
end

-- ===== Gift buttons =====
-- Each giftable DEV-PRODUCT tile has a per-product Gift button (named for its product, e.g.
-- "GiftVoidBlade"). Clicking it CLOSES the shop (so the picker doesn't overlap it) and opens the
-- GiftPlayer recipient picker for THAT tile's product -- the SAME dev product id as the tile's Buy
-- button (gifting reuses the product; only the server-side delivery target changes). When the picker
-- closes again, GiftPlayerClient re-opens the shop (it fires the shop's OpenShop event), so the player
-- lands back where they were.
--
-- GAMEPASS tiles (Vip, SeekerGamepass, CoinsGamepass) are NOT giftable -- a gamepass purchase always
-- lands on the buyer's own account and there's no ProcessReceipt to redirect it -- so their Gift
-- buttons (named "Gift*_Disabled") are hidden.
local OpenGiftPicker = Remotes:WaitForChild("OpenGiftPicker")  -- BindableEvent (created by GiftPlayerClient)

-- each entry: the tile frame, the per-product Gift button NAME on it, and the dev product id to gift.
local GIFT_BUTTON_PRODUCTS = {
	{ frame = scroll:FindFirstChild("SpecialKnife"),  buttonName = "Gift", product = LIMITED_TIME_PACK_PRODUCT },
	{ frame = scroll:FindFirstChild("SpecialKnife2"), buttonName = "Gift", product = SPECIAL_KNIFE2_PRODUCT },
}
-- coin-pack tiles live under CoinsDevProduct; their Gift buttons are named Gift500Coins / Gift1KCoins /
-- Gift5KCoins / Gift10KCoins (matching the frame name).
local COIN_GIFT_BUTTON_NAMES = {
	["500Coins"] = "Gift500Coins",
	["1KCoins"]  = "Gift1KCoins",
	["5KCoins"]  = "Gift5KCoins",
	["10KCoins"] = "Gift10KCoins",
}
if coinsDevSection then
	for frameName, productId in pairs(COIN_PRODUCTS) do
		table.insert(GIFT_BUTTON_PRODUCTS, {
			frame = coinsDevSection:FindFirstChild(frameName),
			buttonName = COIN_GIFT_BUTTON_NAMES[frameName],
			product = productId,
		})
	end
end

local function wireGiftButton(frame, buttonName, productId)
	if not frame or not buttonName then return end
	local giftBtn = frame:FindFirstChild(buttonName)
	if not giftBtn or not giftBtn:IsA("GuiButton") then return end
	UISounds.bindButton(giftBtn)
	giftBtn:SetAttribute("UISoundsBound", true)
	giftBtn.MouseButton1Click:Connect(function()
		UISounds.click()
		gui.Enabled = false           -- close the shop so the picker doesn't overlap it
		OpenGiftPicker:Fire(productId) -- open the recipient picker for this product
	end)
end
for _, entry in ipairs(GIFT_BUTTON_PRODUCTS) do
	wireGiftButton(entry.frame, entry.buttonName, entry.product)
end

-- hide the (non-giftable) gamepass Gift buttons, now named "Gift*_Disabled".
for _, info in ipairs({
	{ frame = vipFrame,    name = "GiftVip_Disabled" },
	{ frame = seekerFrame, name = "GiftSeeker_Disabled" },
	{ frame = coinsFrame,  name = "GiftDoubleCoins_Disabled" },
}) do
	local giftBtn = info.frame and info.frame:FindFirstChild(info.name)
	if giftBtn then giftBtn.Visible = false end
end
