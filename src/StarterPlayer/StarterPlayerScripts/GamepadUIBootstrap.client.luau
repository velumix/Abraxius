-- GamepadUIBootstrap: registers all of the game's UI panels with the GamepadUIManager so a
-- controller player can navigate them (thumbstick/d-pad to move the selection box, A to activate,
-- B to back out). Runs once on the client. Existing UI scripts are untouched; this only wires the
-- manager to each panel's visibility + a close action.
--
-- Panel visibility models found in this game:
--   * Most modals toggle ScreenGui.Enabled  -> watch Enabled; close by setting Enabled=false.
--   * JoinAsSeeker: ScreenGui stays enabled; the ConfirmJoin frame's .Visible is the modal -> watch
--     that; B triggers the Decline button (it's a yes/no choice, so backing out = decline).
--   * PoseButtonGui: the Pose frame's .Visible toggles a small pose-picker bar -> watch that.
--   * CratesShop also has an inner KnifePercentages odds sub-panel (.Visible) shown over the shop.
--   * RightGamepasses is always-on HUD (not a modal) and is intentionally NOT registered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local GamepadUIManager = require(ReplicatedStorage:WaitForChild("GamepadUIManager"))
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))
GamepadUIManager.start()

-- small helpers ----------------------------------------------------------------
local function resolve(root: Instance, path: string): Instance?
	local node: Instance? = root
	for part in string.gmatch(path, "[^/]+") do
		if not node then return nil end
		node = node:FindFirstChild(part)
	end
	return node
end

