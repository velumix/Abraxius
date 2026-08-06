-- HiderTutorialClient: an interactive, pointer-driven walkthrough that runs the FIRST time a player
-- is assigned the Hider role. It dims the screen, draws an animated pointer + instruction caption at
-- the real UI elements, and advances only when the player performs each real action:
--   1) tap the Paint button        -> advances when the color picker opens
--   2) pick the GREEN preset color  -> advances when the green swatch is chosen
--   3) paint a body part            -> advances when one of their parts changes color
--   4) tap the Positions (Pose) btn -> advances when the pose menu opens
--   5) choose a position            -> advances when a pose is selected; then it finishes
--
-- It never blocks the real buttons (it points AT them and lets the player tap the actual UI). The
-- server (HiderTutorialManager) gates it to once-per-player-ever via a ProfileStore flag.
--
-- Design notes:
--  * Fully self-contained: builds its own overlay ScreenGui; does NOT modify PaintClient/PoseClient.
--  * Advances on observable state (panel Visible, body Color changes, pose image highlight) so it
--    stays in sync no matter how the player triggers the action.
--  * If the player leaves the round / stops being a Hider mid-tutorial, it quietly closes and will
--    resume from the start the next time they're a Hider (until they complete it once).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))
-- is a gamepad the active input right now? (PreferredInput is canonical; fall back for old clients)
local function gamepadActive()
	local ok, pref = pcall(function() return UserInputService.PreferredInput end)
	if ok and pref ~= nil then return pref == Enum.PreferredInput.Gamepad end
	local lit = UserInputService:GetLastInputType()
	return lit == Enum.UserInputType.Gamepad1 or lit == Enum.UserInputType.Gamepad2
		or lit == Enum.UserInputType.Gamepad3 or lit == Enum.UserInputType.Gamepad4
end

