--!strict
-- GamepadUIManager: central controller (gamepad) support for the game's UI panels, MM2-style,
-- built on Roblox's GAMEPAD VIRTUAL CURSOR (GamepadService:EnableGamepadCursor/DisableGamepadCursor).
--
-- WHY THE VIRTUAL CURSOR (and not button-to-button selection):
--   The selection-box approach needs every panel's buttons wired with NextSelectionUp/Down/Left/Right
--   or the directional navigation "escapes" the panel — e.g. on the sell dialog, pressing right off
--   CONFIRM jumped to a knife in the grid behind it. The virtual cursor is a mouse-emulation pointer
--   the player moves with the left stick and clicks with A. It works on ANY UI layout automatically,
--   never escapes to whatever's behind a dialog, and needs zero per-button wiring.
--
-- WHAT IT DOES
--   * Maintains a STACK of open UI panels (registered with a visibility source + a close fn).
--   * While ANY panel is open AND a gamepad is the active input, the virtual cursor is enabled, so
--     the player points-and-clicks the panel's buttons with the stick + A. When the last panel
--     closes (or the player switches to mouse/touch), the cursor is disabled so normal gameplay
--     input is unaffected.
--   * Pressing B (ButtonB) closes the TOP panel via its close fn, mirroring console "back" behavior.
--
-- DESIGN: panels register themselves (or the bootstrap registers them) with a visibility signal and
-- a close function. The manager is otherwise autonomous and existing UI scripts stay untouched.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))

local player = Players.LocalPlayer

export type Panel = {
	name: string,
	root: Instance,          -- the ScreenGui (or frame) the panel lives in
	container: Instance,     -- the frame the cursor should be anchored over when the panel opens
	isVisible: () -> boolean, -- returns true when the panel is currently shown
	close: (() -> ())?,      -- optional: called when B is pressed while this panel is on top
	getDefault: (() -> Instance?)?, -- optional: a GuiObject to drop the cursor onto first
	focus: boolean?,         -- optional: also set native GuiService.SelectedObject to the default button
	                         -- when this panel opens on a gamepad (for self-contained confirm dialogs)
	visibleChanged: RBXScriptSignal?, -- fires when visibility may have changed
}

local GamepadUIManager = {}

-- listeners notified whenever the controller-UI state changes (cursor on/off, panel opened/closed,
-- gamepad active/inactive). Used by the on-screen button-hint bar so it can show/hide + relabel.
local stateListeners: { (any) -> () } = {}
function GamepadUIManager.onStateChanged(fn: (any) -> ()): () -> ()
	table.insert(stateListeners, fn)
	return function()
		local i = table.find(stateListeners, fn)
		if i then table.remove(stateListeners, i) end
	end
end

-- ===== input mode tracking =====
local gamepadActive = false  -- true when the most recent input came from a gamepad

-- Probe once whether the canonical PreferredInput property exists on this client (full release 2025).
local preferredInputAvailable = (pcall(function() return UserInputService.PreferredInput end))

local function refreshGamepadActive()
	-- CANONICAL input-device detection: UserInputService.PreferredInput reflects the player's PRIMARY
	-- input device and supersedes GetLastInputType (which required OR-ing the four gamepad values and
	-- mis-reports "is mobile" on touch laptops). We fall back to GetLastInputType only on clients that
	-- predate PreferredInput.
	if preferredInputAvailable then
		gamepadActive = (UserInputService.PreferredInput == Enum.PreferredInput.Gamepad)
		return
	end
	local lit = UserInputService:GetLastInputType()
	if lit == Enum.UserInputType.Gamepad1 or lit == Enum.UserInputType.Gamepad2
		or lit == Enum.UserInputType.Gamepad3 or lit == Enum.UserInputType.Gamepad4 then
		gamepadActive = true
	elseif lit == Enum.UserInputType.Keyboard or lit == Enum.UserInputType.MouseButton1
		or lit == Enum.UserInputType.MouseButton2 or lit == Enum.UserInputType.MouseMovement
		or lit == Enum.UserInputType.Touch then
		gamepadActive = false
	end
end

function GamepadUIManager.isGamepadActive(): boolean
	return gamepadActive
end

-- ===== the open-panel stack =====
local stack: { Panel } = {}

local function indexOf(name: string): number?
	for i, p in ipairs(stack) do
		if p.name == name then return i end
	end
	return nil
