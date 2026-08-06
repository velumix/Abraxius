-- KnifeEquipTutorialClient: an interactive, pointer-driven walkthrough that runs exactly ONCE per
-- player, ever -- the FIRST time they unbox a knife. It teaches the three actions needed to equip it:
--   1) open the Inventory     -> advances when the Inventory ScreenGui becomes Enabled
--   2) select a knife          -> advances when ANY knife cell is selected (pointer guides to the new one)
--   3) tap Equip               -> advances when the EQUIPPED knife changes; then it finishes
--
-- Steps 2 and 3 are intentionally GENERALIZED: the pointer suggests the just-unboxed knife, but the
-- player may select/equip any knife and still progress. This avoids a deadlock where selecting a
-- different knife than the one the tutorial named left the equip step waiting forever.
--
-- It reuses the SAME pointer/ring/caption/dim style as HiderTutorialClient. It never blocks the real
-- buttons (it points AT them and lets the player tap the actual UI). The server (KnifeTutorialManager)
-- gates it to once-per-player-ever via a DataStore flag, exactly like the hider tutorial.
--
-- Trigger: UnboxClient fires GameRemotes.KnifeUnboxedLocal (a BindableEvent) AFTER the unbox UI
-- closes, passing the won item's { name, skinId, rarity }. We ask the server if this player has
-- already seen the tutorial; if not, we run it and then mark it done so it NEVER repeats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- ===== cross-tutorial mutual exclusion =====
-- Shared with HiderTutorialClient: the player attribute "TutorialActive" is true while EITHER tutorial
-- is on screen, so the two never overlap. Before starting we wait for the other to clear it; on finish
-- we clear it. This tutorial is event-driven (fires once when the first knife is unboxed) and is NOT
-- time-gated, so if the hider tutorial is running we just defer and run as soon as it finishes.
local TUTORIAL_ACTIVE_ATTR = "TutorialActive"
local function anotherTutorialActive()
	return player:GetAttribute(TUTORIAL_ACTIVE_ATTR) == true
end
local function setTutorialActive(on)
	player:SetAttribute(TUTORIAL_ACTIVE_ATTR, on and true or false)
end
-- Yield until no tutorial is active (or a timeout safety valve so we never hang if the other script
-- errors without clearing the flag). Returns true if it's clear to proceed.
local function waitForNoTutorial(timeout)
	local waited = 0
	while anotherTutorialActive() and waited < (timeout or 60) do
		task.wait(0.2); waited += 0.2
	end
	return not anotherTutorialActive()
end

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local KnifeUnboxedLocal = Remotes:WaitForChild("KnifeUnboxedLocal")
local InRound = Remotes:WaitForChild("InRound")
local KnifeTutorialQuery = Remotes:WaitForChild("KnifeTutorialQuery")
local KnifeTutorialState = Remotes:WaitForChild("KnifeTutorialState")
local KnifeTutorialDone = Remotes:WaitForChild("KnifeTutorialDone")

-- ===== TESTING OVERRIDE =====
-- Keep this false for normal testing so Studio follows the same once-per-player ProfileStore gate as
-- production. Temporarily set true only when intentionally rehearsing the walkthrough repeatedly.
local FORCE_EVERY_UNBOX = false

local GOLD = Color3.fromRGB(255, 215, 0)  -- the selected-cell border color used by InventoryClient
local function colorsClose(a, b)
	return math.abs(a.R-b.R) < 0.02 and math.abs(a.G-b.G) < 0.02 and math.abs(a.B-b.B) < 0.02
end

-- ===== overlay GUIs (two layers, same approach as the hider tutorial) =====
local dimGui = Instance.new("ScreenGui")
dimGui.Name = "KnifeTutorialDimGui"
dimGui.ResetOnSpawn = false
dimGui.IgnoreGuiInset = false
dimGui.DisplayOrder = 250
dimGui.Enabled = false
dimGui.Parent = pg

