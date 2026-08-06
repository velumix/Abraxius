-- WinSequenceClient: the end-of-round celebration. When the server fires WinSequence, we show a big
-- VICTORY!/DEFEAT banner over the (already fading-in) black screen, play the Victory/Defeat sound,
-- and rain confetti for winners. The server handles the black fade (ScreenFade) and the teleport to
-- the lobby underneath it; this script is purely the banner + confetti + sound layer on top.
--
-- Server fires: WinSequence:FireClient(player, { won = bool, winner = "Seeker"|"Hider", headline = text, hold = seconds })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local WinSequence = Remotes:WaitForChild("WinSequence")

local GLOBAL_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local WIN_COLOR = Color3.fromRGB(255, 215, 70)    -- gold
local LOSS_COLOR = Color3.fromRGB(200, 80, 80)     -- muted red
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 120), Color3.fromRGB(90, 150, 255),
	Color3.fromRGB(255, 215, 70), Color3.fromRGB(220, 120, 255), Color3.fromRGB(120, 240, 240),
}

-- ===== build the banner GUI (self-contained, sits above the black ScreenFadeGui at DisplayOrder 150) =====
local gui = Instance.new("ScreenGui")
gui.Name = "WinBannerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 160
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = pg

-- confetti layer (behind the text)
local confettiLayer = Instance.new("Frame")
confettiLayer.Name = "Confetti"
confettiLayer.BackgroundTransparency = 1
confettiLayer.Size = UDim2.fromScale(1, 1)
confettiLayer.ClipsDescendants = true
confettiLayer.ZIndex = 1
confettiLayer.Parent = gui

-- the big headline (VICTORY! / DEFEAT)
local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.fromScale(0.8, 0.18)
title.BackgroundTransparency = 1
title.FontFace = GLOBAL_FONT
title.Text = "VICTORY!"
title.TextScaled = true
title.TextColor3 = WIN_COLOR
title.ZIndex = 5
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 4
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Parent = title
title.Parent = gui

-- subtitle (the headline text, e.g. "Hiders Win!" / "<name> has won the round!")
local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.57)
subtitle.Size = UDim2.fromScale(0.7, 0.06)
subtitle.BackgroundTransparency = 1
subtitle.FontFace = GLOBAL_FONT
subtitle.Text = ""
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
subtitle.ZIndex = 5
local subStroke = Instance.new("UIStroke")
subStroke.Thickness = 3
subStroke.Color = Color3.fromRGB(0, 0, 0)
subStroke.Parent = subtitle
subtitle.Parent = gui

-- keep the title from being too tall on wide screens
local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MaxTextSize = 90
titleConstraint.Parent = title
local subConstraint = Instance.new("UITextSizeConstraint")
subConstraint.MaxTextSize = 28
subConstraint.Parent = subtitle

-- ===== confetti =====
local confettiActive = false
local function spawnConfettiPiece()
	local piece = Instance.new("Frame")
	piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
	piece.BorderSizePixel = 0
	local size = math.random(8, 16)
	piece.Size = UDim2.fromOffset(size, size)
	piece.Rotation = math.random(0, 360)
	piece.ZIndex = 2
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	local startX = math.random(0, 100) / 100
	piece.Position = UDim2.new(startX, 0, -0.05, 0)
	piece.Parent = confettiLayer

	local fallTime = math.random(18, 32) / 10  -- 1.8 - 3.2s
	local endX = math.clamp(startX + (math.random(-20, 20) / 100), 0, 1)
	local tween = TweenService:Create(piece, TweenInfo.new(fallTime, Enum.EasingStyle.Linear), {
		Position = UDim2.new(endX, 0, 1.1, 0),
		Rotation = piece.Rotation + math.random(-360, 360),
	})
	tween:Play()
	tween.Completed:Connect(function() piece:Destroy() end)
end

local function runConfetti(duration)
	confettiActive = true
	local elapsed = 0
	task.spawn(function()
		while confettiActive and elapsed < duration do
			for _ = 1, 4 do spawnConfettiPiece() end
			task.wait(0.08)
			elapsed += 0.08
		end
	end)
end

local function stopConfetti()
	confettiActive = false
end

-- ===== sound =====
local function playSound(name)
	local t = SoundService:FindFirstChild(name)
	if not t then return end
	local s = t:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 4) + 0.3, function() s:Destroy() end)
end

-- ===== the banner sequence =====
local token = 0
local function showBanner(data)
	token += 1
	local myToken = token
	data = data or {}
	local won = data.won and true or false
	local hold = data.hold or 3

	title.Text = won and "VICTORY!" or "DEFEAT"
	title.TextColor3 = won and WIN_COLOR or LOSS_COLOR
	subtitle.Text = data.headline or ""

	-- slam-in: start big + transparent, settle to normal
	gui.Enabled = true
	title.TextTransparency = 1
	subtitle.TextTransparency = 1
	titleStroke.Transparency = 1
	subStroke.Transparency = 1
	title.Size = UDim2.fromScale(1.1, 0.26)

	playSound(won and "Victory" or "Defeat")

	TweenService:Create(title, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.8, 0.18),
		TextTransparency = 0,
	}):Play()
	TweenService:Create(titleStroke, TweenInfo.new(0.35), { Transparency = 0 }):Play()
	task.delay(0.25, function()
		if myToken ~= token then return end
		TweenService:Create(subtitle, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		TweenService:Create(subStroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
	end)

	if won then runConfetti(hold) end

	-- fade the banner out near the end of the hold, then hide
	task.delay(hold, function()
		if myToken ~= token then return end
		stopConfetti()
		TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(titleStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		TweenService:Create(subtitle, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(subStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.45, function()
			if myToken ~= token then return end
			gui.Enabled = false
		end)
	end)
end

WinSequence.OnClientEvent:Connect(showBanner)
