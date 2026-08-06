--!strict
-- GamepadConfig: the SINGLE source of truth for all controller (gamepad) keybinds, tunables, the
-- haptics helper, and the list of UI panels the virtual cursor should manage. Every gamepad script
-- reads from here, so changing a control is a ONE-LINE edit in this file (no hunting across scripts).
--
-- KEYCODES vs GLYPHS: Roblox normalizes every controller to the SAME Enum.KeyCode values
-- (ButtonA/B/X/Y, ButtonL1/R1/L2/R2/..., DPad*, ButtonSelect/Start). Only the on-screen GLYPH differs
-- by brand (Xbox 'A' vs PlayStation 'Cross', etc.), and that glyph is derived automatically from the
-- connected controller via UserInputService:GetImageForKeyCode (see GamepadHintsClient). So you only
-- ever set KeyCodes here; the correct PS5/Xbox icons follow automatically.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GamepadConfig = {}

-- ===== KEYBINDS (change any of these freely; all scripts pick the change up) =====
-- NOTE: "Be Seeker" intentionally has NO gamepad bind — it was removed for controller players.
-- ButtonX is the in-round hider Taunt; it's only bound while a hider is in a round, so ButtonX stays
-- free for ProximityPrompts (the engine default prompt button) in the lobby / intermission.
GamepadConfig.Keys = {
	-- Cursor / navigation (GamepadUIManager + bootstrap)
	Back         = Enum.KeyCode.ButtonB,      -- close the top open panel / cancel / exit HUD nav
	Confirm      = Enum.KeyCode.ButtonA,      -- virtual-cursor click / activate the selected HUD button

	-- Lobby HUD navigation (bootstrap): ONE D-pad button toggles Roblox's NATIVE gamepad selection on
	-- the left HUD launcher buttons (Store / Inventory / Crates / Settings / Spectate). Move the
	-- selection with the thumbstick or D-pad, press A (Confirm) to open, B (Back) or HudNav again to exit.
	HudNav       = Enum.KeyCode.DPadLeft,

	-- Spectate CAMERA controls (active only while actually spectating someone)
	SpectatePrev = Enum.KeyCode.ButtonL1,     -- previous target
	SpectateNext = Enum.KeyCode.ButtonR1,     -- next target
	SpectateExit = Enum.KeyCode.ButtonB,      -- leave spectate (right stick orbits the camera)

	-- In-round HIDER abilities (GamepadGameplayClient)
	Taunt        = Enum.KeyCode.ButtonX,      -- Square: in-round hider taunt
	Lock         = Enum.KeyCode.ButtonY,      -- Triangle: toggle position lock
	Pose         = Enum.KeyCode.DPadUp,       -- open the pose menu (native D-pad selection; O closes)
	Paint        = Enum.KeyCode.DPadRight,    -- open the paint palette (virtual cursor; Cross paints)
	PaintConfirm = Enum.KeyCode.ButtonA,      -- Cross ("X"): sample / paint the body part under the cursor
	PaintExit    = Enum.KeyCode.ButtonB,      -- leave a paint session
	Troll        = Enum.KeyCode.ButtonL1,     -- L1: open the Troll panel (hider-in-round). The panel is a
	                                          -- registered cursor panel, so the virtual cursor turns on and
	                                          -- B closes it. (L1 is also Spectate "prev target", but that's
	                                          -- a separate context — you can't troll while spectating.)

	-- Seeker knife (KnifeClient reads this) — right trigger: tap=stab, hold=charge, release=throw
	KnifeThrow   = Enum.KeyCode.ButtonR2,

	-- Paintball gun (PaintballGunController reads this) — right trigger: fire
	PaintballFire = Enum.KeyCode.ButtonR2,

	-- Seeker REVEAL abilities (GamepadGameplayClient, seeker-in-round). These prompt the Reveal One /
	-- Reveal All dev products via RevealUIClient's bridges. L1 is also the hider Troll open and Spectate
	-- "prev target", but those are SEPARATE roles/contexts (you're never a seeker AND a hider/spectator at
	-- once), so the same button is unambiguous per context.
	RevealOne    = Enum.KeyCode.ButtonL1,     -- L1: reveal the nearest single hider
	RevealAll    = Enum.KeyCode.ButtonL2,     -- L2: reveal all hiders

	-- Shift lock toggle (GamepadShiftLockClient). R3 (right-stick click) is the console convention for a
	-- custom shift-lock button. We claim it so it toggles shift lock instead of the engine's default R3
	-- first-person zoom. Only bound for gamepad + non-touch; PC/mobile are unaffected.
	ShiftLock    = Enum.KeyCode.ButtonR3,
}

-- ===== PRIORITIES (ContextActionService BindActionAtPriority; higher = handled first) =====
-- Default BindAction priority is 2000. These sit ABOVE it where one action must win a shared button.
GamepadConfig.Priority = {
	MenuBack     = 2500, -- GamepadUIManager "B closes the top panel"
	HiderAbility = 2600, -- in-round hider abilities (Taunt(Square) etc.) sit above the default and SINK
	PoseNav      = 2800, -- pose-menu Back (O) while the pose menu is in native-selection mode -- must
	                     -- beat MenuBack so it closes the menu / restores the hider keybinds
	Spectate     = 2700, -- spectate-exit (B) must beat MenuBack while spectating
	PaintSession = 3000, -- paint-session A/B must beat both the cursor's A and MenuBack's B
}

-- ===== TUNABLES =====
GamepadConfig.Tuning = {
	StickDeadzone = 0.5,  -- radial / stick selection deadzone
	CursorSpeed   = 900,  -- eyedropper free-cursor speed (px/sec at full stick deflection)
	TauntCooldown = 5,    -- client-side UX mirror only (the SERVER stays authoritative)
	PoseCooldown  = 1,
}

-- ===== HAPTICS =====
GamepadConfig.Haptics = { Enabled = true }

-- ===== CORE PROMPT FOCUS HANDOFF =====
-- Roblox's MarketplaceService prompts (PromptProductPurchase etc.) are CoreGui and navigate with the
-- engine's gamepad selection. A known engine issue: if the GAME currently owns gamepad selection
-- (GuiService.SelectedObject is set, or AutoSelectGuiEnabled auto-grabs one of the game's many
-- Selectable buttons), the prompt that opens AFTER can't take selection -- its OK/Cancel become
-- unreachable on a controller (works the first time, breaks on a later open once selection is dirty).
-- See devforum "PlayStation PromptPurchase breaks all UI navigation controls".
--
-- Call this immediately BEFORE firing a Core prompt from a gamepad path. It releases the game's gamepad
-- selection (clears SelectedObject + suppresses AutoSelect so the engine can't instantly re-grab a HUD
-- button) so the prompt owns navigation, then restores AutoSelect when the prompt closes. No-op for
-- non-gamepad input so PC/mobile are unaffected.
local _promptHandoffActive = false
function GamepadConfig.prepForCorePrompt()
	-- only matters on a gamepad; on KBM/touch the prompt uses mouse/touch and needs no handoff
	local onPad = false
	local ok, pref = pcall(function() return UserInputService.PreferredInput end)
	if ok and pref ~= nil then
		onPad = (pref == Enum.PreferredInput.Gamepad)
	else
		local lit = UserInputService:GetLastInputType()
		onPad = lit == Enum.UserInputType.Gamepad1 or lit == Enum.UserInputType.Gamepad2
			or lit == Enum.UserInputType.Gamepad3 or lit == Enum.UserInputType.Gamepad4
	end
	if not onPad then return end
	if _promptHandoffActive then return end
	_promptHandoffActive = true

	local GuiService = game:GetService("GuiService")
	local MarketplaceService = game:GetService("MarketplaceService")
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local prevAutoSelect = GuiService.AutoSelectGuiEnabled
	-- hand selection to the engine prompt: drop ours and stop the engine from auto-grabbing a game button
	GuiService.AutoSelectGuiEnabled = false
	GuiService.SelectedObject = nil

	-- restore once the prompt closes (purchase finished or cancelled). Guard with a timeout so we never
	-- leave AutoSelect off if the Finished signal somehow doesn't fire for this client.
	local restored = false
	local conn
	local function restore()
		if restored then return end
		restored = true
		_promptHandoffActive = false
		if conn then conn:Disconnect() end
		GuiService.AutoSelectGuiEnabled = prevAutoSelect
	end
	ok, conn = pcall(function()
		return MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, _bought)
			-- PromptProductPurchaseFinished passes (userId, productId, isPurchased)
			if userId == player.UserId then restore() end
		end)
	end)
	if not ok then conn = nil end
	task.delay(20, restore)  -- safety net: never leave AutoSelect suppressed indefinitely