local gui = Instance.new("ScreenGui")  -- marker layer (pointer/ring/caption)
gui.Name = "KnifeTutorialGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 270
gui.Enabled = false
gui.Parent = pg

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Position = UDim2.fromOffset(0, -80)
dim.Size = UDim2.new(1, 0, 1, 160)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.55
dim.Active = false
dim.Selectable = false
dim.ZIndex = 1
dim.Parent = dimGui

local pointer = Instance.new("TextLabel")
pointer.Name = "Pointer"
pointer.Size = UDim2.fromOffset(54, 54)
pointer.BackgroundTransparency = 1
pointer.Text = "\u{1F449}"  -- pointing hand
pointer.TextScaled = true
pointer.ZIndex = 6
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Visible = false
pointer.Parent = gui

local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.BackgroundTransparency = 1
ring.BorderSizePixel = 0
ring.ZIndex = 5
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Visible = false
ring.Parent = gui
local ringCorner = Instance.new("UICorner", ring); ringCorner.CornerRadius = UDim.new(0, 12)
local ringStroke = Instance.new("UIStroke", ring)
ringStroke.Color = Color3.fromRGB(235, 70, 70)
ringStroke.Thickness = 3
ringStroke.Transparency = 0

local caption = Instance.new("TextLabel")
caption.Name = "Caption"
caption.AnchorPoint = Vector2.new(0, 1)
caption.Position = UDim2.fromOffset(0, 0)
caption.Size = UDim2.fromOffset(560, 70)
caption.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
caption.BackgroundTransparency = 0.1
caption.TextColor3 = Color3.fromRGB(255, 255, 255)
caption.TextScaled = true
caption.Text = ""
caption.ZIndex = 6
local okFont = pcall(function()
	caption.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
end)
if not okFont then caption.Font = Enum.Font.FredokaOne end
caption.Parent = gui
Instance.new("UICorner", caption).CornerRadius = UDim.new(0, 12)
local capPad = Instance.new("UIPadding", caption)
capPad.PaddingLeft = UDim.new(0, 16); capPad.PaddingRight = UDim.new(0, 16)
capPad.PaddingTop = UDim.new(0, 10); capPad.PaddingBottom = UDim.new(0, 10)
local capStroke = Instance.new("UIStroke", caption)
capStroke.Color = Color3.fromRGB(235, 70, 70); capStroke.Thickness = 2
local capSizeConstraint = Instance.new("UITextSizeConstraint", caption)
capSizeConstraint.MaxTextSize = 20; capSizeConstraint.MinTextSize = 8
local capScale = Instance.new("UIScale", caption)
-- mobile = touch-only device (no mouse). Treat Studio's touch emulator as mobile too (it reports BOTH
-- touch + mouse), mirroring the rule the HUD button scripts use -- otherwise the emulator is wrongly
-- treated as PC. On mobile we shrink the caption so it doesn't dominate the smaller screen / cover the
-- buttons it points at.
local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local emulatingTouch = RunService:IsStudio() and UserInputService.TouchEnabled
local IS_MOBILE = touchOnly or emulatingTouch
local MOBILE_CAPTION_MULT = IS_MOBILE and 0.62 or 1
local function fitCaption()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	capScale.Scale = math.clamp((vp.X * 0.9) / 560, 0.5, 1) * MOBILE_CAPTION_MULT
end
fitCaption()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitCaption)
end

