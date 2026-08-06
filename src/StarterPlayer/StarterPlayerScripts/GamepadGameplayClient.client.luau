--!nonstrict
-- GamepadGameplayClient (LocalScript, StarterPlayer.StarterPlayerScripts)
-- ============================================================================
-- In-round HIDER ability keybinds for a controller. Most fire the SAME function the matching on-screen
-- HUD button runs, via a small BindableEvent "bridge" in that button's own script -- so the controller
-- does EXACTLY what tapping the button does, instantly.
--
--   Triangle (Y)  -> Taunt   (TauntButtonClient.tryTaunt  via Hud/GamepadTauntControl)
--   D-pad Down    -> Lock     (PaintClient.toggleLock       via PaintGui/GamepadLockControl)
--   D-pad Right   -> Paint     (PaintClient.togglePaint      via PaintGui/GamepadPaintControl) + the
--                   virtual cursor turns on while the palette is open (point + Cross to paint).
--   D-pad Up      -> Pose      opens the pose menu in NATIVE selection-nav mode: the other hider
--                   keybinds turn OFF, the D-pad moves the selection between pose options, Cross applies
--                   the highlighted pose, and Circle (O / Back) closes the menu and restores the keybinds.
--   L1            -> Troll     opens the Troll panel (TrollUIClient). The panel is a registered cursor
--                   panel, so the virtual cursor turns on (point + Cross to buy) and B closes it.
--
-- SEEKER (in-round) reveal keybinds also live here, bound only while the player is a SEEKER in a round:
--   L1            -> Reveal One  (RevealUIClient bridge: prompts the Reveal One dev product)
--   L2            -> Reveal All  (RevealUIClient bridge: prompts the Reveal All dev product)
-- L1 is shared with the hider Troll, but role gating means only one set is ever bound at a time.
--
-- Binds are active whenever the player is a HIDER in a round (not gated on the live input device, which
-- flickers on PC). The bridged functions self-gate to hider-in-round and a keyboard/mouse player never
-- presses these gamepad KeyCodes, so binding them for every in-round hider is harmless.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))

-- virtual-cursor panel manager (used ONLY for the paint palette; pose uses native selection nav)
local GamepadUIManager
pcall(function() GamepadUIManager = require(ReplicatedStorage:WaitForChild("GamepadUIManager", 5)) end)

-- ===== state =====
local myRole, inRound = nil, false
local poseNavActive = false
-- True while a cursor PANEL is open (Inventory, Shop, Troll, etc.) or the virtual cursor / HUD pointer
-- is on. While this is true, the in-round ability keys (Pose/Paint/Lock/Taunt/Troll and the seeker
-- Reveal keys) must NOT be bound -- otherwise e.g. pressing D-pad Up to navigate the open Inventory
-- would also fire Pose and open the pose menu on top of it. Fed by GamepadUIManager.onStateChanged.
local uiCaptured = false

-- ===== bridges + pose-menu refs (resolved async) =====
local paintBridge, lockBridge, poseBridge, tauntBridge
local poseMenu, poseButtonsFrame

-- forward declarations (used by callbacks created before these are assigned)
local enterPoseNav, exitPoseNav

task.spawn(function()
	local paintGui = pg:WaitForChild("PaintGui", 60)
	if not paintGui then return end
	paintBridge = paintGui:WaitForChild("GamepadPaintControl", 60)
	lockBridge  = paintGui:WaitForChild("GamepadLockControl", 60)
	-- register the paint PALETTE so opening it turns the virtual cursor on (point at the palette to pick
	-- a color, at your own body + Cross to paint; Circle closes it through the bridge).
	local picker = paintGui:WaitForChild("Picker", 60)
	if picker and GamepadUIManager and GamepadUIManager.register then
		GamepadUIManager.register({
			name = "PaintPalette",
			root = paintGui,
			container = picker,
			isVisible = function() return picker.Visible end,
			visibleChanged = picker:GetPropertyChangedSignal("Visible"),
			close = function() if picker.Visible and paintBridge then paintBridge:Fire("close") end end,
		})
	end
end)