-- Register a standard ScreenGui.Enabled-toggled modal. `containerPath` is where the buttons live
-- (relative to the ScreenGui, using "/" separators); `defaultPath` (optional) is the button to focus
-- first. Closing sets Enabled=false (the panel's own scripts already react to that).
local function registerEnabledModal(guiName: string, containerPath: string, defaultPath: string?)
	local gui = pg:WaitForChild(guiName, 30)
	if not gui or not gui:IsA("ScreenGui") then return end
	GamepadUIManager.register({
		name = guiName,
		root = gui,
		container = resolve(gui, containerPath) or gui,
		isVisible = function() return gui.Enabled end,
		close = function() gui.Enabled = false end,
		getDefault = defaultPath and function() return resolve(gui, defaultPath) end or nil,
		visibleChanged = gui:GetPropertyChangedSignal("Enabled"),
	})
end

-- Register a modal whose visibility is an inner frame's .Visible. `onClose` (optional) is a function
-- B should run to back out; if nil, B just hides the frame (when hideFrame ~= false). For choice
-- modals with a server side-effect (e.g. JoinAsSeeker decline), pass onClose = nil and hideFrame =
-- false so B does nothing and the player must click a choice with the cursor.
local function registerFrameModal(guiName: string, framePath: string, containerPath: string, opts: {default: string?, onClose: (() -> ())?, hideFrame: boolean?}?)
	local gui = pg:WaitForChild(guiName, 30)
	if not gui then return end
	local frame = resolve(gui, framePath)
	if not frame or not frame:IsA("GuiObject") then return end
	opts = opts or {}
	GamepadUIManager.register({
		name = guiName .. "/" .. framePath,
		root = gui,
		container = resolve(gui, containerPath) or frame,
		isVisible = function() return frame.Visible and gui.Enabled end,
		close = function()
			if opts.onClose then
				opts.onClose()
			elseif opts.hideFrame ~= false then
				frame.Visible = false
			end
		end,
		getDefault = opts.default and function() return resolve(gui, opts.default) end or nil,
		visibleChanged = frame:GetPropertyChangedSignal("Visible"),
	})
end

-- ===== register every panel from GamepadConfig.Panels =====
-- The full panel list (and each panel's cursor-anchor / default-focus paths) lives in GamepadConfig so
-- it's changeable in one place. "enabled" panels toggle via ScreenGui.Enabled; "frame" panels via an
-- inner frame's .Visible. `choice` panels (yes/no with a server side effect) are NOT auto-closed by the
-- Back button — the player must point-and-click a choice instead.
for _, p in ipairs(GamepadConfig.Panels) do
	if p.toggle == "enabled" then
		registerEnabledModal(p.name, p.container, p.default)
	elseif p.toggle == "frame" then
		registerFrameModal(p.name, p.framePath, p.container, { default = p.default, hideFrame = not p.choice })
	end
end

print("[GamepadUIBootstrap] registered UI panels for controller navigation")

-- ============================================================================
-- CONTROLLER KEYBINDS (open/close panels, via ContextActionService)
-- ============================================================================
-- All keys come from GamepadConfig.Keys so they're changeable in one place. Buttons claimed elsewhere
-- and intentionally NOT reused here: ButtonR2 (knife throw, KnifeClient), the Confirm button
-- (virtual-cursor click), and the Back button (close, GamepadUIManager). "Be Seeker" has been removed
-- for controller players, so ButtonX is left free for ProximityPrompts (default prompt button = X).

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- only bind these for clients that actually have a gamepad and aren't touch (console, or PC/handheld
-- with a controller). KBM/mobile are unaffected.
local function gamepadEligible(): boolean
	return UserInputService.GamepadEnabled and not UserInputService.TouchEnabled
end

-- fire a BindableEvent child of a PlayerGui ScreenGui (the same Open*/Toggle* events the HUD buttons
-- use). Returns true if it fired.
local function fireGuiEvent(guiName: string, eventName: string): boolean
	local gui = pg:FindFirstChild(guiName)
	local evt = gui and gui:FindFirstChild(eventName)
	if evt and evt:IsA("BindableEvent") then evt:Fire(); return true end
	return false
end

-- close every panel (mirrors HUDBarClient.closeAllPanels) so a shortcut switches context cleanly
local function closeAllPanels()
	fireGuiEvent("Settings", "CloseSettings")
	fireGuiEvent("Shop", "CloseShop")
	fireGuiEvent("CratesShop", "CloseCrateShop")
	fireGuiEvent("SeekerQueueGui", "CloseSeekerQueue")
	fireGuiEvent("StarterPack", "CloseStarterPack")
	local inv = pg:FindFirstChild("Inventory")
	if inv then inv.Enabled = false end
	local results = pg:FindFirstChild("Results")
	if results then results.Enabled = false end
end

-- generic "toggle a panel": if it's already open, close everything; else close everything then open it.
local function toggleEnabledPanel(guiName: string, openEvent: string?)
	local gui = pg:FindFirstChild(guiName)
	if not gui then return end
	local wasOpen = gui.Enabled
	closeAllPanels()
	if not wasOpen then
		if openEvent then
			fireGuiEvent(guiName, openEvent)
		else
			gui.Enabled = true
		end
	end
end

-- lobby vs in-round state (Spectate + Be-Seeker availability mirror the HUD rules)
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local InRound = Remotes:WaitForChild("InRound")
local inRoundNow = false
InRound.OnClientEvent:Connect(function(v) inRoundNow = v and true or false end)

-- action handler factory: runs `fn` on button press (Begin), sinks the input so it doesn't leak.
local function press(fn)
	return function(_, state)
		if state == Enum.UserInputState.Begin then
			GamepadConfig.playHaptic(Enum.HapticEffectType.UIClick)  -- subtle click feedback on a controller
			fn()
		end
		return Enum.ContextActionResult.Sink
	end
end

-- ============================================================================
-- HUD SELECTION NAVIGATION (D-pad Left)
-- ============================================================================
-- One button (GamepadConfig.Keys.HudNav, default DPad Left) turns on Roblox's NATIVE gamepad GUI
-- selection over the left HUD launcher buttons (Store / Inventory / Crates / Settings / Spectate).
-- The player moves the selection box with the thumbstick or D-pad and presses A to open; B (or HudNav
-- again) exits. We make those buttons Selectable ONLY while nav is active, so the engine's
-- AutoSelectGuiEnabled has nothing to grab the rest of the time. The HUD buttons fire their
-- multi-platform Activated event on the A press; we connect that (gated to gamepad + cursor-off + nav
-- active) to the SAME open actions the mouse uses, so mouse / touch / virtual-cursor are unaffected
-- (their MouseButton1Click path still runs and would otherwise double-fire). "Be Seeker" is left out
-- entirely (no controller access), keeping ButtonX free for ProximityPrompts.

local hudNavActive = false
local hudButtons = nil      -- cached ordered list of { btn = ImageButton, open = function }
local hudNavWired = false   -- Activated handlers connected once
local enterHudNav, exitHudNav, toggleHudNav  -- forward declarations

local function getHudButtons()
	if hudButtons then return hudButtons end
	local hud = pg:FindFirstChild("Hud")
	local lb = hud and hud:FindFirstChild("LeftButtons")
	local main = lb and lb:FindFirstChild("MainButtons")
	if not main then return nil end
	local list = {
		{ btn = main:FindFirstChild("StoreButton"),     open = function() toggleEnabledPanel("Shop", "OpenShop") end },
		-- Inventory is a REGISTERED GamepadUIManager panel, so opening it (Enabled=true) immediately
		-- pushes it on the manager stack + turns the cursor on. That made the toggle path race: by the
		-- time this Activated handler read wasOpen it could already be true, so the press toggled it shut.
		-- A controller exits a panel with B (manager handles that), so the press only ever needs to OPEN.
		-- Open-only + idempotent: close other panels, then force this one open. No wasOpen toggle.
		{ btn = main:FindFirstChild("InventoryButton"), open = function()
			closeAllPanels()
			local inv = pg:FindFirstChild("Inventory")
			if inv then inv.Enabled = true end
		end },
		{ btn = main:FindFirstChild("CratesButton"),    open = function() toggleEnabledPanel("CratesShop", "OpenCrateShop") end },
		{ btn = main:FindFirstChild("SettingsButton"),  open = function() toggleEnabledPanel("Settings", "OpenSettings") end },
	}
	local sub = lb and lb:FindFirstChild("SubButtons")
	local spec = sub and sub:FindFirstChild("SpectateButton")
	if spec then
		table.insert(list, { btn = spec, open = function()
			if inRoundNow then return end  -- spectate is lobby-only (matches HUD visibility)
			closeAllPanels()
			fireGuiEvent("SpectateGui", "ToggleSpectate")
		end })
	end
	-- NOTE: SeekerButton ("Be Seeker") is deliberately NOT included — no controller access.
	hudButtons = list
	return hudButtons
end

local function wireHudActivations()
	if hudNavWired then return end
	local list = getHudButtons()
	if not list then return end
	hudNavWired = true
	for _, e in ipairs(list) do
		if e.btn and e.btn:IsA("GuiButton") then
			local open = e.open
			e.btn.Activated:Connect(function()
				-- only the gamepad-selection A press routes through here; mouse / touch / virtual-cursor
				-- clicks use the HUD's own MouseButton1Click, so we'd double-fire without this gate.
				if not hudNavActive then return end
				if not GamepadUIManager.isGamepadActive() then return end
				if GamepadUIManager.isCursorOn() then return end
				exitHudNav()
				open()
			end)
		end
	end
end

exitHudNav = function()
	if not hudNavActive then return end
	hudNavActive = false
	GuiService.SelectedObject = nil
	local list = getHudButtons()
	if list then
		for _, e in ipairs(list) do
			if e.btn then e.btn.Selectable = false end
		end
	end
	ContextActionService:UnbindAction("GamepadUI_HudNavBack")
end

enterHudNav = function()
	if hudNavActive then return end
	local list = getHudButtons()
	if not list then return end
	wireHudActivations()
	-- make the VISIBLE launcher buttons selectable and focus the first one
	local first = nil
	for _, e in ipairs(list) do
		if e.btn then
			local vis = e.btn.Visible
			e.btn.Selectable = vis
			if vis and not first then first = e.btn end
		end
	end
	if not first then return end  -- nothing visible to navigate
	hudNavActive = true
	GuiService.GuiNavigationEnabled = true
	GuiService.SelectedObject = first
	-- B exits HUD nav without opening anything (above the manager's Back so it wins, and sinks).
	ContextActionService:BindActionAtPriority("GamepadUI_HudNavBack", function(_, st)
		if st == Enum.UserInputState.Begin then exitHudNav() end
		return Enum.ContextActionResult.Sink
	end, false, GamepadConfig.Priority.MenuBack + 50, GamepadConfig.Keys.Back)
end

toggleHudNav = function()
	if hudNavActive then exitHudNav() else enterHudNav() end
end

local function bindAll()
	if not gamepadEligible() then return end

	-- LOBBY: the ONLY gamepad keybind is HUD navigation -- one D-pad button toggles native gamepad
	-- selection on the left HUD launcher buttons (Store / Inventory / Crates / Settings / Spectate);
	-- move with the stick/D-pad, A to open, B to exit. Inventory opens from there, NOT via a dedicated
	-- Y shortcut (Y is the in-round hider Taunt, handled by GamepadGameplayClient).
	ContextActionService:BindAction("GamepadUI_HudNav",
		press(function() toggleHudNav() end),
		false, GamepadConfig.Keys.HudNav)

	-- NOTE: "Be Seeker" has NO gamepad binding (removed for controller players). This also leaves
	-- ButtonX free for ProximityPrompts (ChooseMap screen, Watch-Ad sign), whose default button is X.
end

local function unbindAll()
	exitHudNav()
	for _, name in ipairs({ "GamepadUI_HudNav" }) do
		ContextActionService:UnbindAction(name)
	end
end

-- bind now if eligible, and react to a controller being connected/disconnected at runtime so a PC
-- player who plugs in a pad mid-session gets the binds (and they're removed if it's unplugged).
if gamepadEligible() then bindAll() end
UserInputService.GamepadConnected:Connect(function() if gamepadEligible() then bindAll() end end)
UserInputService.GamepadDisconnected:Connect(function()
	if not UserInputService.GamepadEnabled then unbindAll() end
end)

print("[GamepadUIBootstrap] controller keybinds bound")