-- caption follows the pointer's top-right, clamped on-screen (same as hider tutorial)
-- EXCEPTION: when captionAnchorTarget is set (a GuiObject), the caption is parked ABOVE that target
-- instead of beside the pointer. Used for steps where the target button sits high on a panel and a
-- side-placed caption would be clamped on top of the very button the player must tap (e.g. EQUIP on
-- mobile, where the wide caption otherwise covers the button).
local captionAnchorTarget = nil
local captionBelow = false  -- when true, the anchored caption sits BELOW the target instead of above
local CAP_GAP = 14
local CAP_ABOVE_GAP = 12  -- vertical gap between the caption's bottom and the target's top
local captionConn = RunService.RenderStepped:Connect(function()
	if not gui.Enabled then return end
	local cam = workspace.CurrentCamera
	local vpX = cam and cam.ViewportSize.X or 1280
	local vpY = cam and cam.ViewportSize.Y or 720
	local scaledW = caption.AbsoluteSize.X
	local scaledH = caption.AbsoluteSize.Y
	-- ANCHORED placement: center the caption horizontally on the target. By default it sits just ABOVE
	-- the target's top edge (dropping below if there's no room). When captionBelow is set, it sits just
	-- BELOW the target's bottom edge instead (used for the select step, where the pointer is under the
	-- cell and the caption goes under the pointer). caption AnchorPoint is (0,1): Position is BOTTOM-LEFT.
	if captionAnchorTarget and captionAnchorTarget.Parent and captionAnchorTarget.AbsoluteSize.X > 0 then
		local ap = captionAnchorTarget.AbsolutePosition
		local asz = captionAnchorTarget.AbsoluteSize
		local x = ap.X + asz.X/2 - scaledW/2          -- centered horizontally on the target
		local y
		if captionBelow then
			-- caption's TOP sits below the target's bottom; add a pointer-sized gap so it clears the hand
			y = ap.Y + asz.Y + 78 + scaledH             -- bottom-edge y (top sits ~78px below the cell, under the pointer)
			if y > vpY - 8 then
				y = ap.Y - CAP_ABOVE_GAP                  -- no room below: fall back to just above the target
			end
		else
			y = ap.Y - CAP_ABOVE_GAP                    -- caption bottom sits just above the target's top
			if y - scaledH < 8 then
				y = ap.Y + asz.Y + CAP_ABOVE_GAP + scaledH  -- no room above: drop the caption BELOW the target
			end
		end
		x = math.clamp(x, 8, math.max(8, vpX - scaledW - 8))
		y = math.clamp(y, scaledH + 8, vpY - 8)
		caption.Position = UDim2.fromOffset(x, y)
		return
	end
	if pointer.Visible then
		local pp = pointer.AbsolutePosition
		local ps = pointer.AbsoluteSize
		local x = pp.X + ps.X + CAP_GAP
		local y = pp.Y
		x = math.clamp(x, 8, math.max(8, vpX - scaledW - 8))
		y = math.clamp(y, scaledH + 8, vpY - 8)
		caption.Position = UDim2.fromOffset(x, y)
	else
		caption.Position = UDim2.fromOffset(math.floor((vpX - scaledW) / 2), scaledH + 24)
	end
end)

-- ===== pointer/ring placement + bob =====
local bobConn = nil
local function stopBob()
	if bobConn then bobConn:Disconnect(); bobConn = nil end
end

local function pointAt(target, side)
	stopBob()
	if not target or not target:IsA("GuiObject") then
		pointer.Visible = false; ring.Visible = false
		return
	end
	side = side or "left"
	local function reposition()
		local ap = target.AbsolutePosition
		local asz = target.AbsoluteSize
		if asz.X <= 0 or asz.Y <= 0 then ring.Visible = false; pointer.Visible = false; return end
		local cx, cy = ap.X + asz.X/2, ap.Y + asz.Y/2
		ring.Visible = true
		ring.Position = UDim2.fromOffset(cx, cy)
		ring.Size = UDim2.fromOffset(asz.X + 18, asz.Y + 18)
		pointer.Visible = true
		if side == "left" then
			pointer.Position = UDim2.fromOffset(ap.X - 36, cy); pointer.Rotation = 0
		elseif side == "right" then
			pointer.Position = UDim2.fromOffset(ap.X + asz.X + 36, cy); pointer.Rotation = 180
		elseif side == "top" then
			pointer.Position = UDim2.fromOffset(cx, ap.Y - 36); pointer.Rotation = 90
		else
			pointer.Position = UDim2.fromOffset(cx, ap.Y + asz.Y + 36); pointer.Rotation = -90
		end
	end
	reposition()
	local t0 = os.clock()
	bobConn = RunService.RenderStepped:Connect(function()
		reposition()
		if not pointer.Visible then return end
		local phase = math.sin((os.clock() - t0) * 6) * 6
		local p = pointer.Position
		if side == "left" then
			pointer.Position = UDim2.fromOffset(p.X.Offset + phase, p.Y.Offset)
		elseif side == "right" then
			pointer.Position = UDim2.fromOffset(p.X.Offset - phase, p.Y.Offset)
		elseif side == "top" then
			pointer.Position = UDim2.fromOffset(p.X.Offset, p.Y.Offset + phase)
		else
			pointer.Position = UDim2.fromOffset(p.X.Offset, p.Y.Offset - phase)
		end
		ringStroke.Transparency = 0.3 + 0.3 * (math.sin((os.clock()-t0) * 4) * 0.5 + 0.5)
	end)