task.spawn(function()
	local poseGui = pg:WaitForChild("PoseButtonGui", 60)
	if not poseGui then return end
	poseBridge = poseGui:WaitForChild("GamepadPoseControl", 60)
	poseMenu = poseGui:WaitForChild("Pose", 60)
	poseButtonsFrame = poseMenu and poseMenu:WaitForChild("PoseButtons", 60)
	-- options shouldn't be gamepad-selectable except while we're in pose-nav mode
	if poseButtonsFrame then
		for _, b in ipairs(poseButtonsFrame:GetChildren()) do
			if b:IsA("GuiButton") then b.Selectable = false end
		end
	end
	-- if the menu closes by any other route (round ends, etc.), leave nav mode cleanly
	if poseMenu then
		poseMenu:GetPropertyChangedSignal("Visible"):Connect(function()
			if poseNavActive and not poseMenu.Visible then exitPoseNav(false) end
		end)
	end
end)

task.spawn(function()
	local hud = pg:WaitForChild("Hud", 60)
	if hud then tauntBridge = hud:WaitForChild("GamepadTauntControl", 60) end
end)

-- ===== simple ability fires =====
local function doTaunt() if tauntBridge then tauntBridge:Fire() end end
local function doLock()  if lockBridge  then lockBridge:Fire()  end end
local function doPaint() if paintBridge then paintBridge:Fire("toggle") end end
-- Troll: fire the OpenTrollUI bridge TrollUIClient already exposes. It self-gates to an eligible
-- hider-in-round and opens the panel (a registered cursor panel, so B closes it + cursor turns on).
local function doTroll()
	local evt = ReplicatedStorage:FindFirstChild("OpenTrollUI")
	if evt and evt:IsA("BindableEvent") then evt:Fire() end
end
-- Reveal (seeker): fire the RevealOne / RevealAll bridges RevealUIClient exposes. Each self-gates to an
-- active seeker in the seek phase and prompts the matching dev product.
local function fireBridge(name)
	local evt = ReplicatedStorage:FindFirstChild(name)
	if evt and evt:IsA("BindableEvent") then evt:Fire() end
end
local function doRevealOne() fireBridge("RevealOne") end
local function doRevealAll() fireBridge("RevealAll") end

