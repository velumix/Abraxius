-- JoinAsSeekerClient: shows the mid-round prompt (a found hider, back in the lobby, or a player who
-- joined mid-round) with two choices:
--   * Be Seeker  -> join the round as a seeker (JoinAsSeekerResponse -> server convertToSeeker)
--   * Revive (paid) -> buy the current revive tier's dev product to come back as a live hider. Revive is
--     REPEATABLE with an escalating price; the server tells us which tier applies right now and the client
--     maps that tier to the matching product id for price display/prompting.
-- The Revive button only shows when the server says the player is currently revive-eligible.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

-- the dev product id for the player's CURRENT (next) revive. nil until the server tells us the tier.
local currentReviveProductId = nil

local player = Players.LocalPlayer
local gui = script.Parent  -- the JoinAsSeeker ScreenGui (ResetOnSpawn = false, so this persists)

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local OfferJoinAsSeeker = Remotes:WaitForChild("OfferJoinAsSeeker")
local JoinAsSeekerResponse = Remotes:WaitForChild("JoinAsSeekerResponse")
local RequestJoinOffer = Remotes:WaitForChild("RequestJoinOffer")
local ReviveEligibility = Remotes:WaitForChild("ReviveEligibility")
local ReviveTestRequest = Remotes:WaitForChild("ReviveTestRequest")  -- TEST-ONLY free revive (test place)
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local StateChanged = Remotes:WaitForChild("StateChanged")
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

