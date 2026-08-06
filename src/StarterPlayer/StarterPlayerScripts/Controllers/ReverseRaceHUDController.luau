-- Reverse Race HUD: role-specific phase banners + a phase countdown timer, driven by
-- the server's ReverseRaceHUD RemoteEvent. HIDE's timer stays owned by TimerClient; this
-- covers PREVIEW/HUNT (and the being-hunted banner) plus first-time onboarding text.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReverseRaceConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ReverseRaceConfig"))

local ReverseRaceHUDController = Knit.CreateController({
	Name = "ReverseRaceHUDController",
})

local DEFAULT_LIGHTING_PRESET = "DefaultLighting"
local HUNTER_ROOM_LIGHTING_PRESET = "HunterRoomLighting"
local CLIENT_LIGHTING_CLONE_ATTRIBUTE = "ClientLightingPresetClone"

local LIGHTING_PROPERTIES = {
	"Ambient",
	"Brightness",
	"ClockTime",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
	"FogStart",
	"GeographicLatitude",
	"GlobalShadows",
	"OutdoorAmbient",
	"ShadowSoftness",
	"TimeOfDay",
}

local LIGHTING_OBJECT_CLASSES = {
	Atmosphere = true,
	Sky = true,
	BloomEffect = true,
	BlurEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	SunRaysEffect = true,
}

