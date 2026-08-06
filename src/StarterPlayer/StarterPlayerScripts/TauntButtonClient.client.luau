local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ManualTaunt = Remotes:WaitForChild("ManualTaunt")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")

local COOLDOWN = 5

local slots = pg:WaitForChild("Hud"):WaitForChild("BottomButtons")
local btn = slots:FindFirstChild("TauntButton", true)
if not btn then
	repeat task.wait() ; btn = slots:FindFirstChild("TauntButton", true) until btn
end

local myRole = player:GetAttribute("Role")
local inRound = player:GetAttribute("InMatch") == true
local function canTaunt()
	-- Reverse Race's active target is still a hider, but the mode drops the
	-- standard InRound HUD state and exposes taunt/freecam eligibility through
	-- ReverseRaceFreeCam instead.
	return (inRound and myRole == "Hider") or player:GetAttribute("ReverseRaceFreeCam") == true
end
local function updateTauntVisibility()
	btn.Visible = canTaunt()
end

local hud = pg:WaitForChild("Hud")
local freecamScript = pg:WaitForChild("FreecamEngine"):WaitForChild("FreecamScript")
local function freecamActive()
	return freecamScript:GetAttribute("FreecamEnabled") == true
end

local hudHidden = {}
local hidingForFreecam = false
local function hideHudExceptTaunt()
	for _, child in ipairs(hud:GetChildren()) do
		if child:IsA("GuiObject") and child ~= slots and child.Visible then
			hudHidden[child] = true
			child.Visible = false
		end
	end
	for _, child in ipairs(slots:GetChildren()) do
		if child:IsA("GuiObject") and child ~= btn and child.Visible then
			hudHidden[child] = true
			child.Visible = false
		end
	end
end
local function beginFreecamHud()
	hidingForFreecam = true
	hideHudExceptTaunt()
end
local function endFreecamHud()
	hidingForFreecam = false
	for child in pairs(hudHidden) do
		if child and child.Parent then
			child.Visible = true
		end
	end
	table.clear(hudHidden)
	updateTauntVisibility()
end

freecamScript:GetAttributeChangedSignal("FreecamEnabled"):Connect(function()
	if freecamActive() then
		beginFreecamHud()
	else
		endFreecamHud()
	end
end)

RunService.Heartbeat:Connect(function()
	if not freecamActive() then return end
	if not hidingForFreecam then
		beginFreecamHud()
	else
		hideHudExceptTaunt()
	end
end)

local function setRole(role)
	myRole = role
	updateTauntVisibility()
end
local function setInRound(active)
	inRound = active and true or false
	if not inRound then myRole = nil end
	updateTauntVisibility()
end

RoleAnnounce.OnClientEvent:Connect(setRole)
InRound.OnClientEvent:Connect(setInRound)

player:GetAttributeChangedSignal("Role"):Connect(function()
	setRole(player:GetAttribute("Role"))
end)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	setInRound(player:GetAttribute("InMatch") == true)
end)
player:GetAttributeChangedSignal("ReverseRaceFreeCam"):Connect(updateTauntVisibility)

updateTauntVisibility()

local UISounds
pcall(function() UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5)) end)

local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local emulatingTouch = game:GetService("RunService"):IsStudio() and UserInputService.TouchEnabled
local isMobile = touchOnly or emulatingTouch
local function setLayered(label, text)
	if not label then return end
	label.Text = text
	local top = label:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then top.Text = text end
end
local keybindLabel = btn:FindFirstChild("Keybind")
if keybindLabel then
	if isMobile then
		keybindLabel.Visible = false
	else
		keybindLabel.Visible = true
		setLayered(keybindLabel, "(Q)")
	end
end

local overlay = Instance.new("Frame")
overlay.Name = "TauntCooldownOverlay"
overlay.AnchorPoint = Vector2.new(0.5, 0)
overlay.Position = UDim2.new(0.5, 0, 0, 0)
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.ClipsDescendants = true
overlay.ZIndex = 50
overlay.Visible = false
overlay.Parent = btn

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.15, 0)
corner.Parent = overlay

local cdText = Instance.new("TextLabel")
cdText.Name = "CountdownText"
cdText.AnchorPoint = Vector2.new(0.5, 0.5)
cdText.Position = UDim2.new(0.5, 0, 0.5, 0)
cdText.Size = UDim2.new(1, 0, 0.6, 0)
cdText.BackgroundTransparency = 1
cdText.Font = Enum.Font.FredokaOne
cdText.TextScaled = true
cdText.TextColor3 = Color3.fromRGB(255, 255, 255)
cdText.TextStrokeTransparency = 0.4
cdText.Text = "5s"
cdText.ZIndex = 51
cdText.Parent = overlay

