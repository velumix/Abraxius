-- AdCoinRewardClient: when the local player completes a Watch-Ad coin reward, play the coin-reward
-- sound and show a floating "+N COINS" notification. Driven by the server's AdCoinReward remote (fired
-- to the buyer with the coin amount on a granted ad receipt). Purely cosmetic feedback -- the coins
-- themselves are granted server-side in MatchManager. Mirrors the CodeRedeemClient reward feedback so
-- the styling/sound match the rest of the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local AdCoinReward = Remotes:WaitForChild("AdCoinReward")

-- optional shared UI sounds (guarded so a missing module never errors)
local UISounds
pcall(function() UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5)) end)

-- format a number with thousands separators (1000 -> "1,000")
local function commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- coin award sound: clone SoundService.CoinReward into the SFX group and play it (same source the
-- code-redeem + kill-reward feedback uses), then clean up the clone after it finishes.
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

-- big centered on-screen text that holds, then drifts up and fades out: "+N COINS". Lives in its own
-- ScreenGui so it's independent of any menu. Gold FredokaOne with a black stroke (game reward styling).
local function showRewardText(amount)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AdCoinRewardFX"
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
	label.Text = "+" .. commas(amount) .. " COINS"
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

	local RISE = 0.12       -- how far it drifts up (fraction of screen height)
	local HOLD = 1.6        -- seconds to sit fully visible before drifting/fading
	local RISE_TIME = 1.8   -- seconds for the upward drift + fade-out
	task.delay(HOLD, function()
		if not label.Parent then return end
		local moveInfo = TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, moveInfo, { Position = UDim2.fromScale(0.5, 0.4 - RISE) }):Play()
		local fadeInfo = TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(HOLD + RISE_TIME + 0.15, function() if gui then gui:Destroy() end end)
end

AdCoinReward.OnClientEvent:Connect(function(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	if UISounds then pcall(function() UISounds.play("select") end) end
	playCoinReward()
	showRewardText(amount)
end)

print("[AdCoinRewardClient] ready (coin sound + floating +Coins on ad reward)")