end

-- Play a one-shot HapticEffect. Canonical pattern: create -> set .Type -> parent to Workspace ->
-- :Play(), then destroy on .Ended (with a timeout safety net). Safe no-op on devices without haptics,
-- and gated to gamepad users so KBM/touch players never spawn effect instances. `effectType` is an
-- Enum.HapticEffectType (e.g. UIClick, GameplayCollision).
function GamepadConfig.playHaptic(effectType: EnumItem)
	if not GamepadConfig.Haptics.Enabled then return end

	-- only for players currently on a gamepad (PreferredInput is the canonical check; fall back for
	-- very old clients that predate it).
	local onPad = false
	local ok, pref = pcall(function() return UserInputService.PreferredInput end)
	if ok and pref ~= nil then
		onPad = (pref == Enum.PreferredInput.Gamepad)
	else
		local lit = UserInputService:GetLastInputType()
		onPad = lit == Enum.UserInputType.Gamepad1 or lit == Enum.UserInputType.Gamepad2
			or lit == Enum.UserInputType.Gamepad3 or lit == Enum.UserInputType.Gamepad4
	end
	if not onPad then return end

	local fx = Instance.new("HapticEffect")
	fx.Type = effectType
	fx.Parent = Workspace
	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		pcall(function() fx:Destroy() end)
	end
	fx.Ended:Connect(cleanup)
	pcall(function() fx:Play() end)
	task.delay(3, cleanup) -- safety net in case Ended never fires on this device
