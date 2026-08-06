-- GamepadHintsClient: a small on-screen button-hint bar that appears at the bottom of the screen
-- while a controller is the active input, showing the contextual button prompts (Select / Back /
-- shortcuts). Each prompt's glyph is fetched with UserInputService:GetImageForKeyCode, so the icons
-- automatically match the connected controller (Xbox A/B/X/Y vs PlayStation Cross/Circle/Square/
-- Triangle). Keys come from GamepadConfig so the hints always match the actual binds. Hidden entirely
-- for mouse/keyboard and touch players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local GamepadUIManager = require(ReplicatedStorage:WaitForChild("GamepadUIManager"))
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))

-- round/role tracking so the bar shows the in-round prompts (hider abilities / seeker knife) instead of
-- the lobby prompts while a round is running.
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local myRole = nil
local inRound = false

-- ===== canonical controller glyphs =====
-- Roblox normalizes all pads to the same KeyCodes; the correct brand-specific GLYPH is fetched with
-- UserInputService:GetImageForKeyCode, which returns the matching Xbox OR PlayStation image for the
-- connected controller automatically (so a DualSense shows Cross/Circle/Square/Triangle, an Xbox pad
-- shows A/B/X/Y) -- no manual brand detection needed. We fall back to a short text string via
-- GetStringForKeyCode if no image is available (e.g. an unrecognized controller).
local function glyphImageFor(keyCode: Enum.KeyCode): string
	local ok, img = pcall(function() return UserInputService:GetImageForKeyCode(keyCode) end)
	if ok and typeof(img) == "string" and img ~= "" then return img end
	return ""
end

-- compact arrow fallbacks for the D-pad, shown only if no glyph image is available for that key
local DPAD_ARROW = {
	[Enum.KeyCode.DPadLeft]  = "◀",
	[Enum.KeyCode.DPadRight] = "▶",
	[Enum.KeyCode.DPadUp]    = "▲",
	[Enum.KeyCode.DPadDown]  = "▼",
}
local function glyphTextFor(keyCode: Enum.KeyCode): string
	if DPAD_ARROW[keyCode] then return DPAD_ARROW[keyCode] end
	local ok, str = pcall(function() return UserInputService:GetStringForKeyCode(keyCode) end)
	if ok and typeof(str) == "string" and str ~= "" then return str end
	return keyCode.Name
end

-- ===== build the hint bar =====
local gui = Instance.new("ScreenGui")
gui.Name = "GamepadHints"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200  -- above panels so hints are always readable
gui.Enabled = false
gui.Parent = pg

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -12)
bar.AutomaticSize = Enum.AutomaticSize.X   -- grow to fit however many hints are shown
bar.Size = UDim2.new(0, 0, 0, 40)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
bar.BackgroundTransparency = 0.25
bar.BorderSizePixel = 0
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 18)
layout.Parent = bar
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 16); pad.PaddingRight = UDim.new(0, 16)
pad.Parent = bar

-- one hint = a rounded glyph chip + a label. We pool/rebuild them each refresh.
local function clearHints()
	for _, c in ipairs(bar:GetChildren()) do
		if c:IsA("Frame") and c.Name == "Hint" then c:Destroy() end
	end
end

local function addHint(order: number, keyCode: Enum.KeyCode, label: string)
	local hint = Instance.new("Frame")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.AutomaticSize = Enum.AutomaticSize.X
	hint.Size = UDim2.new(0, 0, 1, 0)
	hint.LayoutOrder = order
	hint.Parent = bar
	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	hl.Padding = UDim.new(0, 6)
	hl.Parent = hint

	-- glyph: prefer the canonical per-controller image; fall back to a text chip
	local img = glyphImageFor(keyCode)
	if img ~= "" then
		local glyph = Instance.new("ImageLabel")
		glyph.Name = "Glyph"
		glyph.Size = UDim2.new(0, 26, 0, 26)
		glyph.BackgroundTransparency = 1
		glyph.ScaleType = Enum.ScaleType.Fit
		glyph.Image = img
		glyph.LayoutOrder = 1
		glyph.Parent = hint
	else
		local chip = Instance.new("TextLabel")
		chip.Name = "Glyph"
		chip.Size = UDim2.new(0, 26, 0, 26)
		chip.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
		chip.TextColor3 = Color3.fromRGB(255, 255, 255)
		chip.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		chip.TextSize = 16
		chip.Text = glyphTextFor(keyCode)
		chip.LayoutOrder = 1
		chip.Parent = hint
		Instance.new("UICorner", chip).CornerRadius = UDim.new(0.3, 0)
	end

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.new(0, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(220, 220, 230)
	text.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	text.TextSize = 16
	text.Text = label
	text.LayoutOrder = 2
	text.Parent = hint
end

-- refresh the bar contents for the current state
local lastInfo = { gamepadActive = false, cursorOn = false, panelOpen = false }
local function refresh(info)
	lastInfo = info
	if not info.gamepadActive then
		gui.Enabled = false
		return
	end
	clearHints()
	local K = GamepadConfig.Keys
	if info.panelOpen or info.cursorOn then
		-- inside a panel (or HUD selection / pointer mode, incl. the open paint palette): Select + Back
		addHint(1, K.Confirm, "Select")
		addHint(2, K.Back, "Back")
	elseif inRound and myRole == "Hider" then
		-- in-round hider gameplay: show the ability prompts (Y is Taunt here, not Inventory)
		addHint(1, K.Pose, "Pose")
		addHint(2, K.Paint, "Paint")
		addHint(3, K.Lock, "Lock")
		addHint(4, K.Taunt, "Taunt")
		addHint(5, K.Troll, "Troll")
		addHint(6, K.HudNav, "Menu")
	elseif inRound and myRole == "Seeker" then
		-- in-round seeker: the knife (right trigger), reveal abilities (L1/L2), plus HUD menu navigation
		addHint(1, K.KnifeThrow, "Knife")
		addHint(2, K.RevealOne, "Reveal One")
		addHint(3, K.RevealAll, "Reveal All")
		addHint(4, K.HudNav, "Menu")
	else
		-- free in the lobby: the ONLY control is HUD menu navigation (Inventory / Shop / Crates / Settings
		-- all open from there). (Be Seeker is omitted -- it has no controller binding.)
		addHint(1, K.HudNav, "Menu")
	end
	gui.Enabled = true
end

-- subscribe to manager state; also refresh once now in case a pad is already active
GamepadUIManager.onStateChanged(refresh)
-- re-render the glyphs if the connected controller (and thus its glyph set) changes
UserInputService.GamepadConnected:Connect(function() refresh(lastInfo) end)
UserInputService.GamepadDisconnected:Connect(function() refresh(lastInfo) end)
-- re-render when the round/role changes so the bar swaps between lobby and in-round prompts
RoleAnnounce.OnClientEvent:Connect(function(role) myRole = role; refresh(lastInfo) end)
InRound.OnClientEvent:Connect(function(active)
	inRound = active and true or false
	if not inRound then myRole = nil end
	refresh(lastInfo)
end)
refresh({
	gamepadActive = GamepadUIManager.isGamepadActive(),
	cursorOn = GamepadUIManager.isCursorOn(),
	panelOpen = false,
})