end

local function hidePointerAll()
	stopBob()
	pointer.Visible = false
	ring.Visible = false
end

-- ===== Skip button =====
-- A always-available exit so the player is never trapped if they're confused, change their mind, or
-- hit a state the step engine can't advance from. Tapping it ends the tutorial AND marks it seen on
-- the server (it counts as completed and never shows again). Wired to skipTutorial(), defined once
-- finish() exists below.
-- Placement: PC centers it along the top edge; mobile pins it to the top-right corner (set below).
local skipBtn = Instance.new("TextButton")
skipBtn.Name = "SkipButton"
skipBtn.AnchorPoint = Vector2.new(0.5, 0)
skipBtn.Position = UDim2.new(0.5, 0, 0, 12)  -- top-center (PC default; overridden for mobile below)
skipBtn.Size = UDim2.fromOffset(150, 40)
skipBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
skipBtn.BackgroundTransparency = 0.1
skipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
skipBtn.TextScaled = true
skipBtn.Text = "Skip Tutorial  \u{2715}"
skipBtn.AutoButtonColor = true
skipBtn.ZIndex = 8  -- above the pointer/ring/caption
local okSkipFont = pcall(function()
	skipBtn.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
end)
if not okSkipFont then skipBtn.Font = Enum.Font.FredokaOne end
skipBtn.Visible = false
skipBtn.Parent = gui
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 10)
local skipPad = Instance.new("UIPadding", skipBtn)
skipPad.PaddingLeft = UDim.new(0, 10); skipPad.PaddingRight = UDim.new(0, 10)
skipPad.PaddingTop = UDim.new(0, 6); skipPad.PaddingBottom = UDim.new(0, 6)
local skipStroke = Instance.new("UIStroke", skipBtn)
skipStroke.Color = Color3.fromRGB(235, 70, 70); skipStroke.Thickness = 2
local skipSizeConstraint = Instance.new("UITextSizeConstraint", skipBtn)
skipSizeConstraint.MaxTextSize = 18; skipSizeConstraint.MinTextSize = 8
-- mobile: pin to the top-right corner and shrink it so it doesn't dominate the smaller screen.
-- (PC keeps the top-center placement set above.)
if IS_MOBILE then
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Position = UDim2.new(1, -12, 0, 2)
	skipBtn.Size = UDim2.fromOffset(120, 34)
end

-- ===== resolving the real UI elements =====
-- The inventory button now lives in the consolidated Hud (Hud.LeftButtons.MainButtons.InventoryButton).
local function guiVisibleInTree(obj)
	local cur = obj
	while cur and cur ~= pg do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return true
end
local function findInventoryButton()
	local hud = pg:FindFirstChild("Hud")
	local left = hud and hud:FindFirstChild("LeftButtons")
	if not left then return nil end
	local button = left:FindFirstChild("InventoryButton", true)
	if button and guiVisibleInTree(button) then
		return button
	end
	return nil
end
local function findInventoryGui()
	return pg:FindFirstChild("Inventory")
end
local function inventoryGrid()
	local inv = findInventoryGui()
	if not inv then return nil end
	-- new flat structure: HolderFrame.Inventory.Inventory.ScrollingFrame
	local holder = inv:FindFirstChild("HolderFrame")
	local outer = holder and holder:FindFirstChild("Inventory")
	local panel = outer and outer:FindFirstChild("Inventory")
	return panel and panel:FindFirstChild("ScrollingFrame")
