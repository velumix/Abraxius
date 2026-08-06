-- CodeRedeemClient: wires the Settings > Code row. Reads the code the player typed into the CodeInput
-- TextBox and, on clicking CLAIM, sends it to the server (RedeemCode) to validate + reward. The server
-- replies on RedeemResult; we flash the outcome on the CLAIM button label (briefly) and clear the box on
-- success. The CLAIM button gets a hover/press scale tween to match the rest of the game's buttons.
--
-- All rewarding/validation is SERVER-SIDE (CodeRedeemManager) -- this script only collects the input and
-- shows feedback, so a client can never grant itself a code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RedeemCode = Remotes:WaitForChild("RedeemCode")
local RedeemResult = Remotes:WaitForChild("RedeemResult")

-- optional shared helpers (guarded so a missing one never errors)
local UISounds
pcall(function() UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5)) end)
-- Confetti module for the instant success celebration (screen + character confetti). We call this
-- DIRECTLY rather than PurchaseFX.prompt(), because PurchaseFX.prompt() plays the rainbow swirl meant
-- for an open dev-product PURCHASE prompt -- which shouldn't appear for a free code redeem.
local Confetti
pcall(function() Confetti = require(ReplicatedStorage:WaitForChild("Confetti", 5)) end)

-- format a number with thousands separators (1000 -> "1,000")
local function commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ===== reward feedback: coin sound + on-screen floating text =====
-- Coin award sound (same source as KillRewardClient: clone SoundService.CoinReward into the SFX group).
local function playCoinReward()
	local tmpl = SoundService:FindFirstChild("CoinReward")
	if not tmpl or not tmpl:IsA("Sound") then return end
	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
		if s then s:Destroy() end
	end)
end

-- Big centered on-screen text that drifts UP and fades out, e.g. "CODE CLAIMED! [+1,000 COINS]".
-- Lives in its own ScreenGui so it's independent of the Settings menu (it shows even after the menu
-- closes). Gold FredokaOne with a black stroke, matching the game's reward styling.
local function showClaimText(amount, currency)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CodeClaimFX"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.fromScale(0.6, 0.1)
	label.BackgroundTransparency = 1
	label.Text = "CODE CLAIMED! [+" .. commas(amount) .. " " .. ((currency == "fireworks") and "FIREWORKS" or "COINS") .. "]"
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	local okFont = pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	end)
	if not okFont then label.Font = Enum.Font.FredokaOne end
	label.Parent = gui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 48
	constraint.Parent = label

	-- Timing: hold the text fully visible for HOLD seconds so it's comfortably readable, THEN drift it
	-- up over RISE_TIME while fading out. Total on-screen time = HOLD + RISE_TIME.
	local RISE = 0.12            -- how far it drifts up, as a fraction of screen height
	local HOLD = 1.6             -- seconds to sit still and fully visible before drifting/fading
	local RISE_TIME = 1.8        -- seconds for the upward drift + fade-out
	task.delay(HOLD, function()
		if not label.Parent then return end
		local moveInfo = TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, moveInfo, { Position = UDim2.fromScale(0.5, 0.4 - RISE) }):Play()
		local fade = TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(HOLD + RISE_TIME + 0.15, function() if gui then gui:Destroy() end end)
end

-- ===== tween feedback (matches the other buttons) =====
local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.93
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function getScale(frame)
	local s = frame:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Scale = 1; s.Parent = frame end
	return s
end
local function tweenTo(frame, scale)
	TweenService:Create(getScale(frame), TWEEN_INFO, { Scale = scale }):Play()
end

-- Resolve the Code row's pieces inside a Settings GUI copy. Structure (from the row):
--   Code (Frame)
--     CodeInput (TextBox)            -- the typed code
--     Buttons.ConfirmButton (ImageButton)   -- the green CLAIM button
--       TextLabel ("CLAIM")  + nested TextLabel (drop-shadow duplicate)
local function resolveRow(settingsGui)
	local holder = settingsGui:FindFirstChild("HolderFrame")
	local settings = holder and holder:FindFirstChild("Settings")
	local scrolling = settings and settings:FindFirstChild("ScrollingFrame")
	local code = scrolling and scrolling:FindFirstChild("Code")
	if not code then return nil end
	local box = code:FindFirstChild("CodeInput")
	local buttons = code:FindFirstChild("Buttons")
	local claimBtn = buttons and buttons:FindFirstChild("ConfirmButton")
	if not box or not claimBtn then return nil end
	return { code = code, box = box, claimBtn = claimBtn }
