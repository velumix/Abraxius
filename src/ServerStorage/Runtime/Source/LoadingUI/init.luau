local Runner, LoadingManager, TweenService, StarterGui, PlayerGui

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local LightRunner = _G.LightRunner
local BackgroundScale = 20

local LOADING_TIPS = {
	"Tip: Keep an eye out for rare fish near kelp forests.",
	"Tip: Scan creatures to grow your encyclopedia.",
	"Tip: Upgrade gear to dive deeper and longer.",
	"Tip: Some discoveries unlock bonus rewards.",
	"Tip: You can revisit zones to complete achievements.",
}

local TIP_ROTATE_SECONDS = 5
local STATUS_UPDATE_SECONDS = 0.25

local LoadingUIHandler = {
	Tween = TweenInfo.new(0.1),
	Background = TweenInfo.new(10*BackgroundScale,Enum.EasingStyle.Linear,Enum.EasingDirection.In,-1),
	ScreenOrientation = Enum.ScreenOrientation.LandscapeRight,
	OrientationConnections = {},
	CurrentProgress = 0,
	CurrentDescriptor = "Loading",
	Active = false,
}

local function applyOrientation()
	if StarterGui then
		StarterGui.ScreenOrientation = LoadingUIHandler.ScreenOrientation
		pcall(function()
			StarterGui:SetCore("PreferredScreenOrientation", LoadingUIHandler.ScreenOrientation)
		end)
	end

	if PlayerGui then
		PlayerGui.ScreenOrientation = LoadingUIHandler.ScreenOrientation
	end
end

local function isLandscape(orientation)
	return orientation == Enum.ScreenOrientation.LandscapeLeft
		or orientation == Enum.ScreenOrientation.LandscapeRight
end

local function bindOrientationWatchers()
	if StarterGui and not LoadingUIHandler.OrientationConnections.Starter then
		LoadingUIHandler.OrientationConnections.Starter = StarterGui:GetPropertyChangedSignal("ScreenOrientation"):Connect(function()
			if StarterGui.ScreenOrientation ~= LoadingUIHandler.ScreenOrientation then
				applyOrientation()
			end
		end)
	end

	if PlayerGui and not LoadingUIHandler.OrientationConnections.Player then
		LoadingUIHandler.OrientationConnections.Player = PlayerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(function()
			if not isLandscape(PlayerGui.CurrentScreenOrientation) then
				applyOrientation()
			end
		end)
	end

	if not LoadingUIHandler.OrientationConnections.Render then
		LoadingUIHandler.OrientationConnections.Render = RunService.RenderStepped:Connect(function()
			if not StarterGui or not PlayerGui then
				return
			end
			if not isLandscape(PlayerGui.CurrentScreenOrientation) or StarterGui.ScreenOrientation ~= LoadingUIHandler.ScreenOrientation then
				applyOrientation()
			end
		end)
	end
end