end
local function selectKnifeInventoryTab()
	local inv = findInventoryGui()
	local event = inv and inv:FindFirstChild("SelectInventoryTab")
	if event and event:IsA("BindableEvent") then
		event:Fire("knives")
		return
	end
	local holder = inv and inv:FindFirstChild("HolderFrame")
	local outer = holder and holder:FindFirstChild("Inventory")
	local buttons = outer and outer:FindFirstChild("Buttons")
	local knives = buttons and buttons:FindFirstChild("Knives")
	if knives and knives:IsA("GuiButton") then
		knives:Activate()
	end
end
local function equipButton()
	local inv = findInventoryGui()
	if not inv then return nil end
	return inv:FindFirstChild("Equip", true)
end

-- the cell name label text for a rendered grid cell (KnifeName is a layered TextLabel)
local function cellName(cell)
	local nameLbl = cell:FindFirstChild("KnifeName")
	return nameLbl and nameLbl.Text or nil
end
-- The inventory cells show the DISPLAY name, which strips a trailing " Knife" (so the catalog name
-- "Tralalero Knife" renders as "Tralalero" on the tile). The unbox payload gives the full catalog
-- name, so we must strip the same suffix before comparing -- otherwise the won knife is never matched
-- and the pointer falls back to some other cell. Mirrors KnifeSkinManager.displayName's strip.
local function displayName(name)
	if type(name) ~= "string" then return tostring(name) end
	local stripped = name:gsub("%s+[Kk]nife%s*$", "")
	if stripped == "" then return name end
	return stripped
end
-- is this the synthetic Default knife cell? (always present, always equipped for a new player, and
-- never a valid tutorial target -- the player can't "unbox" or need to equip the Default).
local function isDefaultCell(cell)
	return cellName(cell) == "Default"
end
-- is this cell currently equipped? (its Equipped tag is visible)
local function isEquippedCell(cell)
	local eq = cell:FindFirstChild("Equipped")
	return eq ~= nil and eq.Visible == true
end
-- find a rendered grid cell whose name matches the unboxed knife (prefer an UN-equipped one so the
-- tutorial points at a knife the player still needs to equip; falls back to any match). Never matches
-- the Default cell.
local function findKnifeCell(wantName)
	local grid = inventoryGrid()
	if not grid then return nil end
	local want = displayName(wantName)  -- compare against the cell's DISPLAY name (" Knife" stripped)
	local fallback = nil
	for _, c in ipairs(grid:GetChildren()) do
		if c.Name == "Cell" and not isDefaultCell(c) and cellName(c) == want then
			fallback = fallback or c
			if not isEquippedCell(c) then return c end  -- prefer a not-yet-equipped copy
		end
	end
	return fallback
end

-- Fallback target when the won knife's cell can't be matched by name: the first NON-Default,
-- NON-equipped cell -- i.e. an actual skin the player still needs to select + equip. The Default is
-- always equipped and is never a valid target, so it's skipped entirely. We also skip the currently
-- equipped skin (no point telling the player to equip what's already on). Order of preference:
--   1) first un-equipped, non-Default cell  (the normal case: their new knife)
--   2) first non-Default cell of any kind   (everything they own is somehow equipped -- unlikely)
--   3) nil                                   (only the Default exists -- nothing to point at)
local function firstSelectableCell()
	local grid = inventoryGrid()
	if not grid then return nil end
	local nonDefaultFallback = nil
	for _, c in ipairs(grid:GetChildren()) do
		if c.Name == "Cell" and not isDefaultCell(c) then
			nonDefaultFallback = nonDefaultFallback or c
			if not isEquippedCell(c) then return c end
		end
	end
	return nonDefaultFallback
end
-- Resolver for the SELECT step: prefer the won knife's cell; if it isn't found, point at the first
-- selectable (non-Default, un-equipped) cell so the guidance never stalls AND never points at the
-- Default knife. (The advance condition is still "any cell selected", so this only affects where the
-- pointer sits, not when the step completes.)
local function resolveSelectTarget(wantName)
	return findKnifeCell(wantName) or firstSelectableCell()