end

-- ===== virtual cursor control =====
local cursorOn = false
local lastDisableClock = 0  -- for the same-frame enable-after-disable speed bug workaround

local function notifyState()
	local top = stack[#stack]
	local info = {
		gamepadActive = gamepadActive,
		cursorOn = cursorOn,
		panelOpen = top ~= nil,
		topName = top and top.name or nil,
	}
	for _, fn in ipairs(stateListeners) do
		task.spawn(fn, info)
	end
end

-- Enable the cursor over the top panel (anchored on its default button / container so it appears in a
-- sensible spot), or disable it when there's nothing open or the player isn't on a gamepad. Also used
-- for the HUD cursor toggle (forceShow) so a controller player can point at HUD buttons that open the
-- first panel.
local hudCursorForced = false  -- the player toggled the cursor on over the always-on HUD

local function syncCursor()
	local top = stack[#stack]
	-- show the cursor when: a panel is open, OR the player force-toggled it over the HUD; AND a gamepad
	-- is the active input. Otherwise it must be OFF (so it never sits static during free gameplay).
	local shouldShow = gamepadActive and (top ~= nil and top.isVisible() or hudCursorForced)

	if shouldShow then
		-- pick where to anchor the cursor: the panel's explicit default, else its container, else nil
		-- (nil = engine default/centre position; never call EnableGamepadCursor with NO argument).
		local anchor: Instance? = nil
		if top then
			if top.getDefault then anchor = top.getDefault() end
			if not (anchor and anchor:IsA("GuiObject")) then anchor = top.container end
			if not (anchor and anchor:IsA("GuiObject")) then anchor = top.root end
		end
		-- workaround the documented speed bug: if we disabled the cursor very recently, wait a frame
		-- before re-enabling so movement speed doesn't compound.
		if cursorOn == false and (os.clock() - lastDisableClock) < 0.05 then
			task.wait()
		end
		pcall(function()
			if anchor and anchor:IsA("GuiObject") then
				GamepadService:EnableGamepadCursor(anchor)
			else
				GamepadService:EnableGamepadCursor(nil)  -- nil = default position (NOT no-arg, which errors)
			end
		end)
		cursorOn = true
	elseif cursorOn then
		pcall(function() GamepadService:DisableGamepadCursor() end)
		cursorOn = false
		lastDisableClock = os.clock()
	end
	notifyState()
end

-- Public: toggle the virtual cursor over the HUD (no panel open) so a controller player can click the
-- HUD launcher buttons that open the first panel. Auto-clears when a panel opens or input switches.
function GamepadUIManager.toggleHudCursor()
	if not gamepadActive then return end
	hudCursorForced = not hudCursorForced
	syncCursor()
end

function GamepadUIManager.isCursorOn(): boolean
	return cursorOn
end

-- CONFIRM-DIALOG FOCUS: for panels flagged `focus`, hand NATIVE gamepad selection
-- (GuiService.SelectedObject) to the default button so a controller player's selection lands on the
-- confirm button -- the "opened at join, nothing selected, couldn't move" case on the Be-Seeker prompt.
--
-- WHY THIS IS GATED ON gamepadActive (the player's CURRENT preferred input), NOT merely "has a gamepad":
-- a player can have BOTH a mouse/keyboard and a controller connected (PC + pad, Steam Deck, a controller
-- on another device, etc.). If we focused whenever a gamepad merely EXISTS, a mouse player with a pad
-- plugged in would get an unwanted native selection box on the button. So we only focus when the gamepad
-- is the ACTIVE input. To still cover "the prompt popped while I was on mouse, then I picked up the
-- controller," focusConfirmDialog is also re-run from the input-mode-changed handler -- so the moment the
-- player starts driving with the stick, the open confirm dialog's button becomes selected.
--
-- selectionOwned tracks whether the CURRENT SelectedObject was set by us, so we can clear it when the
-- dialog closes or the player switches back to mouse/touch without stomping a selection something else set.
-- The dialog's frame uses SelectionBehavior = Escape, so native selection can't wander out into UI behind it.
local selectionOwned: Instance? = nil

local function clearOwnedSelection()
	if selectionOwned and GuiService.SelectedObject == selectionOwned then
		GuiService.SelectedObject = nil
	end
	selectionOwned = nil
end

local function focusConfirmDialog(panel: Panel)
	if not gamepadActive then return end  -- only when the gamepad is the player's ACTIVE input
	if not (panel and panel.focus and panel.getDefault) then return end
	if not panel.isVisible() then return end
	local target = panel.getDefault()
	if target and target:IsA("GuiObject") then
		if not target.Selectable then target.Selectable = true end
		GuiService.SelectedObject = target
		selectionOwned = target
	end
end

-- Re-apply (or clear) confirm-dialog focus for the current top panel after an input-mode change.
local function refreshConfirmFocus()
	local top = stack[#stack]
	if gamepadActive and top and top.focus and top.isVisible() then
		focusConfirmDialog(top)
	else
		-- left gamepad input (or no focus dialog on top): drop any selection box WE placed so a mouse
		-- player doesn't see a lingering highlight.
		clearOwnedSelection()
	end
end

local function pushPanel(panel: Panel)
	if indexOf(panel.name) then return end  -- already open
	table.insert(stack, panel)
	hudCursorForced = false  -- a real panel is open now; drop the HUD-forced cursor state
	-- defer a frame so freshly-cloned panel contents exist before the cursor anchors
	task.defer(function()
		if stack[#stack] == panel and panel.isVisible() then
			syncCursor()
			focusConfirmDialog(panel)  -- native selection for confirm dialogs (works even pre-cursor-arm)
		end
	end)
end

local function popPanel(name: string)
	local i = indexOf(name)
	if not i then return end
	local panel = stack[i]
	table.remove(stack, i)
	-- if a focus dialog closed, clear any native selection WE placed on its button so it doesn't linger
	-- (or get auto-grabbed onto something behind it).
	if panel and panel.focus then clearOwnedSelection() end
	task.defer(syncCursor)
end

-- ===== registration =====
-- Register a panel. We hook its visibleChanged signal (e.g. ScreenGui:GetPropertyChangedSignal
-- ("Enabled")) to push/pop it from the stack automatically as it shows/hides.
function GamepadUIManager.register(panel: Panel)
	if not panel.container then panel.container = panel.root end

	if panel.isVisible() then
		pushPanel(panel)
	end

	if panel.visibleChanged then
		panel.visibleChanged:Connect(function()
			if panel.isVisible() then
				pushPanel(panel)
			else
				popPanel(panel.name)
			end
		end)
	end
end

-- ===== B = back/close =====
local BACK_ACTION = "GamepadUI_Back"
local function onBack(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	local top = stack[#stack]
	if top then
		if top.close then
			top.close()  -- the panel's close fn flips its visibility, which pops it via visibleChanged
		else
			popPanel(top.name)
		end
		return Enum.ContextActionResult.Sink
	end
	-- no panel open, but the HUD cursor is up: B turns it off (back out of "pointer mode")
	if hudCursorForced then
		hudCursorForced = false
		syncCursor()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

-- ===== lifecycle =====
local started = false
function GamepadUIManager.start()
	if started then return end
	started = true

	GuiService.GuiNavigationEnabled = true
	refreshGamepadActive()

	local function onInputModeMaybeChanged()
		local was = gamepadActive
		refreshGamepadActive()
		if gamepadActive ~= was then
			if not gamepadActive then
				hudCursorForced = false  -- leaving gamepad: drop any HUD pointer state
			end
			-- input mode changed: show the cursor if a panel is open on gamepad, hide it otherwise
			syncCursor()
			-- and apply/clear native focus for an open confirm dialog (covers "prompt popped on mouse,
			-- then the player picked up the controller" -> the button becomes selected now).
			refreshConfirmFocus()
		end
	end
	-- Listen to the canonical PreferredInput change when available; otherwise the legacy event.
	if preferredInputAvailable then
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(onInputModeMaybeChanged)
	else
		UserInputService.LastInputTypeChanged:Connect(onInputModeMaybeChanged)
	end

	-- Back/close closes the top panel. BindActionAtPriority so it sits above default UI handling; it
	-- Passes when no panel is open so it never eats the button during normal gameplay. Key + priority
	-- come from GamepadConfig so they're changeable in one place.
	ContextActionService:BindActionAtPriority(
		BACK_ACTION, onBack, false, GamepadConfig.Priority.MenuBack, GamepadConfig.Keys.Back
	)
end

return GamepadUIManager