local onCooldown = false

local function runCooldown()
	onCooldown = true
	overlay.Visible = true
	overlay.BackgroundTransparency = 0.35
	overlay.Position = UDim2.new(0.5, 0, 0, 0)
	overlay.Size = UDim2.new(1, 0, 1, 0)
	cdText.TextTransparency = 0
	cdText.TextStrokeTransparency = 0.4

	local startT = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startT
		local remaining = COOLDOWN - elapsed
		if remaining <= 0 then
			if conn then conn:Disconnect() end
			-- final "fade away downward": slide the overlay down and fade it out
			local slide = TweenService:Create(overlay, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 1, 0),       -- slide off the bottom
				BackgroundTransparency = 1,
			})
			TweenService:Create(cdText, TweenInfo.new(0.25), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			slide:Play()
			slide.Completed:Connect(function()
				overlay.Visible = false
				onCooldown = false
			end)
			return
		end
		cdText.Text = tostring(math.ceil(remaining)) .. "s"
		-- progressively "drain" the overlay downward as the cooldown clears: its top edge moves down
		-- so the dark cover shrinks from the top, revealing the button bottom-up.
		local frac = elapsed / COOLDOWN  -- 0 -> 1
		overlay.Position = UDim2.new(0.5, 0, frac, 0)
		overlay.Size = UDim2.new(1, 0, 1 - frac, 0)
	end)
end

local function tryTaunt()
	-- guard: do nothing if the taunt UI isn't currently available (not a hider in a round) or on cooldown
	if not canTaunt() then return end
	if onCooldown then return end
	if UISounds then pcall(function() UISounds.click() end) end
	ManualTaunt:FireServer()
	runCooldown()
end

btn.MouseButton1Click:Connect(tryTaunt)

local hudGui = btn:FindFirstAncestorWhichIsA("ScreenGui")
if hudGui then
	local gamepadTauntControl = Instance.new("BindableEvent")
	gamepadTauntControl.Name = "GamepadTauntControl"
	gamepadTauntControl.Parent = hudGui
	gamepadTauntControl.Event:Connect(function() tryTaunt() end)
end

if UISounds then
	pcall(function()
		UISounds.bindTween(btn)
		btn.MouseEnter:Connect(function() UISounds.hover() end)
	end)
end

local PIXEL = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local function showRewardPopup(amount)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local worldPos = hrp.Position + Vector3.new(0, 3, 0)

	local anchor = Instance.new("Part")
	anchor.Name = "TauntRewardPopupAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(worldPos)
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.Parent = anchor

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.FontFace = PIXEL
	lbl.Text = "+" .. tostring(amount or 0) .. " COINS"
	lbl.TextColor3 = Color3.fromRGB(255, 215, 90)
	lbl.TextScaled = true
	lbl.Parent = billboard
	local stroke = Instance.new("UIStroke", lbl)
	stroke.Color = Color3.fromRGB(60, 40, 0)
	stroke.Thickness = 2
	local tsc = Instance.new("UITextSizeConstraint", lbl); tsc.MaxTextSize = 22

	local RISE = 4
	local DURATION = 0.9
	local goalCF = CFrame.new(worldPos + Vector3.new(0, RISE, 0))
	local tweenInfo = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, tweenInfo, { CFrame = goalCF }):Play()
	TweenService:Create(lbl, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()
	task.delay(DURATION + 0.1, function()
		if anchor then anchor:Destroy() end
	end)
end

-- play the coin reward sound (same as the obby pad / group reward chest) when the taunt pays out
local function playCoinReward()
	local template = SoundService:FindFirstChild("CoinReward")
	if not template then return end
	local s = template:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end  -- obey the Settings SFX slider
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.5, function()
		if s and s.Parent then s:Destroy() end
	end)
end

-- server confirms a manual taunt actually paid out -> show the floating popup + play the reward sound
ManualTaunt.OnClientEvent:Connect(function(amount)
	showRewardPopup(amount or 10)
	playCoinReward()
end)

-- PC keybind: Q triggers the taunt (matches the "(Q) Taunt" label)
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end  -- ignore when typing in a textbox, etc.
	if input.KeyCode == Enum.KeyCode.Q then
		tryTaunt()
	end
end)

print("[TauntButtonClient] ready")