end
-- ===== generalized progress checks =====
-- The tutorial POINTS at the unboxed knife as the suggested choice, but it must not DEADLOCK if the
-- player selects/equips a different knife. So the advance conditions below are generalized: they
-- succeed when ANY knife is selected / equipped, not only the specific unboxed one. (The pointer still
-- guides the player toward their new knife; this just removes the trap where selecting knife Y after
-- knife X left the "equip" step waiting forever for X, with no on-screen way to recover.)

-- is ANY grid cell currently selected (gold border)?
local function anyCellSelected()
	local grid = inventoryGrid()
	if not grid then return false end
	for _, c in ipairs(grid:GetChildren()) do
		if c.Name == "Cell" then
			local stroke = c:FindFirstChildOfClass("UIStroke")
			if stroke and stroke.Transparency < 0.5 and colorsClose(stroke.Color, GOLD) then return true end
		end
	end
	return false
end

-- is ANY grid cell currently equipped (its Equipped label visible)? This is the generalized
-- completion signal for the equip step: equipping any knife (the unboxed one OR another) finishes it.
local function anyCellEquipped()
	local grid = inventoryGrid()
	if not grid then return false end
	for _, c in ipairs(grid:GetChildren()) do
		if c.Name == "Cell" then
			local eq = c:FindFirstChild("Equipped")
			if eq and eq.Visible then return true end
		end
	end
	return false
end

-- Identity of whatever cell is currently equipped, so we can detect a CHANGE (the player equipping a
-- different knife). A new player starts with the Default knife equipped, so "something is equipped"
-- is true from the start — we must instead watch for the equipped item to CHANGE to know the player
-- actually performed an equip. We key on the cell's KnifeName text (the Default cell shows "Default").
local function equippedCellKey()
	local grid = inventoryGrid()
	if not grid then return nil end
	for _, c in ipairs(grid:GetChildren()) do
		if c.Name == "Cell" then
			local eq = c:FindFirstChild("Equipped")
			if eq and eq.Visible then return cellName(c) or "?" end
		end
	end
	return nil  -- nothing equipped
end

-- ===== step engine =====
local running = false
local markedDone = false
local pendingWonName = nil
local eligibilityKnown = false
local alreadySeen = true  -- fail-safe: if the server never answers, don't nag

-- hide unrelated chrome so it can't overlap the pointer/caption (we keep BottomHUD + Inventory)
local HIDE_DURING_TUTORIAL = { "Shop", "Settings", "SeekerQueueGui", "CratesShop", "PopupGui" }
local hiddenGuis = {}
local function hideUnrelatedUI()
	hiddenGuis = {}
	for _, name in ipairs(HIDE_DURING_TUTORIAL) do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			hiddenGuis[g] = g.Enabled
			g.Enabled = false
		end
	end
end
local function restoreUnrelatedUI()
	for g, wasEnabled in pairs(hiddenGuis) do
		if g and g.Parent then g.Enabled = wasEnabled end
	end
	hiddenGuis = {}
end

-- raise the GUIs the tutorial points at above the dim so they aren't greyed out. The HUD is now the
-- consolidated Hud (the inventory button lives inside it), plus the Inventory panel itself.
local RAISE_TARGET_GUIS = { "Hud", "Inventory" }
local RAISED_ORDER = 260
local raisedGuis = {}
local function raiseTargetGuis()
	raisedGuis = {}
	for _, name in ipairs(RAISE_TARGET_GUIS) do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") then
			raisedGuis[g] = g.DisplayOrder
			g.DisplayOrder = RAISED_ORDER
		end
	end
end
local function restoreTargetGuis()
	for g, prevOrder in pairs(raisedGuis) do
		if g and g.Parent then g.DisplayOrder = prevOrder end
	end
	raisedGuis = {}
end

local function finish(markServer)
	running = false
	setTutorialActive(false)  -- release the shared lock (lets a deferred hider tutorial proceed)
	hidePointerAll()
	restoreUnrelatedUI()
	restoreTargetGuis()
	captionAnchorTarget = nil
	captionBelow = false
	skipBtn.Visible = false
	gui.Enabled = false
	dimGui.Enabled = false
	if markServer and not markedDone and not FORCE_EVERY_UNBOX then
		markedDone = true
		alreadySeen = true
		KnifeTutorialDone:FireServer()
	end
