-- HUDCoinClient: drives the from-scratch bottom-left CoinSection (CoinIcon + Amount + Plus).
-- Amount updates from the server's CoinUpdate; the plus opens the shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local CoinUpdate = Remotes:WaitForChild("CoinUpdate")

local pg = player:WaitForChild("PlayerGui")
local hud = pg:WaitForChild("Hud")
local currency = hud:WaitForChild("RegularCurrency")
local moneyLabel = currency:WaitForChild("Currency")
local moneyTop = moneyLabel:WaitForChild("Top")  -- overlay layer; keep its text in sync
local plusButton = currency:WaitForChild("BuyButton")

-- ===== hover/press tween (matches the game's other buttons) =====
local TweenService = game:GetService("TweenService")
local HOVER_SCALE = 1.08
local PRESS_SCALE = 0.92
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function getScale(frame)
	local s = frame:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Scale = 1; s.Parent = frame end
	return s
end
local function tweenTo(frame, scale)
	TweenService:Create(getScale(frame), TWEEN_INFO, { Scale = scale }):Play()
end

plusButton.ResampleMode = Enum.ResamplerMode.Pixelated
plusButton.AutoButtonColor = false
getScale(plusButton)

plusButton.MouseEnter:Connect(function() tweenTo(plusButton, HOVER_SCALE) end)
plusButton.MouseLeave:Connect(function() tweenTo(plusButton, 1) end)
plusButton.MouseButton1Down:Connect(function() tweenTo(plusButton, PRESS_SCALE) end)
plusButton.MouseButton1Up:Connect(function() tweenTo(plusButton, HOVER_SCALE) end)

-- format with thousands separators (12345 -> "12,345")
local function withCommas(n)
	local s = tostring(math.floor(n))
	while true do
		local new, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = new
		if count == 0 then break end
	end
	return s
end

local function setAmount(n)
	local text = "$" .. withCommas(n or 0)
	moneyLabel.Text = text
	moneyTop.Text = text  -- keep the overlay layer in sync
end

-- Responsive text size. We turned OFF TextScaled on the Money label so AutomaticSize.X actually grows
-- the label with the number (with TextScaled on, the box stays fixed and the text just shrinks -- which
-- is why the +button never moved). With TextScaled off we must pick a TextSize ourselves; tie it to the
-- label's pixel HEIGHT so it stays readable on every screen size. The Top overlay tracks the same size.
local function syncTextSize()
	local h = moneyLabel.AbsoluteSize.Y
	if h <= 0 then return end
	local size = math.clamp(math.floor(h * 0.85), 8, 64)
	moneyLabel.TextSize = size
	moneyTop.TextSize = size
end
syncTextSize()
moneyLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncTextSize)

CoinUpdate.OnClientEvent:Connect(function(balance)
	setAmount(balance)
end)

-- Close any other open panels before opening the shop, so they don't overlap. Mirrors the
-- close-event pattern the HUD bar buttons use (each panel exposes a Close* event or .Enabled flag).
local function closeOtherPanels()
	-- settings (new consolidated Settings UI)
	local settingsGui = pg:FindFirstChild("Settings")
	local settingsClose = settingsGui and settingsGui:FindFirstChild("CloseSettings")
	if settingsClose then settingsClose:Fire() end
	-- crate shop (CratesShop)
	local crateGui = pg:FindFirstChild("CratesShop")
	local crateClose = crateGui and crateGui:FindFirstChild("CloseCrateShop")
	if crateClose then crateClose:Fire() end
	-- crates popup overlay (created by the HUD bar)
	local popupGui = pg:FindFirstChild("PopupGui")
	local popup = popupGui and popupGui:FindFirstChild("Popup")
	if popup then popup.Visible = false end
	-- seeker queue shop
	local sqGui = pg:FindFirstChild("SeekerQueueGui")
	local sqClose = sqGui and sqGui:FindFirstChild("CloseSeekerQueue")
	if sqClose then sqClose:Fire() end
	-- inventory
	local invGui = pg:FindFirstChild("Inventory")
	if invGui then invGui.Enabled = false end
	-- results screen (new Results GUI toggles via .Enabled)
	local results = pg:FindFirstChild("Results")
	if results then results.Enabled = false end
end

-- plus closes whatever's open, then opens the shop directly at the coin-buying section
plusButton.MouseButton1Click:Connect(function()
	-- quick press bounce so touch users (no hover) still get feedback
	tweenTo(plusButton, PRESS_SCALE)
	task.delay(0.1, function() tweenTo(plusButton, 1) end)
	closeOtherPanels()
	local shopGui = pg:FindFirstChild("Shop")
	local openEvent = shopGui and shopGui:FindFirstChild("OpenShop")
	if openEvent then openEvent:Fire("coins") end
end)