end

-- ===== PANELS for the virtual cursor (consumed by GamepadUIBootstrap) =====
-- Each entry describes one modal so the cursor turns on (and B closes it) when it opens.
--   name      : the ScreenGui's name in PlayerGui
--   toggle    : "enabled" (ScreenGui.Enabled is the modal) or "frame" (an inner frame's .Visible is)
--   framePath : required when toggle == "frame" — "/"-path to that inner frame under the ScreenGui
--   container : optional "/"-path the cursor anchors over when the panel opens
--   default   : optional "/"-path of the button to drop the cursor on first
--   choice    : if true, B does NOT auto-close it (yes/no dialogs with a server side effect — the
--               player must point-and-click a choice instead of "backing out")
--   focus     : if true, when the panel opens on a gamepad we ALSO set GuiService.SelectedObject to the
--               `default` button (native gamepad selection), in addition to the virtual cursor. This is
--               for self-contained CONFIRMATION dialogs (yes/no, no grid behind them) so a console
--               player's selection lands on the confirm button the instant the dialog pops -- including
--               a dialog that appears at join, before the player has moved the stick (so the virtual
--               cursor's input-mode detection may not have engaged yet). The frame's SelectionBehavior
--               is Escape, so native selection can't wander out of the dialog into whatever's behind it.
GamepadConfig.Panels = {
	-- ScreenGui.Enabled-toggled modals
	{ name = "Shop",            toggle = "enabled", container = "HolderFrame/Shop",                    default = "HolderFrame/Shop/CloseButton" },
	{ name = "Inventory",       toggle = "enabled", container = "HolderFrame/Inventory",               default = "HolderFrame/Inventory/Inventory/CloseButton" },
	{ name = "CratesShop",      toggle = "enabled", container = "HolderFrame", default = "HolderFrame/Buttons/Knives" },
	{ name = "SeekerQueueGui",  toggle = "enabled", container = "HolderFrame/CleanFrame",              default = "HolderFrame/CleanFrame/Information/Buttons/RobuxPurchaseButton" },
	{ name = "Settings",        toggle = "enabled", container = "HolderFrame/Settings",                default = "HolderFrame/Settings/CloseButton" },
	{ name = "Results",         toggle = "enabled", container = "HolderFrame/Results",                 default = "HolderFrame/Results/CloseButton" },
	-- NOTE: SpectateGui is intentionally NOT a cursor panel. Spectate is a camera mode driven by gamepad
	-- buttons (L1/R1 cycle, B exit, right-stick orbit) in SpectateClient, so the cursor must never
	-- auto-activate for it (it would otherwise pop up even on the transient "No one to spectate" flash).
	{ name = "ConfirmSellGui",  toggle = "enabled", container = "ConfirmSellFrame",                    default = "ConfirmSellFrame/AcceptBT", focus = true },
	{ name = "ChooseMap",       toggle = "enabled", container = "HolderFrame/ChooseMap/MapScrollingFrame",  default = "HolderFrame/ChooseMap/CloseButton" },
	{ name = "DailyRewards",    toggle = "enabled", container = "HolderFrame" },
	-- NOTE: ChangeSizeHider (the right-side "Be Giant" / "Be Tiny" hider tiles) is intentionally NOT a
	-- cursor panel. It stays ENABLED for the entire hider round (RightGamepassesHiderClient), so treating
	-- it as an open modal forced the virtual cursor on the whole round -- hijacking the left stick so the
	-- hider could not walk, and its R2 click-button fired the mouse paint path. Gamepad hiders use
	-- dedicated buttons for their abilities; size-change has no gamepad bind yet (can add on request).
	{ name = "TrollUI",         toggle = "enabled", container = "HolderFrame" },

	-- inner-frame (.Visible) modals shown over another panel
	{ name = "CratesShop",   toggle = "frame", framePath = "HolderFrame/Percentages", container = "HolderFrame/Percentages", default = "HolderFrame/Percentages/Buttons/CoinsButton" },
	-- The "Be Seeker / Revive" confirm prompt. It toggles ScreenGui.Enabled (NOT an inner frame's
	-- .Visible), and the offer can appear the moment a mid-round joiner loads in. focus=true so a console
	-- player's selection lands on "Be Seeker" immediately; choice=true so B doesn't silently back out of a
	-- yes/no with a server side effect (they pick Be Seeker / Revive / the X close button explicitly).
	{ name = "JoinAsSeeker", toggle = "enabled", container = "HolderFrame/ContainerFrame", default = "HolderFrame/ContainerFrame/Buttons/BeSeeker/BeSeeker", choice = true, focus = true },
	-- NOTE: the Pose menu (PoseButtonGui) is intentionally NOT a virtual-cursor panel. On a controller it
	-- uses NATIVE gamepad selection navigation instead (GamepadGameplayClient): opening Pose turns the
	-- other hider keybinds off, the D-pad moves the selection between pose options, Cross applies one, and
	-- Circle (O) closes the menu and restores the keybinds.
}

return GamepadConfig