end

-- Skip = end the tutorial now AND mark it completed (counts as seen; never shows again).
local function skipTutorial()
	if not running then return end
	finish(true)
end
skipBtn.MouseButton1Click:Connect(skipTutorial)

-- generic step: point at a (possibly not-yet-existing) GuiObject, wait until satisfied() is true.
-- opts.captionAbove (bool): park the caption ABOVE the target instead of beside the pointer, so a wide
--   caption can't cover the very button the player must tap (used for EQUIP on mobile).
-- opts.requiresInventory (bool): this step only makes sense while the Inventory panel is open. If the
--   player CLOSES the inventory mid-step (e.g. taps its X, or a round transition closes it), there's
--   nothing left to point at and no way to advance -- so we abort the whole tutorial cleanly (marking
--   it seen) instead of leaving the pointer lingering on a panel that's gone. Returns false + sets a
--   flag the walkthrough reads to know it should finish(true) rather than silently stop.
local abortedByClose = false
local function inventoryOpen()
	local inv = findInventoryGui()
	return inv ~= nil and inv.Enabled == true
end
local function runStep(opts)
	caption.Text = opts.text
	local target = opts.resolve()
	local waited = 0
	while running and not target and waited < 6 do
		task.wait(0.1); waited += 0.1
		target = opts.resolve()
	end
	if not running then captionAnchorTarget = nil; captionBelow = false; return false end
	if target then pointAt(target, opts.side) else hidePointerAll() end
	-- set the anchored caption placement for this step (cleared when the step ends). captionBelow puts
	-- it under the target+pointer; captionAbove puts it above. Both are cleared on exit.
	captionBelow = opts.captionBelow or false
	captionAnchorTarget = ((opts.captionAbove or opts.captionBelow) and target) or nil
	while running do
		if opts.satisfied() then captionAnchorTarget = nil; captionBelow = false; return true end
		-- abort if this step needs the inventory open and the player closed it. The inventory is now
		-- available during a round too, so a mid-step close is always a deliberate user close -> mark seen.
		if opts.requiresInventory and not inventoryOpen() then
			captionAnchorTarget = nil
			captionBelow = false
			hidePointerAll()
			abortedByClose = true
			return false
		end
		local t = opts.resolve()
		if t and t ~= target then
			target = t; pointAt(target, opts.side)
			if opts.captionAbove or opts.captionBelow then captionAnchorTarget = target end
		elseif not t then
			-- target vanished (but inventory may still be open mid-render): hide the stale pointer so it
			-- doesn't linger on nothing; it'll re-point when resolve() returns a target again.
			hidePointerAll()
		end
		task.wait(0.05)
	end
	captionAnchorTarget = nil
	captionBelow = false
	return false
end