local function disconnectOrientationWatchers()
	for key, connection in pairs(LoadingUIHandler.OrientationConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
		LoadingUIHandler.OrientationConnections[key] = nil
	end
end

function LoadingUIHandler:UpdateLoadingBarProgress(DecimalProgress)
	LoadingUIHandler.CurrentProgress = DecimalProgress or 0
	TweenService:Create(LoadingUIHandler.ScreenGui.Background.Bar, LoadingUIHandler.Tween, {
		Size = UDim2.new(DecimalProgress, 0, 0, 5)
	}):Play()
	LoadingUIHandler:UpdateStatusText()
end

function LoadingUIHandler:UpdateLoadingUIToMatchTask(LoadingTask)
	LoadingUIHandler.CurrentDescriptor = (LoadingTask and LoadingTask.Descriptor) or "Loading"
	LoadingUIHandler:UpdateStatusText()
end

function LoadingUIHandler:EnsureStatusLabels()
	local background = LoadingUIHandler.ScreenGui and LoadingUIHandler.ScreenGui:FindFirstChild("Background")
	local infoFrame = background and background:FindFirstChild("Information")
	local infoLabel = infoFrame and infoFrame:FindFirstChild("InformationLabel")

	LoadingUIHandler.InformationLabel = infoLabel
	if not infoFrame or not infoLabel then
		return
	end

	if not infoFrame:FindFirstChild("StatusLabel") then
		local status = Instance.new("TextLabel")
		status.Name = "StatusLabel"
		status.BackgroundTransparency = 1
		status.Size = UDim2.new(1, 0, 0, 18)
		status.Position = UDim2.new(0, 0, 1, 4)
		status.TextColor3 = infoLabel.TextColor3
		status.Font = infoLabel.Font
		status.TextSize = math.max(12, (infoLabel.TextSize or 18) - 4)
		status.TextWrapped = true
		status.TextXAlignment = infoLabel.TextXAlignment
		status.TextYAlignment = Enum.TextYAlignment.Top
		status.Parent = infoFrame
	end

	if not infoFrame:FindFirstChild("TipLabel") then
		local tip = Instance.new("TextLabel")
		tip.Name = "TipLabel"
		tip.BackgroundTransparency = 1
		tip.Size = UDim2.new(1, 0, 0, 18)
		tip.Position = UDim2.new(0, 0, 1, 24)
		tip.TextColor3 = infoLabel.TextColor3
		tip.Font = infoLabel.Font
		tip.TextSize = math.max(12, (infoLabel.TextSize or 18) - 4)
		tip.TextWrapped = true
		tip.TextXAlignment = infoLabel.TextXAlignment
		tip.TextYAlignment = Enum.TextYAlignment.Top
		tip.Parent = infoFrame
	end

	LoadingUIHandler.StatusLabel = infoFrame:FindFirstChild("StatusLabel")
	LoadingUIHandler.TipLabel = infoFrame:FindFirstChild("TipLabel")
end

function LoadingUIHandler:UpdateStatusText()
	local statusLabel = LoadingUIHandler.StatusLabel
	if statusLabel then
		local percent = math.floor((LoadingUIHandler.CurrentProgress or 0) * 100)
		statusLabel.Text = string.format("%d%% complete", percent)
	end
end

function LoadingUIHandler:StartStatusLoops()
	LoadingUIHandler.Active = true
	local tipIndex = 1
	local elapsed = 0
	local ellipsisStep = 0

	task.spawn(function()
		while LoadingUIHandler.Active and LoadingUIHandler.ScreenGui and LoadingUIHandler.ScreenGui.Parent do
			if LoadingUIHandler.InformationLabel then
				ellipsisStep = (ellipsisStep + 1) % 4
				local dots = string.rep(".", ellipsisStep)
				LoadingUIHandler.InformationLabel.Text = string.format("%s%s", LoadingUIHandler.CurrentDescriptor, dots)
			end
			LoadingUIHandler:UpdateStatusText()
			task.wait(STATUS_UPDATE_SECONDS)
		end
	end)

	task.spawn(function()
		while LoadingUIHandler.Active and LoadingUIHandler.ScreenGui and LoadingUIHandler.ScreenGui.Parent do
			if LoadingUIHandler.TipLabel then
				LoadingUIHandler.TipLabel.Text = LOADING_TIPS[tipIndex]
				tipIndex = (tipIndex % #LOADING_TIPS) + 1
			end
			task.wait(TIP_ROTATE_SECONDS)
		end
	end)
end

function LoadingUIHandler:Start()
	ReplicatedFirst:RemoveDefaultLoadingScreen()

	applyOrientation()
	bindOrientationWatchers()

	LoadingManager.Loaded:Connect(function()
		LoadingUIHandler:End()
	end)

	LoadingUIHandler.TeleportUI = script.Loading:Clone() 
	LoadingUIHandler.TeleportUI.Background.Information.InformationLabel.Text = "Teleporting..."
	TeleportService:SetTeleportGui(LoadingUIHandler.TeleportUI)

	LoadingUIHandler.ScreenGui = script.Loading:Clone() 
	LoadingUIHandler.ScreenGui.Parent = PlayerGui
	LoadingUIHandler:EnsureStatusLabels()
	if LoadingUIHandler.InformationLabel then
		LoadingUIHandler.InformationLabel.Text = LoadingUIHandler.CurrentDescriptor
	end
	LoadingUIHandler:UpdateStatusText()
	LoadingUIHandler:StartStatusLoops()

	LoadingManager.ProgressChanged:Connect(function(DecimalProgress) 
		LoadingUIHandler:UpdateLoadingBarProgress(DecimalProgress)
	end)

	LoadingManager.TaskChanged:Connect(function(LoadingTask) 
		LoadingUIHandler:UpdateLoadingUIToMatchTask(LoadingTask)
	end)

	LoadingManager:Start()
end

function LoadingUIHandler:End()
	LoadingUIHandler.Active = false
	disconnectOrientationWatchers()
	if LoadingUIHandler.ScreenGui then
		local fadeTime = 0.4
		local tweens = {}
		for _, descendant in ipairs(LoadingUIHandler.ScreenGui:GetDescendants()) do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
				table.insert(tweens, TweenService:Create(descendant, TweenInfo.new(fadeTime), {TextTransparency = 1, BackgroundTransparency = 1}))
			elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				table.insert(tweens, TweenService:Create(descendant, TweenInfo.new(fadeTime), {ImageTransparency = 1, BackgroundTransparency = 1}))
			elseif descendant:IsA("Frame") then
				table.insert(tweens, TweenService:Create(descendant, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}))
			end
		end

		for _, tween in ipairs(tweens) do
			tween:Play()
		end

		if #tweens > 0 then
			tweens[1].Completed:Wait()
		else
			task.wait(fadeTime)
		end

		LoadingUIHandler.ScreenGui:Destroy()
	end
end

function LoadingUIHandler:WhenLoaded()
	Runner = LightRunner:Get("Runner")
	LoadingManager = LightRunner:Get("LoadingManager")

	TweenService = Runner:Get("TweenService")
	StarterGui = Runner:Get("StarterGui")
	PlayerGui = Runner:Get("PlayerGui")

	applyOrientation()
	bindOrientationWatchers()

	LoadingUIHandler:Start()
end

return LoadingUIHandler