local function getLightingPreset(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local lightingFolder = assets and assets:FindFirstChild("Lighting")
	local preset = lightingFolder and lightingFolder:FindFirstChild(name)
	return (preset and preset:IsA("Folder")) and preset or nil
end

local function clearLightingObjects()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:GetAttribute(CLIENT_LIGHTING_CLONE_ATTRIBUTE) == true then
			child:Destroy()
		elseif LIGHTING_OBJECT_CLASSES[child.ClassName] then
			child:Destroy()
		end
	end
end

local function applyLightingPreset(name)
	local preset = getLightingPreset(name)
	if not preset then
		warn("[ReverseRaceHUDController] missing lighting preset: " .. tostring(name))
		return
	end

	for _, propertyName in ipairs(LIGHTING_PROPERTIES) do
		local value = preset:GetAttribute(propertyName)
		if value ~= nil then
			pcall(function()
				Lighting[propertyName] = value
			end)
		end
	end

	clearLightingObjects()
	for _, child in ipairs(preset:GetChildren()) do
		if LIGHTING_OBJECT_CLASSES[child.ClassName] then
			local clone = child:Clone()
			clone:SetAttribute(CLIENT_LIGHTING_CLONE_ATTRIBUTE, true)
			clone.Parent = Lighting
		end
	end
end

function ReverseRaceHUDController:KnitStart()
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
	local hudRemote = remotes:WaitForChild("ReverseRaceHUD")

	applyLightingPreset(DEFAULT_LIGHTING_PRESET)

	-- The shared Hud.Main.Top.Timer handles the in-round countdown display.
	local hud = pg:WaitForChild("Hud")
	local roundTimer = hud:WaitForChild("Main"):WaitForChild("Top"):WaitForChild("Timer")
	local roundTimerTitle = roundTimer:WaitForChild("Announce")
	local roundTimerLabel = roundTimer:WaitForChild("Timer")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ReverseRaceHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = pg

	local bannerHolder = Instance.new("Frame")
	bannerHolder.Name = "Banner"
	bannerHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerHolder.Position = UDim2.new(0.5, 0, 0.3, 0)
	bannerHolder.Size = UDim2.new(0.9, 0, 0, 130)
	bannerHolder.BackgroundTransparency = 1
	bannerHolder.Visible = false
	bannerHolder.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.Text = ""
	title.Parent = bannerHolder
	local titleC = Instance.new("UITextSizeConstraint")
	titleC.MaxTextSize = 46
	titleC.Parent = title

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Position = UDim2.new(0, 0, 0, 66)
	sub.Size = UDim2.new(1, 0, 0, 56)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.TextColor3 = Color3.fromRGB(235, 235, 235)
	sub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	sub.TextStrokeTransparency = 0.3
	sub.TextWrapped = true
	sub.TextScaled = true
	sub.Text = ""
	sub.Parent = bannerHolder
	local subC = Instance.new("UITextSizeConstraint")
	subC.MaxTextSize = 20
	subC.Parent = sub

	-- Hunter lives: 3 hearts in a UIListLayout; a lost life shows the broken-heart icon.
	local HEART_ICON = "rbxassetid://124916248857231"
	local BROKEN_ICON = "rbxassetid://109111589672848"
	local livesFrame = Instance.new("Frame")
	livesFrame.Name = "Lives"
	livesFrame.AnchorPoint = Vector2.new(0.5, 1)
	livesFrame.Position = UDim2.new(0.5, 0, 1, -24)
	livesFrame.Size = UDim2.fromOffset(180, 52)
	livesFrame.BackgroundTransparency = 1
	livesFrame.Visible = false
	livesFrame.Parent = gui
	local livesLayout = Instance.new("UIListLayout")
	livesLayout.FillDirection = Enum.FillDirection.Horizontal
	livesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	livesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	livesLayout.Padding = UDim.new(0, 8)
	livesLayout.Parent = livesFrame
	local hearts = {}
	for i = 1, 3 do
		local heart = Instance.new("ImageLabel")
		heart.Name = "Heart" .. i
		heart.LayoutOrder = i
		heart.Size = UDim2.fromOffset(48, 48)
		heart.BackgroundTransparency = 1
		heart.Image = HEART_ICON
		heart.Parent = livesFrame
		hearts[i] = heart
	end
	local function setLives(n, maxN)
		maxN = maxN or 3
		for i = 1, 3 do
			if i <= maxN then
				hearts[i].Visible = true
				hearts[i].Image = (i <= n) and HEART_ICON or BROKEN_ICON
			else
				hearts[i].Visible = false
			end
		end
		livesFrame.Visible = true
	end

	local function fmtTime(t)
		t = math.max(0, math.ceil(t or 0))
		return string.format("%d:%02d", math.floor(t / 60), t % 60)
	end

	local deadline = nil
	RunService.Heartbeat:Connect(function()
		if deadline then
			local left = deadline - os.clock()
			if left <= 0 then
				roundTimer.Visible = false
				deadline = nil
			else
				roundTimerLabel.Text = fmtTime(left)
			end
		end
	end)

	local function setTimer(timeLeft, title)
		if title ~= nil then
			roundTimerTitle.Text = title
		end
		if timeLeft and timeLeft > 0 then
			deadline = os.clock() + timeLeft
			roundTimerLabel.Text = fmtTime(timeLeft)
			roundTimer.Visible = true
		else
			deadline = nil
			roundTimer.Visible = false
		end
	end

	local bannerToken = 0
	local function showBanner(titleText, subText, holdTime)
		bannerToken += 1
		local myToken = bannerToken
		title.Text = titleText or ""
		sub.Text = subText or ""
		bannerHolder.Visible = true
		title.TextTransparency = 1
		title.TextStrokeTransparency = 1
		sub.TextTransparency = 1
		sub.TextStrokeTransparency = 1
		local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
		TweenService:Create(title, ti, { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
		TweenService:Create(sub, ti, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
		task.delay(holdTime or 3, function()
			if myToken ~= bannerToken then
				return
			end
			TweenService:Create(title, ti, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(sub, ti, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.3, function()
				if myToken == bannerToken then
					bannerHolder.Visible = false
				end
			end)
		end)
	end

	-- Placeholder Reverse Race SFX. Built once from ReverseRaceConfig.SOUNDS; a blank SoundId plays
	-- nothing, so this is ready for real asset ids to be dropped into the config later.
	local sfxGroup = SoundService:FindFirstChild("SFX")
	local soundVolumes = {
		LoseLife = 1,
		LoseAllLives = 1,
	}
	local rrSounds = {}
	for name, id in pairs(ReverseRaceConfig.SOUNDS or {}) do
		local s = Instance.new("Sound")
		s.Name = "RR_" .. name
		s.SoundId = id
		s.Volume = soundVolumes[name] or s.Volume
		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			s.SoundGroup = sfxGroup
		end
		s.Parent = SoundService
		rrSounds[name] = s
	end
	local function playRRSound(name)
		local s = rrSounds[name]
		if s and s.SoundId ~= "" then
			s.TimePosition = 0
			s:Play()
		end
	end

	hudRemote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.sound then
			playRRSound(data.sound)
		end
		if data.hunterRoomLighting ~= nil then
			applyLightingPreset(if data.hunterRoomLighting then HUNTER_ROOM_LIGHTING_PRESET else DEFAULT_LIGHTING_PRESET)
		end
		if data.banner then
			showBanner(data.banner, data.sub, data.hold)
		end
		if data.timeLeft ~= nil then
			setTimer(data.timeLeft, data.timerTitle)
		end
		if data.clearTimer then
			setTimer(0)
		end
		if data.lives ~= nil then
			setLives(data.lives, data.maxLives)
		end
		if data.hideLives then
			livesFrame.Visible = false
		end
	end)

	print("[ReverseRaceHUDController] ready")
end

return ReverseRaceHUDController
