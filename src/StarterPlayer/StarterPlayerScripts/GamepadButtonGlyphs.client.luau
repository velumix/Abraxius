-- GamepadButtonGlyphs (LocalScript, StarterPlayer.StarterPlayerScripts)
-- ============================================================================
-- On the bottom-HUD buttons, show the CONTROLLER glyph (the console keybind indicator) and HIDE the PC
-- keybind letters (Q / V / E / F and their drop-shadow) when a gamepad is the active input. On
-- keyboard/mouse it's the reverse (letters shown, glyph hidden). On touch we leave the per-button
-- script's own state alone.
--
-- The glyph is a SEPARATE ImageLabel placed on the button (a sibling of the letter label), so hiding
-- the whole letter label never hides the glyph. The image comes from UserInputService:GetImageForKeyCode,
-- which returns the correct brand art automatically (PlayStation Triangle/Cross/etc. vs Xbox Y/A/etc.).
-- Keys come from GamepadConfig.Keys, so re-binding a control updates the glyph too.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))
local K = GamepadConfig.Keys

-- bottom-HUD buttons and the gamepad key each maps to (read from GamepadConfig)
local BUTTONS = {
	{ name = "PaintButton", key = K.Paint },
	{ name = "LockButton",  key = K.Lock  },
	{ name = "PoseButton",  key = K.Pose  },
	{ name = "TauntButton", key = K.Taunt },
	{ name = "TrollButton", key = K.Troll },  -- same Keybind-label structure as the others (showed "R")
}

local function gamepadActive(): boolean
	local ok, pref = pcall(function() return UserInputService.PreferredInput end)
	if ok and pref ~= nil then return pref == Enum.PreferredInput.Gamepad end
	local lit = UserInputService:GetLastInputType()
	return lit == Enum.UserInputType.Gamepad1 or lit == Enum.UserInputType.Gamepad2
		or lit == Enum.UserInputType.Gamepad3 or lit == Enum.UserInputType.Gamepad4
end

local function glyphImage(key: Enum.KeyCode): string
	local ok, img = pcall(function() return UserInputService:GetImageForKeyCode(key) end)
	if ok and typeof(img) == "string" and img ~= "" then return img end
	return ""
end

local entries = {}

local function applyOne(entry)
	if not (entry.kb and entry.glyph) then return end
	-- touch device that's NOT on a controller: leave the per-button script's state untouched
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled and not gamepadActive() then
		entry.glyph.Visible = false
		return
	end
	if gamepadActive() then
		-- controller: hide the PC letter label entirely (letter + drop-shadow + stroke all live under
		-- it), and show the controller glyph in its place.
		entry.kb.Visible = false
		local image = glyphImage(entry.key)
		entry.glyph.Image = image
		entry.glyph.Visible = (image ~= "")
	else
		-- keyboard/mouse: show the PC letter label, hide the glyph
		entry.glyph.Visible = false
		entry.kb.Visible = true
	end
end

local applyHudNavGlyph  -- forward-declared; updates the Left-D-pad glyph beside the Inventory button
local applyRevealGlyphs -- forward-declared; updates the seeker Reveal One / Reveal All glyphs
local function applyAll()
	for _, e in ipairs(entries) do applyOne(e) end
	if applyHudNavGlyph then applyHudNavGlyph() end
	if applyRevealGlyphs then applyRevealGlyphs() end
end

