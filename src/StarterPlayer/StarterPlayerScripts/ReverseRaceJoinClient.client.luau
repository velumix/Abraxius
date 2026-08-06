-- ReverseRaceJoinClient: shows a mid-round "Join as Hunter?" prompt to lobby players when the Reverse
-- Race server offers them a late join (OfferJoinReverseRace). Accepting fires JoinReverseRaceResponse so
-- the server arms them into the current hunt. Self-contained GUI (no pre-authored ScreenGui needed);
-- mirrors the JoinAsSeeker prompt's show/hide + auto-close behavior.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local OfferJoin = Remotes:WaitForChild("OfferJoinReverseRace")
local JoinResponse = Remotes:WaitForChild("JoinReverseRaceResponse")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")

local okSounds, UISounds = pcall(function()
	return require(ReplicatedStorage:WaitForChild("UISounds"))
end)
local function playSound(name)
	if okSounds and UISounds and UISounds.play then
		pcall(UISounds.play, name)
	end
end

local AUTO_CLOSE = 10
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local gui = Instance.new("ScreenGui")
gui.Name = "ReverseRaceJoin"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 25
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.42, 0)
card.Size = UDim2.new(0, 380, 0, 210)
card.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
card.BackgroundTransparency = 0.05
card.Parent = gui
local cardCorner = Instance.new("UICorner"); cardCorner.CornerRadius = UDim.new(0, 16); cardCorner.Parent = card
local cardStroke = Instance.new("UIStroke"); cardStroke.Color = Color3.fromRGB(255, 215, 90); cardStroke.Thickness = 3; cardStroke.Parent = card
local scale = Instance.new("UIScale"); scale.Parent = card

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 22)
title.Size = UDim2.new(1, -30, 0, 42)
title.FontFace = FONT
title.RichText = true
title.Text = 'Join the <font color="rgb(255,215,90)">Reverse Race</font>?'
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Parent = card
local titleC = Instance.new("UITextSizeConstraint"); titleC.MaxTextSize = 26; titleC.Parent = title

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.new(0.5, 0, 0, 70)
sub.Size = UDim2.new(1, -44, 0, 26)
sub.FontFace = FONT
sub.Text = "Hop in as a Hunter and catch the hider!"
sub.TextColor3 = Color3.fromRGB(210, 210, 220)
sub.TextScaled = true
sub.Parent = card
local subC = Instance.new("UITextSizeConstraint"); subC.MaxTextSize = 16; subC.Parent = sub

local joinBtn = Instance.new("TextButton")
joinBtn.Name = "Join"
joinBtn.AnchorPoint = Vector2.new(0.5, 1)
joinBtn.Position = UDim2.new(0.5, 0, 1, -48)
joinBtn.Size = UDim2.new(0, 210, 0, 54)
joinBtn.BackgroundColor3 = Color3.fromRGB(70, 180, 95)
joinBtn.AutoButtonColor = true
joinBtn.FontFace = FONT
joinBtn.Text = "JOIN"
joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
joinBtn.TextScaled = true
joinBtn.Active = true
joinBtn.Parent = card
local jC = Instance.new("UICorner"); jC.CornerRadius = UDim.new(0, 10); jC.Parent = joinBtn
local jS = Instance.new("UIStroke"); jS.Color = Color3.fromRGB(255, 255, 255); jS.Thickness = 2; jS.Transparency = 0.6; jS.Parent = joinBtn
local jT = Instance.new("UITextSizeConstraint"); jT.MaxTextSize = 22; jT.Parent = joinBtn

local declineBtn = Instance.new("TextButton")
declineBtn.Name = "Decline"
declineBtn.AnchorPoint = Vector2.new(0.5, 1)
declineBtn.Position = UDim2.new(0.5, 0, 1, -14)
declineBtn.Size = UDim2.new(0, 220, 0, 26)
declineBtn.BackgroundTransparency = 1
declineBtn.FontFace = FONT
declineBtn.Text = "No thanks (10s)"
declineBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
declineBtn.TextScaled = true
declineBtn.Active = true
declineBtn.Parent = card
local dT = Instance.new("UITextSizeConstraint"); dT.MaxTextSize = 14; dT.Parent = declineBtn

local open = false
local animToken = 0
local timerToken = 0

local function hide()
	if not open then return end
	open = false
	animToken += 1
	timerToken += 1
	local myToken = animToken
	local tw = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.7 })
	tw.Completed:Once(function()
		if myToken == animToken then
			gui.Enabled = false
			scale.Scale = 1
		end
	end)
	tw:Play()
end

local function startCountdown()
	timerToken += 1
	local myToken = timerToken
	local remaining = AUTO_CLOSE
	declineBtn.Text = "No thanks (" .. remaining .. "s)"
	task.spawn(function()
		while remaining > 0 do
			task.wait(1)
			if myToken ~= timerToken then return end
			remaining -= 1
			declineBtn.Text = "No thanks (" .. remaining .. "s)"
		end
		if myToken ~= timerToken or not open then return end
		JoinResponse:FireServer(false)
		playSound("close")
		hide()
	end)
end

local function show()
	if open then return end
	open = true
	animToken += 1
	scale.Scale = 0.7
	gui.Enabled = true
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	playSound("select")
	startCountdown()
end

local function accept()
	if not open then return end
	playSound("select")
	JoinResponse:FireServer(true)
	hide()
end

local function decline()
	if not open then return end
	playSound("close")
	JoinResponse:FireServer(false)
	hide()
end

joinBtn.Activated:Connect(accept)
joinBtn.MouseButton1Click:Connect(accept)
declineBtn.Activated:Connect(decline)
declineBtn.MouseButton1Click:Connect(decline)
joinBtn.MouseEnter:Connect(function() playSound("hover") end)

-- Server controls the prompt: fired with no arg (or true) to SHOW, or false to HIDE/dismiss.
OfferJoin.OnClientEvent:Connect(function(shouldShow)
	if shouldShow == false then
		hide()
	else
		show()
	end
end)

-- Auto-dismiss once the server actually arms us into the hunt (announces our Seeker role).
RoleAnnounce.OnClientEvent:Connect(function(role)
	if open and role == "Seeker" then
		hide()
	end
end)
