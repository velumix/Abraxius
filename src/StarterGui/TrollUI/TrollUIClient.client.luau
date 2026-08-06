-- TrollUIClient: wires the TrollUI panel (the one matching the Trolls mock: 5 rows, each with a green
-- "Troll One" button and a red "Troll ALL" button). It:
--   1) labels each of the 5 template rows from TrollConfig.Order (Jumpscare, Flashbang, Freeze, Trip,
--      Confusion) and binds its two buttons to prompt the matching dev product,
--   2) gates the whole panel to HIDERS during the active ROUND (seek) phase — the buttons grey out and
--      do nothing otherwise (and the panel auto-closes if you stop being an eligible hider),
--   3) opens/closes from the HUD button (Hud.BottomButtons.TrollButton), which is itself shown only to
--      eligible hiders-in-round. Both the panel and the HUD button animate with scale tweens.
--
-- The actual troll is applied SERVER-SIDE in MatchManager.ProcessReceipt after it validates the buyer
-- is an active hider in the seek phase — so a client can never trigger a troll for free. This script
-- only PROMPTS the purchase, exactly like RevealUIClient does for the reveal products.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- keyboard key that toggles the Trolls panel (matches the "R" shown on the HUD button's Keybind label)
local TROLL_KEYBIND = Enum.KeyCode.R

-- platform: PC shows the (R) keybind hint; mobile/tablet hides it. Treat as mobile when touch-only
-- (real device) OR when emulating a touch device in Studio (the emulator reports BOTH touch + mouse,
-- so a plain check would wrongly show the PC label on the emulated phone). Same rule the other HUD
-- button scripts (Taunt/Pose/Paint/Lock) use, so the whole bottom row behaves consistently.
local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local emulatingTouch = game:GetService("RunService"):IsStudio() and UserInputService.TouchEnabled
local isMobile = touchOnly or emulatingTouch
-- set a label AND its "Top" drop-shadow overlay so the layered look stays correct (same helper the
-- other HUD scripts use for the Keybind label).
local function setLayered(label, text)
	if not label then return end
	label.Text = text
	local top = label:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then top.Text = text end
end

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local StateChanged = Remotes:WaitForChild("StateChanged")
local TrollConfig = require(ReplicatedStorage:WaitForChild("TrollConfig"))
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))

-- optional shared helpers (match the rest of the game's UI); all guarded so missing ones don't error
local UISounds
pcall(function() UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5)) end)
local PurchaseFX
pcall(function()
	PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX", 5))
end)
-- suppress the generic confetti "thank you" for troll products — the troll has its own banner/effects.
if PurchaseFX and PurchaseFX.suppressProducts then
	for _, key in ipairs(TrollConfig.Order) do
		local t = TrollConfig.Trolls[key]
		if t then
			PurchaseFX.suppressProducts[t.oneProduct] = true
			PurchaseFX.suppressProducts[t.allProduct] = true
		end
	end
end

local screenGui = script.Parent           -- the TrollUI ScreenGui (this script lives inside it)
local holder = screenGui:WaitForChild("HolderFrame")
local panel = holder:WaitForChild("Trolls")
local scrolling = panel:WaitForChild("ScrollingFrame")
local closeButton = panel:WaitForChild("CloseButton")

screenGui.Enabled = false  -- starts hidden; opened by the HUD TrollButton (wired below)