local function setupButton(def)
	task.spawn(function()
		local hud = pg:WaitForChild("Hud", 60)
		local bottom = hud and hud:WaitForChild("BottomButtons", 60)
		if not bottom then return end
		local btn = bottom:WaitForChild(def.name, 60)
		if not btn then return end
		local kb = btn:WaitForChild("Keybind", 60)
		if not kb then return end

		-- glyph lives on the BUTTON (sibling of the letter label) so hiding the letter label can never
		-- hide the glyph. It mirrors the letter label's footprint so it sits exactly where (Q)/(V)/etc. was.
		local glyph = btn:FindFirstChild("GamepadGlyph")
		if not glyph then
			glyph = Instance.new("ImageLabel")
			glyph.Name = "GamepadGlyph"
			glyph.BackgroundTransparency = 1
			glyph.ScaleType = Enum.ScaleType.Fit
			glyph.AnchorPoint = kb.AnchorPoint
			glyph.Position = kb.Position
			glyph.Size = kb.Size
			glyph.ZIndex = kb.ZIndex + 1
			glyph.Visible = false
			glyph.Parent = btn
		end

		table.insert(entries, { kb = kb, glyph = glyph, key = def.key })
		applyOne(entries[#entries])
	end)
end

for _, def in ipairs(BUTTONS) do setupButton(def) end

-- ============================================================================
-- Seeker REVEAL buttons (Hud.RevealButtons.{RevealOneButton, RevealAllButton}). Unlike the bottom-HUD
-- buttons these have NO Keybind label (they never showed a PC key), so there's nothing to hide -- we
-- just add a controller glyph in the top-right corner, shown only while a gamepad is the active input.
-- L1 = Reveal One, L2 = Reveal All (keys from GamepadConfig).
-- ============================================================================
local revealEntries = {}
applyRevealGlyphs = function()
	local onPad = gamepadActive()
	for _, e in ipairs(revealEntries) do
		if e.glyph then
			if onPad then
				local image = glyphImage(e.key)
				e.glyph.Image = image
				e.glyph.Visible = (image ~= "")
			else
				e.glyph.Visible = false
			end
		end
	end
end

local function setupRevealButton(btnName, key)
	task.spawn(function()
		local hud = pg:WaitForChild("Hud", 60)
		local frame = hud and hud:WaitForChild("RevealButtons", 60)
		if not frame then return end
		local btn = frame:WaitForChild(btnName, 60)
		if not btn then return end
		local glyph = btn:FindFirstChild("GamepadGlyph")
		if not glyph then
			glyph = Instance.new("ImageLabel")
			glyph.Name = "GamepadGlyph"
			glyph.BackgroundTransparency = 1
			glyph.ScaleType = Enum.ScaleType.Fit
			-- top-right corner of the button so it doesn't cover the Icon/Title
			glyph.AnchorPoint = Vector2.new(1, 0)
			glyph.Position = UDim2.new(1, -2, 0, 2)
			glyph.Size = UDim2.fromScale(0.32, 0.32)
			glyph.ZIndex = btn.ZIndex + 5
			glyph.Visible = false
			local ar = Instance.new("UIAspectRatioConstraint")
			ar.AspectRatio = 1
			ar.DominantAxis = Enum.DominantAxis.Height
			ar.Parent = glyph
			glyph.Parent = btn
		end
		table.insert(revealEntries, { glyph = glyph, key = key })
		applyRevealGlyphs()
	end)
end

setupRevealButton("RevealOneButton", K.RevealOne)
setupRevealButton("RevealAllButton", K.RevealAll)

-- ============================================================================
-- Left-D-pad glyph beside the lobby Inventory button. The Left D-pad opens HUD navigation (which lands
-- on these launcher buttons), so we show a small DPadLeft glyph just to the RIGHT of the Inventory
-- button as a hint -- only while a gamepad is the active input, and with a gap so it never overlaps.
-- ============================================================================
local hudNavGlyph = nil
applyHudNavGlyph = function()
	if not hudNavGlyph then return end
	if gamepadActive() then
		local image = glyphImage(K.HudNav)
		hudNavGlyph.Image = image
		hudNavGlyph.Visible = (image ~= "")
	else
		hudNavGlyph.Visible = false
	end
end

task.spawn(function()
	local hud = pg:WaitForChild("Hud", 60)
	local left = hud and hud:WaitForChild("LeftButtons", 60)
	local main = left and left:WaitForChild("MainButtons", 60)
	local invBtn = main and main:WaitForChild("InventoryButton", 60)
	if not invBtn then return end
	hudNavGlyph = invBtn:FindFirstChild("HudNavGlyph")
	if not hudNavGlyph then
		hudNavGlyph = Instance.new("ImageLabel")
		hudNavGlyph.Name = "HudNavGlyph"
		hudNavGlyph.BackgroundTransparency = 1
		hudNavGlyph.ScaleType = Enum.ScaleType.Fit
		hudNavGlyph.AnchorPoint = Vector2.new(0, 0.5)
		hudNavGlyph.Position = UDim2.new(1.1, 0, 0.5, 0)   -- right of the button, ~10% gap (no overlap)
		hudNavGlyph.Size = UDim2.fromScale(0.65, 0.65)     -- square (see UIAspectRatioConstraint below)
		hudNavGlyph.ZIndex = invBtn.ZIndex + 1
		hudNavGlyph.Visible = false
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.DominantAxis = Enum.DominantAxis.Height
		ar.Parent = hudNavGlyph
		hudNavGlyph.Parent = invBtn
	end
	applyHudNavGlyph()
end)

-- re-apply whenever the input device changes (PreferredInput is canonical; fall back for old clients).
-- a controller (re)connecting can change the brand art, so re-fetch the glyph then too.
local okPref = pcall(function() return UserInputService.PreferredInput end)
if okPref then
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(applyAll)
else
	UserInputService.LastInputTypeChanged:Connect(applyAll)
end
UserInputService.GamepadConnected:Connect(applyAll)
UserInputService.GamepadDisconnected:Connect(applyAll)

-- the per-button scripts set their keybind label at startup too, so re-apply a couple of times shortly
-- after load to win any first-frame ordering race.
task.delay(1, applyAll)
task.delay(3, applyAll)