local function runWalkthrough(wonName)
	if running then return end
	-- Final guard against a simultaneous start: if the other (hider) tutorial just claimed the shared
	-- lock in the same instant, defer instead of dropping -- this tutorial is event-driven and can't
	-- retry on its own, so we wait for the lock to clear and then run (rather than silently returning).
	if anotherTutorialActive() then
		task.spawn(function()
			waitForNoTutorial()
			if not running and not anotherTutorialActive() then runWalkthrough(wonName) end
		end)
		return
	end
	running = true
	pendingWonName = nil
	setTutorialActive(true)  -- claim the shared lock so the hider tutorial defers until we finish
	markedDone = false
	abortedByClose = false
	hideUnrelatedUI()
	raiseTargetGuis()
	dimGui.Enabled = true
	gui.Enabled = true
	skipBtn.Visible = true  -- always-available exit for the whole walkthrough

	task.spawn(function()
		-- STEP 1: open the inventory
		local ok = runStep({
			text = "Open your Inventory to see your knives",
			side = "right",  -- inventory button is on the LEFT HUD: hand sits to its right, pointing left
			resolve = findInventoryButton,
			satisfied = function()
				local inv = findInventoryGui()
				return inv ~= nil and inv.Enabled == true
			end,
		})
		if not running or not ok then return end
		selectKnifeInventoryTab()
		task.wait(0.15)

		-- STEP 2: select a knife. The pointer guides them to their NEW knife (findKnifeCell points at
		-- the unboxed one, preferring an un-equipped copy), but the step ADVANCES on selecting ANY knife
		-- so the player can't get stuck if they tap a different cell.
		ok = runStep({
			text = "Tap your new " .. displayName(wonName or "knife") .. " to select it",
			side = "bottom",  -- hand sits UNDER the cell, pointing up at it
			captionBelow = true,  -- caption goes under the pointer (first-timers have no cells below, so overlap is fine)
			requiresInventory = true,  -- if they close the inventory here, abort cleanly
			resolve = function() return resolveSelectTarget(wonName) end,
			satisfied = function() return anyCellSelected() end,
		})
		if abortedByClose then finish(true); return end
		if not running or not ok then return end

		-- STEP 3: tap Equip. We point at the Equip button, but completion is GENERALIZED: the step is
		-- done once the EQUIPPED knife CHANGES from whatever was equipped when the step began. This is the
		-- core fix and it avoids two traps: (1) a new player starts with the Default knife equipped, so a
		-- plain "is anything equipped?" check would pass instantly — we instead watch for a change; and
		-- (2) if the player selected knife X (passing step 2) then selected knife Y instead of equipping,
		-- the old code waited forever for X specifically. Now equipping whichever knife they chose
		-- (X or Y) changes the equipped item and satisfies the step, matching what they actually did.
		local equippedAtStart = equippedCellKey()
		ok = runStep({
			text = "Tap EQUIP to use it as a Seeker",
			side = "bottom",  -- hand sits UNDER the Equip button, pointing up at it
			captionBelow = true,  -- caption goes under the pointer so it never covers the Equip button (esp. mobile)
			requiresInventory = true,  -- if they close the inventory here, abort cleanly
			resolve = equipButton,
			satisfied = function()
				-- done when the equipped knife differs from what was equipped when this step started
				return equippedCellKey() ~= equippedAtStart
			end,
		})
		if abortedByClose then finish(true); return end
		if not running or not ok then return end

		-- DONE: congratulate briefly, then close + persist (never repeats)
		caption.Text = "Equipped! You'll carry this knife as the Seeker."
		hidePointerAll()
		task.wait(2.5)
		finish(true)
	end)
end

-- ===== eligibility + trigger =====
local asked = false

local function tryRunPending()
	if running or anotherTutorialActive() or not pendingWonName then
		return
	end
	if alreadySeen and not FORCE_EVERY_UNBOX then
		pendingWonName = nil
		return
	end
	local wonName = pendingWonName
	task.spawn(function()
		waitForNoTutorial()
		if running or anotherTutorialActive() then
			return
		end
		task.wait(0.35)
		if not running and not anotherTutorialActive() then
			runWalkthrough(wonName)
		end
	end)
end

InRound.OnClientEvent:Connect(function()
	-- Round state no longer gates this tutorial (the Inventory button is available mid-round), so we
	-- don't tear it down when a round starts. Re-check in case a pending unbox can now run (e.g. it
	-- had been deferred behind the hider tutorial and conditions have since changed).
	tryRunPending()
end)

KnifeTutorialState.OnClientEvent:Connect(function(seen)
	alreadySeen = seen and true or false
	eligibilityKnown = true
end)

KnifeUnboxedLocal.Event:Connect(function(info)
	if running then return end
	local wonName = (type(info) == "table" and info.name) or "knife"
	-- ask the server once whether we've already done it
	if not asked then
		asked = true
		KnifeTutorialQuery:FireServer()
	end
	pendingWonName = wonName
	task.spawn(function()
		local waited = 0
		while not eligibilityKnown and waited < 4 do task.wait(0.1); waited += 0.1 end
		if alreadySeen and not FORCE_EVERY_UNBOX then return end
		-- MUTUAL EXCLUSION: if the hider (paint) tutorial is on screen, defer until it finishes so the
		-- two never overlap. (Round state no longer matters -- the Inventory button is available mid-round.)
		if anotherTutorialActive() then
			waitForNoTutorial()
		end
		tryRunPending()
	end)
end)