end

-- set the CLAIM button's label text (handles the layered label + its nested drop-shadow duplicate)
local function setClaimText(claimBtn, text, color)
	for _, lbl in ipairs(claimBtn:GetDescendants()) do
		if lbl:IsA("TextLabel") then
			lbl.Text = text
			if color then lbl.TextColor3 = color end
		end
	end
end

local DEFAULT_CLAIM_TEXT = "CLAIM"
local DEFAULT_CLAIM_COLOR = Color3.fromRGB(255, 255, 255)

-- flash a short status message on the CLAIM button, then restore it to "CLAIM". A token guards against
-- overlapping flashes (a second redeem before the first's restore fires).
local flashToken = 0
local function flash(claimBtn, text, color)
	flashToken += 1
	local myToken = flashToken
	setClaimText(claimBtn, text, color)
	task.delay(1.6, function()
		if myToken == flashToken then
			setClaimText(claimBtn, DEFAULT_CLAIM_TEXT, DEFAULT_CLAIM_COLOR)
		end
	end)
end

-- the row pieces we last bound (so the RedeemResult handler can flash the right button + clear the box)
local bound = nil

local function bindRow(settingsGui)
	local row = resolveRow(settingsGui)
	if not row then return end
	bound = row
	local claimBtn, box = row.claimBtn, row.box

	-- bind click/tween ONCE per button instance (a re-cloned Settings GUI gets a fresh button)
	if claimBtn:GetAttribute("CodeBound") then return end
	claimBtn:SetAttribute("CodeBound", true)
	claimBtn.Active = true
	claimBtn.AutoButtonColor = false
	getScale(claimBtn)

	claimBtn.MouseEnter:Connect(function()
		if UISounds then pcall(function() UISounds.play("hover") end) end
		tweenTo(claimBtn, HOVER_SCALE)
	end)
	claimBtn.MouseLeave:Connect(function() tweenTo(claimBtn, 1) end)
	claimBtn.MouseButton1Down:Connect(function() tweenTo(claimBtn, PRESS_SCALE) end)
	claimBtn.MouseButton1Up:Connect(function() tweenTo(claimBtn, HOVER_SCALE) end)

	local function submit()
		if UISounds then pcall(function() UISounds.click() end) end
		tweenTo(claimBtn, PRESS_SCALE); task.delay(0.1, function() tweenTo(claimBtn, 1) end)
		local text = box.Text or ""
		if text:gsub("%s+", "") == "" then
			flash(claimBtn, "ENTER A CODE", Color3.fromRGB(255, 210, 90))
			return
		end
		RedeemCode:FireServer(text)
	end

	claimBtn.MouseButton1Click:Connect(submit)
	-- also let Enter in the textbox submit
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then submit() end
	end)
end

-- ===== server reply =====
RedeemResult.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or not bound then return end
	local claimBtn, box = bound.claimBtn, bound.box
	if data.ok then
		-- Success: the CLAIM button stays "CLAIM" (no amount shown on it). Instead show the on-screen
		-- floating "CODE CLAIMED! [+N COINS]" text, play the coin sound, pop instant confetti, and clear
		-- the input box back to its default placeholder state.
		if UISounds then pcall(function() UISounds.play("select") end) end
		playCoinReward()
		showClaimText(data.amount or 0, data.currency)
		if Confetti then pcall(function() Confetti.Emit(2) end) end
		if box then
			box.Text = ""               -- clear the typed code
			pcall(function() box:ReleaseFocus() end)  -- return to default (shows placeholder again)
		end
	else
		if UISounds then pcall(function() UISounds.error() end) end
		local msg = "INVALID CODE"
		if data.reason == "already" then msg = "ALREADY USED"
		elseif data.reason == "empty" then msg = "ENTER A CODE" end
		flash(claimBtn, msg, Color3.fromRGB(255, 120, 120))
	end
end)

-- bind the current Settings GUI + any future copy (respawn re-clone)
local existing = pg:FindFirstChild("Settings")
if existing then bindRow(existing) end
pg.ChildAdded:Connect(function(child)
	if child.Name == "Settings" and child:IsA("ScreenGui") then
		task.defer(bindRow, child)
	end
end)