-- ===== ContextAction handler for the four ability keys =====
local function handler(actionName, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if actionName == "Hider_Taunt" then doTaunt()
	elseif actionName == "Hider_Lock" then doLock()
	elseif actionName == "Hider_Paint" then doPaint()
	elseif actionName == "Hider_Troll" then doTroll()
	elseif actionName == "Hider_Pose" then enterPoseNav()
	elseif actionName == "Seeker_RevealOne" then doRevealOne()
	elseif actionName == "Seeker_RevealAll" then doRevealAll()
	else return Enum.ContextActionResult.Pass end
	return Enum.ContextActionResult.Sink  -- consume the press so nothing else reacts to it
end

-- ===== bind / unbind the four ability keys together =====
local ABIL_BOUND = false
local function bindAbilities()
	if ABIL_BOUND then return end
	ABIL_BOUND = true
	local K, P = GamepadConfig.Keys, GamepadConfig.Priority
	ContextActionService:BindActionAtPriority("Hider_Taunt", handler, false, P.HiderAbility, K.Taunt)
	ContextActionService:BindAction("Hider_Lock", handler, false, K.Lock)
	ContextActionService:BindAction("Hider_Paint", handler, false, K.Paint)
	ContextActionService:BindAction("Hider_Pose", handler, false, K.Pose)
	ContextActionService:BindAction("Hider_Troll", handler, false, K.Troll)
end
local function unbindAbilities()
	if not ABIL_BOUND then return end
	ABIL_BOUND = false
	for _, name in ipairs({ "Hider_Taunt", "Hider_Lock", "Hider_Paint", "Hider_Pose", "Hider_Troll" }) do
		pcall(function() ContextActionService:UnbindAction(name) end)
	end
end

-- ===== bind / unbind the SEEKER reveal keys together (L1 = Reveal One, L2 = Reveal All) =====
local SEEKER_BOUND = false
local function bindSeekerAbilities()
	if SEEKER_BOUND then return end
	SEEKER_BOUND = true
	local K = GamepadConfig.Keys
	ContextActionService:BindAction("Seeker_RevealOne", handler, false, K.RevealOne)
	ContextActionService:BindAction("Seeker_RevealAll", handler, false, K.RevealAll)
end
local function unbindSeekerAbilities()
	if not SEEKER_BOUND then return end
	SEEKER_BOUND = false
	for _, name in ipairs({ "Seeker_RevealOne", "Seeker_RevealAll" }) do
		pcall(function() ContextActionService:UnbindAction(name) end)
	end
end

-- ===== pose-menu Back (O / Circle) while in selection-nav mode =====
local function onPoseBack(_, state)
	if state == Enum.UserInputState.Begin then exitPoseNav(true) end
	return Enum.ContextActionResult.Sink
end

-- ===== POSE: native selection navigation =====
enterPoseNav = function()
	if poseNavActive then return end
	if not (inRound and myRole == "Hider") then return end
	if not (poseBridge and poseButtonsFrame) then return end
	poseNavActive = true

	unbindAbilities()         -- the other hider keybinds turn OFF while the menu is open
	poseBridge:Fire("open")   -- open the real pose menu

	-- native gamepad selection over the pose options (D-pad moves the highlight, Cross applies)
	GuiService.GuiNavigationEnabled = true
	local first = nil
	for _, b in ipairs(poseButtonsFrame:GetChildren()) do
		if b:IsA("GuiButton") then
			b.Selectable = true
			if not first then first = b end
		end
	end
	local default = poseButtonsFrame:FindFirstChild("Default")
	GuiService.SelectedObject = (default and default:IsA("GuiButton")) and default or first

	-- Circle (O / Back) closes the menu; sits above MenuBack so it wins
	ContextActionService:BindActionAtPriority("Pose_NavBack", onPoseBack, false,
		GamepadConfig.Priority.PoseNav, GamepadConfig.Keys.Back)
end

exitPoseNav = function(doClose)
	if not poseNavActive then return end
	poseNavActive = false

	pcall(function() ContextActionService:UnbindAction("Pose_NavBack") end)

	-- drop selection and make the options non-selectable again
	if poseButtonsFrame then
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(poseButtonsFrame) then
			GuiService.SelectedObject = nil
		end
		for _, b in ipairs(poseButtonsFrame:GetChildren()) do
			if b:IsA("GuiButton") then b.Selectable = false end
		end
	end

	if doClose and poseBridge then poseBridge:Fire("close") end

	-- restore the normal hider keybinds (if still a hider in a round)
	if inRound and myRole == "Hider" then bindAbilities() end
end

-- ===== eligibility =====
local function refresh()
	-- While a cursor panel / virtual cursor is open, suppress ALL in-round ability binds so their keys
	-- (D-pad, L1/L2, etc.) drive only the open UI -- not gameplay actions layered behind it. The pose
	-- menu is exempt: it uses native selection-nav and manages its own bind state via poseNavActive, and
	-- it isn't a registered cursor panel, so it never sets uiCaptured.
	if uiCaptured then
		unbindAbilities()
		unbindSeekerAbilities()
		return
	end
	-- HIDER abilities (Taunt/Lock/Paint/Pose/Troll) bind only while a hider in a round.
	if inRound and myRole == "Hider" then
		if not poseNavActive then bindAbilities() end
	else
		if poseNavActive then exitPoseNav(true) end   -- left the round mid-menu: close + restore
		unbindAbilities()
	end
	-- SEEKER reveal keys (L1/L2) bind only while a seeker in a round.
	if inRound and myRole == "Seeker" then
		bindSeekerAbilities()
	else
		unbindSeekerAbilities()
	end
end

-- React to the controller-UI state: when a panel opens (or the virtual cursor / HUD pointer turns on),
-- mark the UI as capturing input and re-run refresh so the ability keys unbind; when everything closes,
-- refresh re-binds them (respecting role / round / poseNav).
if GamepadUIManager and GamepadUIManager.onStateChanged then
	GamepadUIManager.onStateChanged(function(info)
		local captured = (info ~= nil) and (info.panelOpen == true or info.cursorOn == true) or false
		if captured ~= uiCaptured then
			uiCaptured = captured
			refresh()
		end
	end)
end

RoleAnnounce.OnClientEvent:Connect(function(role) myRole = role; refresh() end)
InRound.OnClientEvent:Connect(function(active)
	inRound = active and true or false
	if not inRound then myRole = nil end
	refresh()
end)
refresh()