-- ===== cross-tutorial mutual exclusion =====
-- The hider (paint) tutorial and the knife-equip tutorial are separate LocalScripts that can both want
-- to run close together (e.g. a first-time player wins as Seeker -> ranks up -> unboxes their first
-- knife -> next round they're a Hider). To stop the two overlapping, both scripts share a single flag:
-- the player attribute "TutorialActive", set true while EITHER walkthrough is on screen. Before starting,
-- each waits for the other to clear it; on finish, each clears it. (An attribute is the simplest shared
-- channel two LocalScripts both see.)
local TUTORIAL_ACTIVE_ATTR = "TutorialActive"
local function anotherTutorialActive()
	return player:GetAttribute(TUTORIAL_ACTIVE_ATTR) == true
end
local function setTutorialActive(on)
	player:SetAttribute(TUTORIAL_ACTIVE_ATTR, on and true or false)
end
-- Yield until no tutorial is active (or a timeout, as a safety valve so we can never hang forever if
-- the other script errors without clearing the flag). Returns true if it's clear to proceed.
local function waitForNoTutorial(timeout)
	local waited = 0
	while anotherTutorialActive() and waited < (timeout or 60) do
		task.wait(0.2); waited += 0.2
	end
	return not anotherTutorialActive()
end

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local StateChanged = Remotes:WaitForChild("StateChanged")
local HiderTutorialQuery = Remotes:WaitForChild("HiderTutorialQuery")
local HiderTutorialState = Remotes:WaitForChild("HiderTutorialState")
local HiderTutorialDone = Remotes:WaitForChild("HiderTutorialDone")

-- ===== TESTING OVERRIDE =====
-- Keep this false for normal testing so Studio follows the same once-per-player ProfileStore gate as
-- production. Temporarily set true only when intentionally rehearsing the walkthrough repeatedly.
local FORCE_EVERY_ROUND = false

-- the green preset color (matches the foliage-green swatch in PaintClient.PRESETS exactly so we can
-- find that swatch). Updated when the presets were reworked to the map's most common colors.
local GREEN = Color3.fromRGB(38, 115, 44)
local function colorsClose(a, b)
	return math.abs(a.R-b.R) < 0.02 and math.abs(a.G-b.G) < 0.02 and math.abs(a.B-b.B) < 0.02
end

-- ===== overlay GUIs =====
-- Two layers so the tutorial's TARGET buttons can sit BETWEEN them:
--   dimGui  (DisplayOrder 250) -> the dark dimmer, BELOW the raised paint/pose GUIs (260)
--   topGui  (DisplayOrder 270) -> the pointer/ring/caption, ABOVE the raised GUIs so they read clearly
-- DisplayOrder is per-ScreenGui, so a single GUI can't be both under the dim and over the buttons;
-- splitting the dimmer and the markers into two layers lets the targets render in between.
-- Both keep IgnoreGuiInset = false so they share the Paint/Pose GUIs' coordinate space (accurate rings).
local dimGui = Instance.new("ScreenGui")
dimGui.Name = "HiderTutorialDimGui"
dimGui.ResetOnSpawn = false
dimGui.IgnoreGuiInset = false
dimGui.DisplayOrder = 250
dimGui.Enabled = false
dimGui.Parent = pg

local gui = Instance.new("ScreenGui")  -- the marker layer (pointer/ring/caption)
gui.Name = "HiderTutorialGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 270
gui.Enabled = false
gui.Parent = pg

-- A soft dim over the whole screen to focus attention. It does NOT sink input (Active=false,
-- and we never cover the real buttons with an input-catching frame) so the player can still tap
-- the actual Paint/Pose UI underneath. Oversized + offset up to still cover the topbar inset area
-- (since this GUI respects the inset, a 1,1 frame would leave the topbar strip undimmed).
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

-- An animated arrow/hand pointer that sits next to the target element and bobs toward it.
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

-- A ring that highlights the target element's bounds.
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
ringStroke.Color = Color3.fromRGB(235, 70, 70)  -- red indicator border
ringStroke.Thickness = 3
ringStroke.Transparency = 0

-- Instruction caption. It DYNAMICALLY follows the pointer (sits at the pointer's top-right) so it
-- never overlaps the highlighted target/character. Anchored at its bottom-left corner so positioning
-- it relative to the pointer's top-right reads naturally; clamped on-screen each frame below.
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
capStroke.Color = Color3.fromRGB(235, 70, 70); capStroke.Thickness = 2  -- red to match the indicator
local capSizeConstraint = Instance.new("UITextSizeConstraint", caption)
capSizeConstraint.MaxTextSize = 20; capSizeConstraint.MinTextSize = 8
-- keep the caption from running off small screens
local capScale = Instance.new("UIScale", caption)
-- mobile = touch-only device (no mouse). On mobile we shrink the caption an extra 20% so it doesn't
-- dominate the smaller screen (per design request).
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local MOBILE_CAPTION_MULT = IS_MOBILE and 0.8 or 1
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

-- ===== caption follows the pointer (top-right of it), clamped on-screen =====
-- A single render loop keeps the caption pinned to the pointer's top-right whenever the pointer is
-- visible, so it tracks the bob/target movement and never sits on top of the highlighted element.
-- If the pointer is hidden (e.g. character off-screen) the caption falls back to top-center.
local CAP_GAP = 14  -- px gap between the pointer and the caption
local captionConn = RunService.RenderStepped:Connect(function()
	if not gui.Enabled then return end
	local cam = workspace.CurrentCamera
	local vpX = cam and cam.ViewportSize.X or 1280
	local vpY = cam and cam.ViewportSize.Y or 720
	local scaledW = caption.AbsoluteSize.X  -- already includes the UIScale
	local scaledH = caption.AbsoluteSize.Y
	if pointer.Visible then
		local pp = pointer.AbsolutePosition
		local ps = pointer.AbsoluteSize
		-- desired: caption's bottom-left just to the top-right of the pointer
		local x = pp.X + ps.X + CAP_GAP
		local y = pp.Y  -- AnchorPoint (0,1): this is the caption's BOTTOM edge -> sits above this y
		-- clamp so the whole caption stays on screen
		x = math.clamp(x, 8, math.max(8, vpX - scaledW - 8))
		y = math.clamp(y, scaledH + 8, vpY - 8)
		caption.Position = UDim2.fromOffset(x, y)
	else
		-- no pointer on screen: park the caption near the top-center
		caption.Position = UDim2.fromOffset(math.floor((vpX - scaledW) / 2), scaledH + 24)
	end
end)

-- ===== pointer/ring placement + bob animation =====
local bobConn = nil
local function stopBob()
	if bobConn then bobConn:Disconnect(); bobConn = nil end
end

-- forward declarations so pointAt (below) can stop the world-pointer; the bodies are defined later.
local worldConn = nil
local function stopWorld()
	if worldConn then worldConn:Disconnect(); worldConn = nil end
end

-- point at a GuiObject: place the ring over its rendered bounds and the bobbing hand just outside it.
local function pointAt(target, side)
	stopBob()
	stopWorld()
	if not target or not target:IsA("GuiObject") then
		pointer.Visible = false; ring.Visible = false
		return
	end
	side = side or "left"  -- which side of the target the hand sits on
	local function reposition()
		local ap = target.AbsolutePosition
		local asz = target.AbsoluteSize
		if asz.X <= 0 or asz.Y <= 0 then ring.Visible = false; pointer.Visible = false; return end
		local cx, cy = ap.X + asz.X/2, ap.Y + asz.Y/2
		ring.Visible = true
		ring.Position = UDim2.fromOffset(cx, cy)
		ring.Size = UDim2.fromOffset(asz.X + 18, asz.Y + 18)
		pointer.Visible = true
		-- base position of the hand on the chosen side of the target
		if side == "left" then
			pointer.Position = UDim2.fromOffset(ap.X - 36, cy)
			pointer.Rotation = 0
		elseif side == "right" then
			pointer.Position = UDim2.fromOffset(ap.X + asz.X + 36, cy)
			pointer.Rotation = 180
		elseif side == "top" then
			pointer.Position = UDim2.fromOffset(cx, ap.Y - 36)
			pointer.Rotation = 90
		else -- bottom
			pointer.Position = UDim2.fromOffset(cx, ap.Y + asz.Y + 36)
			pointer.Rotation = -90
		end
	end
	reposition()
	-- bob the hand toward the target + pulse the ring; also re-read bounds each frame so the pointer
	-- tracks the element if it moves (mobile rescale, layout shifts).
	local t0 = os.clock()
	bobConn = RunService.RenderStepped:Connect(function()
		reposition()
		if not pointer.Visible then return end
		local phase = math.sin((os.clock() - t0) * 6) * 6  -- +/-6px bob
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

local function hidePointer()
	stopBob()
	pointer.Visible = false
	ring.Visible = false
end

-- Point the hand at a WORLD position (used to point at the player's own character for the paint
-- step). Projects the world point to screen space each frame and bobs the hand just above it. The
-- ring is sized to roughly frame the character. Because this overlay respects the GUI inset, we
-- subtract the inset from the viewport point so the hand lands exactly over the character on screen.
local function pointAtWorld(getWorldPos)
	stopBob()
	stopWorld()
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	worldConn = RunService.RenderStepped:Connect(function()
		cam = workspace.CurrentCamera
		local wp = getWorldPos()
		if not cam or not wp then ring.Visible = false; pointer.Visible = false; return end
		local sp, onScreen = cam:WorldToViewportPoint(wp)
		local inset = GuiService:GetGuiInset()
		local x, y = sp.X - inset.X, sp.Y - inset.Y
		if not onScreen or sp.Z <= 0 then
			-- character is off-screen / behind the camera: hide the ring but keep the caption guiding
			ring.Visible = false; pointer.Visible = false
			return
		end
		ring.Visible = true
		ring.Position = UDim2.fromOffset(x, y)
		ring.Size = UDim2.fromOffset(150, 190)  -- roughly frames an R6 body at typical distance
		pointer.Visible = true
		local bob = math.sin((os.clock() - t0) * 6) * 6
		pointer.Rotation = 90  -- 👉 rotated to point DOWNWARD at the body
		pointer.Position = UDim2.fromOffset(x, y - 120 - bob)
		ringStroke.Transparency = 0.3 + 0.3 * (math.sin((os.clock()-t0) * 4) * 0.5 + 0.5)
	end)
end

local function hidePointerAll()
	stopBob()
	stopWorld()
	pointer.Visible = false
	ring.Visible = false
end

-- ===== Skip button =====
-- An always-available exit so the player is never trapped if they're confused, change their mind, or
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

-- ===== resolving the real UI elements (wait for them; they stream in) =====
-- The Paint, Pose and Lock buttons now live in the consolidated Hud bottom row (Hud.BottomButtons);
-- the picker panel (PaintGui) and the pose MENU (PoseButtonGui.Pose) are still their own things.
local function bottomSlots()
	local g = pg:FindFirstChild("Hud")
	return g and g:FindFirstChild("BottomButtons")
end
local function findPaintButton()
	local slots = bottomSlots()
	return slots and slots:FindFirstChild("PaintButton", true)
end
local function findPicker()
	local g = pg:FindFirstChild("PaintGui")
	return g and g:FindFirstChild("Picker")
end
local function findGreenPreset()
	local picker = findPicker()
	local presets = picker and picker:FindFirstChild("Presets")
	if not presets then return nil end
	for _, c in ipairs(presets:GetChildren()) do
		if c:IsA("GuiButton") and colorsClose(c.BackgroundColor3, GREEN) then
			return c
		end
	end
	return nil
end
local function findPoseButton()
	local slots = bottomSlots()
	return slots and slots:FindFirstChild("PoseButton", true)
end
local function findPoseMenu()
	local g = pg:FindFirstChild("PoseButtonGui")
	return g and g:FindFirstChild("Pose")
end

-- Close the paint palette if it's open. After the paint step the tutorial moves the player to the Pose
-- menu, so the palette should be dismissed first. On a CONTROLLER this is essential: while the palette
-- is open the gamepad virtual cursor is on, which (a) suppresses the Pose keybind in GamepadGameplayClient
-- (so D-pad Up does nothing) and (b) means opening Pose via the cursor bypasses the proper pose-nav setup,
-- producing a half-rendered menu. Closing the palette turns the cursor off so the Pose keybind works and
-- the menu opens correctly. We fire PaintClient's own GamepadPaintControl "close" bridge (it self-gates,
-- updates server paint-mode state, and flips Picker.Visible, which the cursor manager reacts to); we fall
-- back to hiding the picker directly if the bridge isn't present.
local function closePaintPalette()
	local paintGui = pg:FindFirstChild("PaintGui")
	if not paintGui then return end
	local picker = paintGui:FindFirstChild("Picker")
	if not (picker and picker.Visible) then return end
	local bridge = paintGui:FindFirstChild("GamepadPaintControl")
	if bridge and bridge:IsA("BindableEvent") then
		bridge:Fire("close")
	else
		picker.Visible = false
	end
end
local function findAPoseOption()
	-- point at "Crawl" specifically; fall back to any non-Default pose option if it's missing
	local menu = findPoseMenu()
	local frame = menu and menu:FindFirstChild("PoseButtons")
	if not frame then return nil end
	local preferred = frame:FindFirstChild("Crawl")
	if preferred and preferred:IsA("GuiButton") then return preferred end
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiButton") and c.Name ~= "Default" then return c end
	end
	return nil
end

-- ===== body-paint detection =====
-- snapshot the player's paintable body part colors; returns a function that reports whether any
-- changed since the snapshot (i.e. the player painted a part).
local function snapshotBodyColors()
	local snap = {}
	local char = player.Character
	if char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				snap[p] = p.Color
			end
		end
	end
	return function()
		local c = player.Character
		if not c then return false end
		for p, col in pairs(snap) do
			if p and p.Parent and not colorsClose(p.Color, col) then
				return true
			end
		end
		return false
	end
end

local PAINT_COVERAGE_FRACTION = 0.6
local function paintableBodyParts()
	local list = {}
	local c = player.Character
	if c then
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart")
				and p.Name ~= "HumanoidRootPart"
				and p.Name ~= "CollisionPart"
				and p.Name ~= "Head" then
				list[#list + 1] = p
			end
		end
	end
	return list
end

local function snapshotRequiredParts()
	local baseline = {}
	for _, p in ipairs(paintableBodyParts()) do
		baseline[p] = p.Color
	end
	return function()
		local parts = paintableBodyParts()
		if #parts == 0 then return false end
		local painted = 0
		for _, p in ipairs(parts) do
			local orig = baseline[p]
			if orig == nil then
				baseline[p] = p.Color
			elseif not colorsClose(p.Color, orig) then
				painted += 1
			end
		end
		return painted >= math.max(1, math.ceil(#parts * PAINT_COVERAGE_FRACTION))
	end
end

-- ===== step engine =====
local running = false
local cancelStep = nil  -- function to tear down the current step's listeners

local function clearStep()
	if cancelStep then pcall(cancelStep); cancelStep = nil end
	hidePointerAll()
end

local markedDone = false
-- Eligibility state (declared here so finish() can mark the tutorial as seen locally on completion).
-- alreadySeen defaults to true as a fail-safe: if the server never answers, we don't nag the player.
local eligibilityKnown = false
local alreadySeen = true

-- ===== hide unrelated UI during the tutorial (issue #4) =====
-- We hide chrome that has nothing to do with the walkthrough so it can't overlap the pointer/caption,
-- then restore exactly what we hid. The HUD is now ONE shared GUI (Hud), and the buttons the tutorial
-- points at (Paint/Pose/Lock/Taunt) live in its `BottomButtons` frame, so we can't just disable the
-- whole GUI. Instead we hide the non-target HUD frames at the FRAME level (LeftButtons = shop/
-- inventory/etc., Currency = money, SeekerChance), leaving `BottomButtons` visible, plus the
-- standalone panel GUIs. We do NOT touch the picker (PaintGui), the pose menu (PoseButtonGui), the
-- timer, role/fade overlays, or our own.
local HIDE_GUIS_DURING_TUTORIAL = { "Shop", "Settings", "SeekerQueueGui" }
local HIDE_FRAMES_DURING_TUTORIAL = { "LeftButtons", "RegularCurrency", "EventCurrency", "SeekerChance", "ColoringBookButton" }  -- children of Hud
local hiddenGuis = {}    -- [ScreenGui] = previousEnabled
local hiddenFrames = {}  -- [GuiObject] = previousVisible
local function hudFrame()
	-- the new Hud's frames are direct children of the Hud ScreenGui (no inner HUDFrame wrapper)
	return pg:FindFirstChild("Hud")
end
local function hideUnrelatedUI()
	hiddenGuis = {}
	hiddenFrames = {}
	for _, name in ipairs(HIDE_GUIS_DURING_TUTORIAL) do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			hiddenGuis[g] = g.Enabled
			g.Enabled = false
		end
	end
	local hud = hudFrame()
	if hud then
		for _, name in ipairs(HIDE_FRAMES_DURING_TUTORIAL) do
			local f = hud:FindFirstChild(name)
			if f and f.Visible then
				hiddenFrames[f] = f.Visible
				f.Visible = false
			end
		end
	end
end
local function restoreUnrelatedUI()
	for g, wasEnabled in pairs(hiddenGuis) do
		if g and g.Parent then g.Enabled = wasEnabled end
	end
	for f, wasVisible in pairs(hiddenFrames) do
		if f and f.Parent then f.Visible = wasVisible end
	end
	hiddenGuis = {}
	hiddenFrames = {}
end

-- ===== raise the tutorial's TARGET GUIs above the dim =====
-- The dim lives in our overlay (DisplayOrder 250). DisplayOrder is per-ScreenGui, so the paint/pose
-- GUIs (DisplayOrder ~9) would render UNDERNEATH the dim and look greyed out. While the tutorial
-- runs we bump the GUIs it points at to a DisplayOrder ABOVE the overlay so they sit on top of the
-- dim and read clearly, then restore their original DisplayOrder when the tutorial ends.
local RAISE_TARGET_GUIS = { "Hud", "PaintGui", "PoseButtonGui" }
local RAISED_ORDER = 260  -- just above the overlay's 250 so targets render over the dim
local raisedGuis = {}  -- [ScreenGui] = previousDisplayOrder
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
	setTutorialActive(false)  -- release the shared lock so the knife tutorial (if queued) can run
	clearStep()
	restoreUnrelatedUI()  -- bring back the chrome we hid
	restoreTargetGuis()   -- restore the target GUIs' DisplayOrder
	skipBtn.Visible = false
	gui.Enabled = false
	dimGui.Enabled = false
	if markServer and not markedDone and not FORCE_EVERY_ROUND then
		markedDone = true
		alreadySeen = true  -- remember locally for the rest of this session so it never repeats
		HiderTutorialDone:FireServer()
	end
end

-- Skip = end the tutorial now AND mark it completed (counts as seen; never shows again).
local function skipTutorial()
	if not running then return end
	finish(true)
end
skipBtn.MouseButton1Click:Connect(skipTutorial)

-- generic "wait for a target to exist, point at it, then wait for a condition" step.
-- text: caption; resolve: () -> GuiObject (the element to point at, may be nil until it streams in);
-- worldResolve: () -> Vector3 (optional; point the hand at a WORLD position instead of a GUI element);
-- side: which side the hand sits; satisfied: () -> bool advance condition; pollExtra: optional per-
-- frame hook. Returns when satisfied() is true (or the tutorial is cancelled).
-- opts.requiresPanel (optional): () -> bool. This step only makes sense while some panel is open (e.g.
--   the paint picker, or the pose menu). If the player CLOSES that panel mid-step (taps its X, picks
--   nothing, or a transition closes it), there's nothing left to point at and no way to advance -- so
--   we abort the whole tutorial cleanly (marking it seen via abortedByClose) instead of leaving the
--   pointer lingering on a panel that's gone. Mirrors the knife tutorial's requiresInventory fix.
local abortedByClose = false
local function runStep(opts)
	caption.Text = opts.text

	-- world-pointing step (e.g. point at the player's own character): no GUI to wait for.
	if opts.worldResolve then
		pointAtWorld(opts.worldResolve)
		while running do
			if opts.satisfied() then return true end
			if opts.pollExtra then opts.pollExtra() end
			task.wait(0.05)
		end
		return false
	end

	-- wait for the target element to resolve
	local target = opts.resolve()
	local waited = 0
	while running and not target and waited < 5 do
		task.wait(0.1); waited += 0.1
		target = opts.resolve()
	end
	if not running then return false end
	if target then pointAt(target, opts.side) else hidePointerAll() end

	-- now wait for the advance condition; keep re-resolving the target so the pointer can attach if
	-- the element appears/moves (e.g. the picker panel opening).
	while running do
		if opts.satisfied() then return true end
		-- abort if this step needs a panel open and the player closed it (e.g. closed the pose menu
		-- without choosing a pose) -- otherwise the pointer would linger on the gone panel.
		if opts.requiresPanel and not opts.requiresPanel() then
			hidePointerAll()
			abortedByClose = true
			return false
		end
		local t = opts.resolve()
		if t and t ~= target then
			target = t; pointAt(target, opts.side)
		elseif not t then
			-- target vanished (panel still opening/closing mid-render): hide the stale pointer so it
			-- doesn't linger on nothing; it'll re-point when resolve() returns a target again.
			hidePointerAll()
		end
		if opts.pollExtra then opts.pollExtra() end
		task.wait(0.05)
	end
	return false
end

local function runWalkthrough()
	if running then return end
	-- Final atomic guard against a simultaneous start: if the other tutorial already holds the shared
	-- lock, don't run now (no yield between this check and the claim below, so both can't pass).
	if anotherTutorialActive() then return end
	running = true
	setTutorialActive(true)  -- claim the shared lock so the knife tutorial defers until we finish
	markedDone = false
	abortedByClose = false
	hideUnrelatedUI()  -- clear unrelated chrome so it can't overlap the tutorial (issue #4)
	raiseTargetGuis()  -- lift paint/pose GUIs above the dim so they aren't greyed out
	dimGui.Enabled = true
	gui.Enabled = true
	skipBtn.Visible = true  -- always-available exit for the whole walkthrough

	local function __walk()
		-- STEP 1: open the paint picker
		local ok = runStep({
			text = "Tap the Paint button to open your colors",
			side = "top",  -- bottom-HUD button: point DOWN at it from above
			resolve = findPaintButton,
			satisfied = function()
				local picker = findPicker()
				return picker ~= nil and picker.Visible == true
			end,
		})
		if not running or not ok then return end

		-- STEP 2: pick the green preset
		ok = runStep({
			text = "Pick the GREEN color to blend with the map",
			-- Point from the LEFT (not "bottom"): the green swatch sits near the bottom of the picker, so a
			-- bottom-side pointer pushed the caption (which follows the pointer's top-right, clamped on-
			-- screen) DOWN onto the preset swatch row, covering the colors the player needs to tap. Pointing
			-- from the left puts the hand beside the swatch and the caption up-and-right of it, clear of the
			-- swatches — matching how the pose-option step (also side="left") already reads cleanly.
			side = "left",
			requiresPanel = function()  -- abort cleanly if the player closes the picker without picking
				local picker = findPicker()
				return picker ~= nil and picker.Visible == true
			end,
			resolve = findGreenPreset,
			satisfied = function()
				-- advance once the preview swatch shows green (the player chose it). The Preview frame
				-- under the picker reflects the current color.
				local picker = findPicker()
				local preview = picker and picker:FindFirstChild("Preview")
				return preview ~= nil and colorsClose(preview.BackgroundColor3, GREEN)
			end,
		})
		if abortedByClose then finish(true); return end
		if not running or not ok then return end

		-- STEP 3: paint the body (point the hand at the player's own character).
		-- The player should color their whole body to blend in, so we don't auto-advance the instant ONE
		-- part changes color. Instead we wait until EVERY required body part (Head excluded -- see
		-- snapshotRequiredParts) has been recolored, then advance + close the palette automatically. This
		-- needs no "press X when done" prompt: full coverage IS the done signal, which is cleaner and works
		-- the same on controller, PC, and mobile.
		local allPainted = snapshotRequiredParts()  -- true once EVERY required body part is recolored
		ok = runStep({
			text = "Color your whole body green to blend in!",
			worldResolve = function()
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				return hrp and hrp.Position or nil
			end,
			satisfied = function() return allPainted() end,
		})
		if not running or not ok then return end

		-- Done painting. Close the paint palette before moving to the Pose step. On a controller this turns
		-- the virtual cursor OFF so the Pose keybind works again and the pose menu opens correctly (see
		-- closePaintPalette). Give the cursor/keybind state a beat to settle before the next step.
		closePaintPalette()
		task.wait(0.15)
		if not running then return end

		-- STEP 4: open the positions (pose) menu
		ok = runStep({
			text = "Tap the Positions button to strike a pose",
			side = "top",  -- bottom-HUD button: point DOWN at it from above
			resolve = findPoseButton,
			satisfied = function()
				local menu = findPoseMenu()
				return menu ~= nil and menu.Visible == true
			end,
		})
		if not running or not ok then return end

		-- STEP 5: choose a position
		ok = runStep({
			text = "Choose the Crawl position to blend in",
			side = "left",
			requiresPanel = function()  -- abort cleanly if the player closes the pose menu without choosing
				local menu = findPoseMenu()
				return menu ~= nil and menu.Visible == true
			end,
			resolve = findAPoseOption,
			satisfied = function()
				-- advance once any non-Default pose option shows the green ACTIVE highlight image
				local menu = findPoseMenu()
				local frame = menu and menu:FindFirstChild("PoseButtons")
				if not frame then return false end
				for _, c in ipairs(frame:GetChildren()) do
					if c:IsA("ImageButton") and c.Name ~= "Default"
						and c.Image == "rbxassetid://134236090170398" then
						return true
					end
				end
				return false
			end,
		})
		if abortedByClose then finish(true); return end
		if not running or not ok then return end

		-- DONE: congratulate briefly, then close + persist
		caption.Text = "Nice! You're ready to hide. Good luck!"
		hidePointerAll()
		task.wait(2.5)
		finish(true)
	end
	task.spawn(function()
		local ok, err = pcall(__walk)
		if not ok then
			warn("[HiderTutorialClient] walkthrough errored; restoring HUD: " .. tostring(err))
		end
		if running then finish(false) end
	end)
end

-- ===== eligibility + trigger =====
-- Track role/round so we only run for a Hider in an active round, and stop if that changes.
-- NOTE: alreadySeen / eligibilityKnown are declared ABOVE finish() (which sets them on completion),
-- so they live here near the top of this section but are referenced by finish() too.
local myRole = nil
local inRound = false
local hidePhaseStarted = false  -- true once the PLAYABLE hide phase begins (screen un-blacked)
local asked = false

HiderTutorialState.OnClientEvent:Connect(function(seen)
	alreadySeen = seen and true or false
	eligibilityKnown = true
end)

local function maybeStart()
	if running then return end
	if not (inRound and myRole == "Hider") then return end
	-- Only run during the PLAYABLE hide phase (issue #1): the role reveal happens under a black
	-- screen first, and the tutorial must NOT appear over it. hidePhaseStarted is set when the
	-- server broadcasts the "hiders hiding" state (after the reveal fades out).
	if not hidePhaseStarted then return end
	-- ask the server once whether we've already done it
	if not asked then
		asked = true
		HiderTutorialQuery:FireServer()
	end
	-- wait briefly for the server's answer, then start if not seen and still a hider
	task.spawn(function()
		local waited = 0
		while not eligibilityKnown and waited < 4 do task.wait(0.1); waited += 0.1 end
		-- TESTING: when forced manually, ignore the "already seen" gate so it shows every hider round
		if alreadySeen and not FORCE_EVERY_ROUND then return end
		-- MUTUAL EXCLUSION: if the knife-equip tutorial is currently on screen, wait for it to finish
		-- before starting ours so the two never overlap. We're time-gated to the hide phase, so after
		-- waiting we re-check our conditions; if the hide phase has since ended (or we're no longer a
		-- hider), we simply don't run now -- it'll retry next hider round, which is fine.
		if anotherTutorialActive() then
			waitForNoTutorial()
		end
		if inRound and myRole == "Hider" and hidePhaseStarted and not running and not anotherTutorialActive() then
			runWalkthrough()
		end
	end)
end

-- Watch the round state. The playable hide phase is signalled by the "hiders hiding" note (the
-- earlier "role reveal" note is the under-black reveal, which we must skip). Once it begins we can
-- start the walkthrough.
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.state == "HIDE" and data.note == "hiders hiding" then
		hidePhaseStarted = true
		maybeStart()
	end
end)

RoleAnnounce.OnClientEvent:Connect(function(role)
	myRole = role
	if role == "Hider" then
		maybeStart()  -- will no-op until the playable hide phase begins
	else
		-- became seeker (or role cleared): abort any running tutorial without marking it done so it
		-- can run cleanly next time they're a hider.
		if running then finish(false) else restoreUnrelatedUI() restoreTargetGuis() end
	end
end)
InRound.OnClientEvent:Connect(function(active)
	inRound = active and true or false
	if not inRound then
		myRole = nil
		hidePhaseStarted = false  -- reset for next round
		if running then finish(false) else restoreUnrelatedUI() restoreTargetGuis() end  -- round ended: close (and always un-hide chrome)
		-- TESTING: reset the per-round ask so the tutorial can re-trigger next round when forced manually
		if FORCE_EVERY_ROUND then asked = false end
	else
		maybeStart()
	end
end)
