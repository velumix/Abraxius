local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FREECAM_ATTRIBUTE = "FreecamEnabled"

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local StateChanged = Remotes:WaitForChild("StateChanged")

local freecamScript = pg:WaitForChild("FreecamEngine"):WaitForChild("FreecamScript")

local buttonGui = pg:WaitForChild("FreecamButton")
local button = buttonGui:WaitForChild("Button")
local title = button:WaitForChild("Title")
local titleTop = title:WaitForChild("Top")
local uiScale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", button)

local isHider = false
local inRound = false
local seekPhase = false
local freecamActive = false

local function eligible()
	-- Reverse Race lets the current target (a frozen hider) free-cam even though it isn't the
	-- HideAndSeek ROUND phase -- signalled by a server-set attribute.
	return (isHider and inRound and seekPhase) or (player:GetAttribute("ReverseRaceFreeCam") == true)
end

local function applyStyle()
	local label = freecamActive and "Exit" or "Free Cam"
	title.Text = label
	titleTop.Text = label
	button.ImageColor3 = freecamActive and Color3.fromRGB(255, 150, 150) or Color3.fromRGB(255, 255, 255)
end

local function setFreecam(on)
	if on == freecamActive then
		return
	end

	freecamScript:SetAttribute(FREECAM_ATTRIBUTE, on)
end

local function deactivateIfIneligible()
	if freecamActive and not eligible() then
		setFreecam(false)
	end
end

local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tween(scale)
	TweenService:Create(uiScale, TWEEN_INFO, { Scale = scale }):Play()
end

freecamScript:GetAttributeChangedSignal(FREECAM_ATTRIBUTE):Connect(function()
	freecamActive = freecamScript:GetAttribute(FREECAM_ATTRIBUTE) == true
	applyStyle()
end)

button.MouseEnter:Connect(function()
	tween(1.06)
end)

button.MouseLeave:Connect(function()
	tween(1)
end)

button.MouseButton1Down:Connect(function()
	tween(0.93)
end)

button.MouseButton1Up:Connect(function()
	tween(1.06)
end)

button.MouseButton1Click:Connect(function()
	tween(0.93)
	task.delay(0.1, function()
		tween(1)
	end)

	if freecamActive then
		setFreecam(false)
	elseif eligible() then
		setFreecam(true)
	end
end)

RoleAnnounce.OnClientEvent:Connect(function(role)
	isHider = (role == "Hider")
	deactivateIfIneligible()
end)

InRound.OnClientEvent:Connect(function(state)
	inRound = (state == true)
	if not inRound then
		isHider = false
	end

	deactivateIfIneligible()
end)

StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.state == nil then
		return
	end

	seekPhase = (data.state == "ROUND")
	deactivateIfIneligible()
end)

player:GetAttributeChangedSignal("ReverseRaceFreeCam"):Connect(deactivateIfIneligible)

local function bindCharacter(char)
	local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			if freecamActive then
				setFreecam(false)
			end
		end)
	end
end

if player.Character then
	task.spawn(bindCharacter, player.Character)
end

player.CharacterAdded:Connect(bindCharacter)

local function hideOtherGuis()
	for _, g in ipairs(pg:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= buttonGui and g.Name ~= "FreecamEngine" and g.Name ~= "CratesOpening" and g.Name ~= "Hud" and g.Enabled then
			g.Enabled = false
		end
	end
end

RunService.Heartbeat:Connect(function()
	if buttonGui.Parent then
		buttonGui.Enabled = freecamActive or eligible()
	end

	if freecamActive then
		UserInputService.MouseIconEnabled = true
		hideOtherGuis()
	end
end)

applyStyle()