-- a UIScale on the panel drives the open/close pop tween (added if the panel doesn't have one)
local panelScale = panel:FindFirstChildOfClass("UIScale")
if not panelScale then
	panelScale = Instance.new("UIScale")
	panelScale.Scale = 1
	panelScale.Parent = panel
end

-- ===== eligibility state =====
-- Trolls are usable only by an active HIDER during the ROUND (seek) phase. We track role + in-round +
-- match state from the same remotes RevealUIClient uses, so the gating matches the rest of the game.
local isHider = false
local inRound = false
local roundActive = false   -- true only while state == "ROUND" (seek phase)

local function eligible()
	return isHider and inRound and roundActive
end

-- forward declaration: bindBuyButton (defined below) closes the panel after a purchase prompt, but
-- closePanel is defined further down with the rest of the open/close logic. Declaring it here makes
-- it an upvalue so the button handler resolves it correctly (rather than a nil global).
local closePanel

-- ===== button visuals =====
local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.93
local TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function getScale(btn)
	local s = btn:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Scale = 1; s.Parent = btn end
	return s
end
local function tweenTo(btn, scale) TweenService:Create(getScale(btn), TWEEN, { Scale = scale }):Play() end

-- collect the 5 template rows in layout order. The rows are all named "Afk" in the template; we sort
-- by their LayoutOrder (then by Y position as a tiebreak) so the visual top-to-bottom order matches
-- TrollConfig.Order. We then RENAME each row to its troll key so future code/debugging is readable.
local function getRows()
	local rows = {}
	for _, child in ipairs(scrolling:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("Buttons") then
			table.insert(rows, child)
		end
	end
	table.sort(rows, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)
	return rows
end

-- set a row's visible label. The template row has a "Name" TextLabel with a nested "Top" label (the
-- drop-shadow duplicate used elsewhere in this game's UI); set both so the styling matches.
local function setRowLabel(row, text)
	local nameLabel = row:FindFirstChild("Name")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = text
		local top = nameLabel:FindFirstChild("Top")
		if top and top:IsA("TextLabel") then top.Text = text end
	end
end

local function setRowIcon(row, image)
	local icon = row:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") and image and image ~= "rbxassetid://0" then
		icon.Image = image
	end
end

-- bind one buy button to prompt a product. Greys/blocks the click when the player isn't an eligible
-- hider-in-round. We don't disable the instance (so hover art still reads), we just gate the action.
local function bindBuyButton(btn, getProductId)
	if not btn or not btn:IsA("GuiButton") then return end
	btn.AutoButtonColor = false
	getScale(btn)
	btn.MouseEnter:Connect(function()
		if UISounds then pcall(function() UISounds.play("hover") end) end
		tweenTo(btn, HOVER_SCALE)
	end)
	btn.MouseLeave:Connect(function() tweenTo(btn, 1) end)
	btn.MouseButton1Down:Connect(function() tweenTo(btn, PRESS_SCALE) end)
	btn.MouseButton1Up:Connect(function() tweenTo(btn, HOVER_SCALE) end)
	btn.MouseButton1Click:Connect(function()
		if UISounds then pcall(function() UISounds.click() end) end
		tweenTo(btn, PRESS_SCALE); task.delay(0.1, function() tweenTo(btn, 1) end)
		if not eligible() then
			-- not an active hider in the seek phase: do nothing (the server would refuse anyway).
			return
		end
		local productId = getProductId()
		if not productId then return end
		if PurchaseFX then pcall(function() PurchaseFX.prompt() end) end
		GamepadConfig.prepForCorePrompt()  -- gamepad: hand selection to the prompt so OK/Cancel are reachable
		MarketplaceService:PromptProductPurchase(player, productId)
		-- close the panel once the purchase prompt has been triggered (the dev-product dialog is now
		-- on screen; the troll itself plays out via the server + banners, so the panel's job is done).
		closePanel()
	end)
end

-- ===== build the rows from config =====
local built = false
local function buildRows()
	if built then return end
	local rows = getRows()
	if #rows == 0 then return end
	built = true
	for i, key in ipairs(TrollConfig.Order) do
		local row = rows[i]
		local def = TrollConfig.Trolls[key]
		if row and def then
			row.Name = key  -- rename "Afk" -> "Jumpscare" etc. for readability
			setRowLabel(row, def.name)
			setRowIcon(row, def.icon)
			local buttons = row:FindFirstChild("Buttons")
			if buttons then
				-- green OnButton = Troll One (nearest seeker); red OffButton = Troll ALL (every seeker)
				bindBuyButton(buttons:FindFirstChild("OnButton"), function() return def.oneProduct end)
				bindBuyButton(buttons:FindFirstChild("OffButton"), function() return def.allProduct end)
				-- the unused 3rd "GrayButton" in the template is hidden (the mock has only two buttons/row)
				local gray = buttons:FindFirstChild("GrayButton")
				if gray then gray.Visible = false end
				-- set the button captions if they carry text labels (green "Troll One", red "Troll ALL")
				local function caption(b, txt)
					if not b then return end
					local tl = b:FindFirstChild("TextLabel")
					if tl and tl:IsA("TextLabel") then
						tl.Text = txt
						local inner = tl:FindFirstChild("TextLabel")
						if inner and inner:IsA("TextLabel") then inner.Text = txt end
					end
				end
				caption(buttons:FindFirstChild("OnButton"), "Troll One")
				caption(buttons:FindFirstChild("OffButton"), "Troll ALL")
			end
		end
	end
end

-- ===== open / close (tweened) =====
-- Open: enable the GUI, then pop the panel from small->1 with a Back ease (a little overshoot bounce).
-- Close: shrink back down and disable the GUI when the tween finishes. animToken guards against an
-- open/close firing during an in-flight tween (so a fast double-tap can't leave it half-open).
local OPEN_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local animToken = 0
local isOpen = false

local function tweenOpen()
	animToken += 1
	isOpen = true
	panelScale.Scale = 0.6
	screenGui.Enabled = true
	TweenService:Create(panelScale, OPEN_TWEEN, { Scale = 1 }):Play()
end

local function tweenClose()
	animToken += 1
	local myToken = animToken
	isOpen = false
	local tw = TweenService:Create(panelScale, CLOSE_TWEEN, { Scale = 0.6 })
	tw.Completed:Once(function()
		if myToken == animToken then
			screenGui.Enabled = false
			panelScale.Scale = 1  -- reset for next open
		end
	end)
	tw:Play()
end

closePanel = function()
	if not isOpen then return end
	if UISounds then pcall(function() UISounds.click() end) end
	tweenClose()
end

local function openPanel()
	buildRows()
	-- Only open for an eligible hider-in-round. The HUD button is hidden for non-eligible players too,
	-- but we guard here so the panel can't be force-opened by an ineligible player.
	if not eligible() then
		return false
	end
	if isOpen then return true end
	if UISounds then pcall(function() UISounds.click() end) end
	tweenOpen()
	return true
end

local function togglePanel()
	if isOpen then closePanel() else openPanel() end
end

-- close button
if closeButton and closeButton:IsA("GuiButton") then
	closeButton.MouseButton1Click:Connect(closePanel)
end

-- If the player stops being eligible while the panel is open (round ends, they get found, etc.),
-- close it so they can't sit on a stale panel.
local function refreshGate()
	if isOpen and not eligible() then
		tweenClose()
	end
end

-- ===== HUD TrollButton (Hud.BottomButtons.TrollButton) =====
-- Opens/closes this panel. Shown only to an eligible hider-in-round (matching the panel's gating),
-- with a hover/press scale tween like the game's other buttons. The Hud ScreenGui is ResetOnSpawn=
-- false, but if it's ever replaced we re-resolve + re-bind the button on the new copy.
local HUD_HOVER = 1.08
local HUD_PRESS = 0.92
local HUD_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local trollHudButton  -- the currently-bound TrollButton

local function refreshHudButtonVisible()
	if trollHudButton and trollHudButton.Parent then
		trollHudButton.Visible = eligible()
	end
end

local function bindHudButton(hud)
	if not hud then return end
	local bottom = hud:FindFirstChild("BottomButtons")
	local btn = bottom and bottom:FindFirstChild("TrollButton")
	if not btn or not btn:IsA("GuiButton") then return end
	if btn:GetAttribute("TrollBound") then trollHudButton = btn; refreshHudButtonVisible(); return end
	btn:SetAttribute("TrollBound", true)
	trollHudButton = btn
	btn.AutoButtonColor = false
	-- Keybind hint: show "(R)" on PC, hide it on mobile/tablet (matches the other bottom-row buttons).
	local keybindLabel = btn:FindFirstChild("Keybind")
	if keybindLabel then
		if isMobile then
			keybindLabel.Visible = false
		else
			keybindLabel.Visible = true
			setLayered(keybindLabel, "(R)")
		end
	end
	local scale = getScale(btn)
	btn.MouseEnter:Connect(function()
		if UISounds then pcall(function() UISounds.play("hover") end) end
		TweenService:Create(scale, HUD_TWEEN, { Scale = HUD_HOVER }):Play()
	end)
	btn.MouseLeave:Connect(function() TweenService:Create(scale, HUD_TWEEN, { Scale = 1 }):Play() end)
	btn.MouseButton1Down:Connect(function() TweenService:Create(scale, HUD_TWEEN, { Scale = HUD_PRESS }):Play() end)
	btn.MouseButton1Up:Connect(function() TweenService:Create(scale, HUD_TWEEN, { Scale = HUD_HOVER }):Play() end)
	btn.MouseButton1Click:Connect(function()
		if UISounds then pcall(function() UISounds.click() end) end
		TweenService:Create(scale, HUD_TWEEN, { Scale = HUD_PRESS }):Play()
		task.delay(0.1, function() TweenService:Create(scale, HUD_TWEEN, { Scale = 1 }):Play() end)
		togglePanel()
	end)
	refreshHudButtonVisible()
end

-- bind the current Hud and any future copy added to PlayerGui
local existingHud = pg:FindFirstChild("Hud")
if existingHud then bindHudButton(existingHud) end
pg.ChildAdded:Connect(function(child)
	if child.Name == "Hud" and child:IsA("ScreenGui") then
		task.defer(bindHudButton, child)  -- defer so descendants exist before we resolve them
	end
end)

RoleAnnounce.OnClientEvent:Connect(function(role)
	isHider = (role == "Hider")
	refreshGate()
	refreshHudButtonVisible()
end)
InRound.OnClientEvent:Connect(function(state)
	inRound = (state == true)
	if not inRound then isHider = false end
	refreshGate()
	refreshHudButtonVisible()
end)
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.state == nil then return end
	roundActive = (data.state == "ROUND")
	refreshGate()
	refreshHudButtonVisible()
end)

-- ===== open hooks (also available for keybinds / other scripts) =====
-- The HUD TrollButton above is the primary opener; these remain so you can open/close/toggle the panel
-- from anywhere (e.g. a gamepad keybind). All refuse to open for an ineligible player.
_G.OpenTrollUI = openPanel
_G.CloseTrollUI = closePanel
_G.ToggleTrollUI = togglePanel
_G.IsTrollUIEligible = eligible

local openEvent = ReplicatedStorage:FindFirstChild("OpenTrollUI")
if not openEvent then
	openEvent = Instance.new("BindableEvent")
	openEvent.Name = "OpenTrollUI"
	openEvent.Parent = ReplicatedStorage
end
openEvent.Event:Connect(openPanel)

-- ===== keybind (R) =====
-- Toggle the Trolls panel with the keyboard key shown on the HUD button (R). We ignore the input when
-- gameProcessedEvent is true (e.g. the player is typing in chat) so it never fires while typing, and
-- togglePanel itself refuses to OPEN for an ineligible player — so pressing R does nothing unless
-- you're an active hider in the seek phase, exactly like the HUD button.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TROLL_KEYBIND then
		togglePanel()
	end
end)

-- build rows up front so the first open is instant (also makes the labels correct if you peek in Studio)
buildRows()