-- Suppress the generic confetti "thank you" celebration for the revive dev products. A revive isn't a
-- cosmetic/coin purchase -- it just puts the player back in the round (with its own black-screen + role
-- re-announce), so the confetti would be out of place. These are all four escalating revive tier ids
-- (must match MarketplaceService's revive products). PurchaseFX checks this set in its global
-- PromptProductPurchaseFinished handler.
local REVIVE_PRODUCTS = { 3605235518, 3605238864, 3605239104, 3605239189 }
local okFX, PurchaseFX = pcall(function()
	return require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX", 5))
end)
if okFX and PurchaseFX and PurchaseFX.suppressProducts then
	for _, id in ipairs(REVIVE_PRODUCTS) do
		PurchaseFX.suppressProducts[id] = true
	end
end

-- ===== new GUI layout =====
-- JoinAsSeeker (ScreenGui) -> HolderFrame -> { Overview (backdrop img), ContainerFrame }
--   ContainerFrame -> { Bg, Title, CloseButton.ImageButton, Buttons -> { BeSeeker.BeSeeker, Revive.Revive } }
local holder = gui:WaitForChild("HolderFrame")
local container = holder:WaitForChild("ContainerFrame")
local buttons = container:WaitForChild("Buttons")
local seekerBtn = buttons:WaitForChild("BeSeeker"):WaitForChild("BeSeeker")
local reviveFrame = buttons:WaitForChild("Revive")
local reviveBtn = reviveFrame:WaitForChild("Revive")
local reviveLabel = reviveBtn:FindFirstChild("TextLabel")    -- "Revive N" price label
local reviveLabelShadow = reviveBtn:FindFirstChild("Shadow")  -- its drop-shadow duplicate
local closeBtn = container:WaitForChild("CloseButton"):WaitForChild("ImageButton")
local timerLabel = container:FindFirstChild("Timer")  -- "10s" countdown label; auto-closes the prompt at 0

-- The two buttons are laid out by a UIListLayout. We remember its authored horizontal alignment for
-- the two-button case and switch to Center when only "Be Seeker" is showing (so the lone button sits
-- in the middle instead of off to one side).
local buttonsLayout = buttons:FindFirstChildOfClass("UIListLayout")
local BUTTONS_ALIGN_BOTH = buttonsLayout and buttonsLayout.HorizontalAlignment or Enum.HorizontalAlignment.Center

-- ===== headline title (changes with revive availability) =====
-- TWO sibling TextLabels are both named "Title": the headline (RichText, with colored Seeker/Revive
-- words) and a small countdown ("10s"). WaitForChild("Title") is ambiguous, so we resolve the
-- headline by content: the Title whose text contains "Would you like". TitleShadow is the plain
-- (RichText=false) drop-shadow duplicate behind it; we keep it in sync with an uncolored string.
local titleLabel
for _, c in ipairs(container:GetChildren()) do
	if c:IsA("TextLabel") and c.Name == "Title" and string.find(c.Text, "Would you like", 1, true) then
		titleLabel = c
		break
	end
end
local titleShadow = container:FindFirstChild("TitleShadow")

-- prompt state (declared here so refreshTitle below can read reviveEligible)
local open = false
local reviveEligible = false

-- the two headline variants. RichText (colored) for the real label; plain for the shadow.
local TITLE_WITH_REVIVE = "Would you like to be <font color=\"#ff3333\">Seeker</font> or <font color=\"#33ff33\">Revive</font>?"
local TITLE_WITH_REVIVE_PLAIN = "Would you like to be Seeker or Revive?"
local TITLE_SEEKER_ONLY = "Would you like to join as <font color=\"#ff3333\">Seeker</font>?"
local TITLE_SEEKER_ONLY_PLAIN = "Would you like to join as Seeker?"

-- set the headline + its shadow to match whether revive is currently offered
local function refreshTitle()
	if titleLabel then
		titleLabel.Text = reviveEligible and TITLE_WITH_REVIVE or TITLE_SEEKER_ONLY
	end
	if titleShadow then
		titleShadow.Text = reviveEligible and TITLE_WITH_REVIVE_PLAIN or TITLE_SEEKER_ONLY_PLAIN
	end
end

-- ===== open/close tween setup =====
-- The card (ContainerFrame, center-anchored) pops in with a Back ease-out via a UIScale. Close reverses
-- it quickly (Quad ease-in), disabling the ScreenGui only AFTER the shrink finishes. animToken guards
-- against an open/close racing an in-flight tween (a fast double-tap can't leave the card half-scaled).
local cardScale = container:FindFirstChildOfClass("UIScale")
if not cardScale then
	cardScale = Instance.new("UIScale")
	cardScale.Parent = container
end
cardScale.Scale = 1

local OPEN_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local animToken = 0

-- 10s auto-close countdown. Each show() starts a fresh countdown; any hide()/choice/state change bumps
-- timerToken so the running countdown loop sees it's stale and stops (no overlapping timers).
local AUTO_CLOSE_SECONDS = 10
local timerToken = 0

-- make sure the buttons are interactive (an Active=false ImageButton ignores taps)
seekerBtn.Active = true
reviveBtn.Active = true
closeBtn.Active = true

-- button feel: hover sound + hover-grow / press-shrink tween (shared UISounds helper)
UISounds.bindTween(seekerBtn)
UISounds.bindTween(reviveBtn)
UISounds.bindTween(closeBtn)
seekerBtn.MouseEnter:Connect(function() UISounds.play("hover") end)
reviveBtn.MouseEnter:Connect(function() UISounds.play("hover") end)
closeBtn.MouseEnter:Connect(function() UISounds.play("hover") end)

-- write the revive button's price label (and its shadow) for the given product id. Shows the Robux
-- icon glyph next to the price (e.g. "Revive [R$] 9"). Falls back to a plain "Revive" if the price
-- can't be fetched yet. Cached so repeat lookups of the same tier are free.
local ROBUX_ICON = utf8.char(0xE002)  -- Roblox's built-in Robux symbol glyph
local priceCache = {}
local function setReviveLabel(productId)
	if not productId then return end
	local function apply(price)
		local text = price and ("Revive " .. ROBUX_ICON .. " " .. price) or "Revive"
		if reviveLabel then reviveLabel.Text = text end
		if reviveLabelShadow then reviveLabelShadow.Text = text end
	end
	if priceCache[productId] ~= nil then
		apply(priceCache[productId])
		return
	end
	apply(nil)  -- show "Revive" while we fetch
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			priceCache[productId] = info.PriceInRobux
			-- only apply if this is still the product we're offering (avoid a late fetch overwriting a newer tier)
			if currentReviveProductId == productId then apply(info.PriceInRobux) end
		end
	end)
end

-- show/hide the Revive button per the latest eligibility from the server, and update the headline
-- ("...be Seeker or Revive?" vs "...join as Seeker?") to match. When Revive is hidden, "Be Seeker" is
-- the only button, so center the layout; with both buttons, restore the authored alignment.
local function refreshReviveButton()
	reviveFrame.Visible = reviveEligible
	if buttonsLayout then
		buttonsLayout.HorizontalAlignment = reviveEligible and BUTTONS_ALIGN_BOTH or Enum.HorizontalAlignment.Center
	end
	refreshTitle()
end

-- instant=true skips the tween (used for the initial hide at load, before the GUI is ever shown).
local function hide(instant)
	open = false
	animToken += 1
	timerToken += 1   -- cancel any running auto-close countdown
	local myToken = animToken
	if instant then
		cardScale.Scale = 1
		gui.Enabled = false
		return
	end
	-- shrink the card, then disable the ScreenGui once the shrink completes
	local tw = TweenService:Create(cardScale, CLOSE_TWEEN, { Scale = 0.7 })
	tw.Completed:Once(function()
		if myToken == animToken then  -- not superseded by a new open in the meantime
			gui.Enabled = false
			cardScale.Scale = 1  -- reset for the next open
		end
	end)
	tw:Play()
end

-- Start (or restart) the 10s auto-close countdown. Updates the Timer label each second and, when it
-- reaches 0, auto-declines exactly like the close (X) button. Cancelable: a new show(), any button
-- choice, or a hide() bumps timerToken, which this loop checks every tick and bails on if superseded.
local function startCountdown()
	timerToken += 1
	local myToken = timerToken
	local remaining = AUTO_CLOSE_SECONDS
	if timerLabel then timerLabel.Text = remaining .. "s" end
	task.spawn(function()
		while remaining > 0 do
			task.wait(1)
			if myToken ~= timerToken then return end   -- superseded (closed / re-shown) -> stop silently
			remaining -= 1
			if timerLabel then timerLabel.Text = remaining .. "s" end
		end
		if myToken ~= timerToken or not open then return end
		-- time's up: decline like the X button (tell the server they passed) and close
		UISounds.play("close")
		JoinAsSeekerResponse:FireServer(false)
		hide()
	end)
end

local function show()
	open = true
	animToken += 1
	refreshReviveButton()
	-- start small, enable, then pop the card in
	cardScale.Scale = 0.7
	gui.Enabled = true
	TweenService:Create(cardScale, OPEN_TWEEN, { Scale = 1 }):Play()
	startCountdown()  -- begin the 10s auto-close timer
end

hide(true)  -- start hidden (instant, no tween)

-- ===== Be Seeker =====
local function chooseSeeker()
	if not open then return end
	UISounds.play("select")
	JoinAsSeekerResponse:FireServer(true)
	hide()
end

-- ===== Revive =====
-- TEST MODE: while testing in the published test place, clicking Revive asks the server for a FREE
-- revive (skipping the Robux purchase) -- because Roblox doesn't fire ProcessReceipt in Studio and we
-- want to exercise the flow in the live test game. The server is the real gate (REVIVE_FREE_TESTING
-- in MatchManager); set REVIVE_FREE_TESTING_CLIENT = false (and the server flag) to restore real
-- purchases for the production game.
local REVIVE_FREE_TESTING_CLIENT = false
local function chooseRevive()
	if not open then return end
	if not reviveEligible or not currentReviveProductId then UISounds.play("error"); return end
	UISounds.play("select")
	timerToken += 1   -- stop the auto-close countdown so the prompt can't close mid-purchase
	if timerLabel then timerLabel.Text = "" end
	if REVIVE_FREE_TESTING_CLIENT then
		ReviveTestRequest:FireServer()   -- free revive (server validates + is gated by REVIVE_FREE_TESTING)
	else
		MarketplaceService:PromptProductPurchase(player, currentReviveProductId)
	end
	-- keep the prompt open; the server revives + black-screens them on a successful purchase, and the
	-- RoleAnnounce("Hider")/InRound it sends will dismiss this prompt via the handlers below. If they
	-- cancel the purchase, the prompt stays so they can still choose Be Seeker or close.
end

-- ===== Close (decline) =====
local function chooseClose()
	if not open then return end
	UISounds.play("close")
	JoinAsSeekerResponse:FireServer(false)  -- tell the server they declined the seeker offer
	hide()
end

seekerBtn.Activated:Connect(chooseSeeker)
seekerBtn.MouseButton1Click:Connect(chooseSeeker)
reviveBtn.Activated:Connect(chooseRevive)
reviveBtn.MouseButton1Click:Connect(chooseRevive)
closeBtn.Activated:Connect(chooseClose)
closeBtn.MouseButton1Click:Connect(chooseClose)

-- Server controls the prompt: fired with no arg (or true) to SHOW it, or false to HIDE/dismiss it.
OfferJoinAsSeeker.OnClientEvent:Connect(function(shouldShow)
	if shouldShow == false then
		hide()
	else
		UISounds.play("select")
		show()
	end
end)

-- Server pushes our live Revive eligibility + next-tier info. Payload is a table:
--   { canRevive = bool, tier = n|nil }
-- (Older single-bool payloads are tolerated for safety.)
ReviveEligibility.OnClientEvent:Connect(function(data)
	if type(data) == "table" then
		reviveEligible = data.canRevive == true
		currentReviveProductId = data.tier and REVIVE_PRODUCTS[data.tier] or nil
		if currentReviveProductId then setReviveLabel(currentReviveProductId) end
	else
		reviveEligible = data == true   -- legacy bool fallback
	end
	refreshReviveButton()
end)

-- Auto-dismiss so a prompt never lingers into a context where it no longer applies:
--  * becoming a Seeker, OR being revived as a Hider (server re-announces the role) -> close
--  * a new round's role reveal / hide phase begins, or we return to intermission/resolve -> close
RoleAnnounce.OnClientEvent:Connect(function(role)
	if open and (role == "Seeker" or role == "Hider") then hide() end
end)
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if open and (data.note == "role reveal" or data.note == "hiders hiding" or data.state == "INTERMISSION" or data.state == "RESOLVE" or data.state == "REVEALING_HIDERS") then
		hide()
	end
end)

-- Ask the server to re-push any pending offer + our current revive eligibility once our handlers are
-- connected (covers a slow-loading client that missed the server's one-shot FireClient).
task.spawn(function()
	for _ = 1, 3 do
		RequestJoinOffer:FireServer()
		ReviveEligibility:FireServer()
		if open then break end
		task.wait(1.5)
	end
end)
