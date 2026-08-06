local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local MIN_DISPLAY_SECONDS = 3
local MAX_DISPLAY_SECONDS = 16
local POST_LOAD_BUFFER = 0.4
local TIP_ROTATE_SECONDS = 5
local WORLD_LOAD_TIMEOUT = 10
local READINESS_TIMEOUT = 8

local LOADING_TIPS = {
	"Tip: Scan creatures to grow your encyclopedia.",
	"Tip: Upgrade gear to dive longer.",
	"Tip: Some discoveries unlock bonus rewards.",
	"Tip: Revisit zones to complete achievements.",
	"Tip: Keep an eye out for rare fish near kelp forests.",
}

local CORE_GUI_TO_HIDE = {
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.EmotesMenu,
}

local function tweenBar(bar, target)
	if not bar then
		return
	end

	local tween = TweenService:Create(bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(target, 0, 1, 0),
	})
	tween:Play()
end

local function setLoadingCoreGuiEnabled(isEnabled)
	for _, coreGuiType in ipairs(CORE_GUI_TO_HIDE) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, isEnabled)
		end)
	end
end

local function getCharacterRig(timeout, updateStepProgress)
	local startedAt = os.clock()
	local character
	local rootPart
	local humanoid

	while os.clock() - startedAt < timeout do
		character = player.Character
		rootPart = character and character:FindFirstChild("HumanoidRootPart")
		humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if character and rootPart and humanoid then
			return character, rootPart, humanoid
		end

		if updateStepProgress then
			local elapsed = os.clock() - startedAt
			updateStepProgress(math.clamp(elapsed / timeout, 0, 0.9))
		end
		task.wait(0.05)
	end

	return character, rootPart, humanoid
end

local function waitForCharacterReady(updateStepProgress)
	local _, rootPart, humanoid = getCharacterRig(READINESS_TIMEOUT, updateStepProgress)
	if not rootPart or not humanoid then
		warn("[Loading] Character was not fully ready before the loading screen timeout.")
	end

	updateStepProgress(1)
end

local function waitForCondition(timeout, condition, updateStepProgress)
	local startedAt = os.clock()
	while os.clock() - startedAt < timeout do
		if condition() then
			return true
		end
		if updateStepProgress then
			updateStepProgress(math.clamp((os.clock() - startedAt) / timeout, 0, 0.9))
		end
		task.wait(0.05)
	end

	return condition()
end

local function startLoading()
	setLoadingCoreGuiEnabled(false)

	local template = script:FindFirstChild("Loading")
	if not template or not template:IsA("ScreenGui") then
		warn("Missing ScreenGui template named 'Loading' under the script.")
		setLoadingCoreGuiEnabled(true)
		return
	end

	local screenGui = template:Clone()
	screenGui.Parent = playerGui

	local statusLabel = screenGui:FindFirstChild("StatusLabel", true)
	local tipLabel = screenGui:FindFirstChild("TipLabel", true)
	local barFill = screenGui:FindFirstChild("Bar", true)
	local logo = screenGui:FindFirstChild("Logo", true)
	local logoGradient = logo and logo:FindFirstChild("LogoGradient")
	local skipRequested = false
	local canSkip = false

	local skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipButton"
	skipButton.Text = "Skip"
	skipButton.Font = Enum.Font.GothamSemibold
	skipButton.TextSize = 16
	skipButton.TextColor3 = Color3.new(1, 1, 1)
	skipButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	skipButton.BackgroundTransparency = 0.2
	skipButton.Size = UDim2.new(0, 110, 0, 36)
	skipButton.AnchorPoint = Vector2.new(1, 1)
	skipButton.Position = UDim2.new(1, -24, 1, -24)
	skipButton.AutoButtonColor = true
	skipButton.Parent = screenGui

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 10)
	skipCorner.Parent = skipButton

	skipButton.Activated:Connect(function()
		if canSkip then
			skipRequested = true
		end
	end)

	task.delay(MIN_DISPLAY_SECONDS, function()
		canSkip = true
	end)

	local currentProgress = 0
	local function updateProgress(progress)
		local clamped = math.clamp(progress, currentProgress, 1)
		currentProgress = clamped
		tweenBar(barFill, clamped)
		if logoGradient then
			logoGradient.Offset = Vector2.new(0, 1 - clamped)
		end
	end

	local tipIndex = 1
	local tipTask = task.spawn(function()
		while screenGui.Parent do
			if tipLabel then
				tipLabel.Text = LOADING_TIPS[tipIndex]
			end
			tipIndex = (tipIndex % #LOADING_TIPS) + 1
			task.wait(TIP_ROTATE_SECONDS)
		end
	end)

	local startTime = os.clock()

	local loadingSteps = {
		{
			Label = "LOADING GAME WORLD",
			Weight = 0.60,
			Run = function(updateStepProgress)
				local worldReady = waitForCondition(WORLD_LOAD_TIMEOUT, function()
					return game:IsLoaded()
				end, updateStepProgress)
				if not worldReady then
					warn("[Loading] Initial game replication exceeded the loading timeout.")
				end
				updateStepProgress(1)
			end,
		},
		{
			Label = "PREPARING CHARACTER",
			Weight = 0.34,
			Run = function(updateStepProgress)
				waitForCharacterReady(updateStepProgress)
			end,
		},
		{
			Label = "FINALIZING",
			Weight = 0.06,
			Run = function(updateStepProgress)
				local elapsed = os.clock() - startTime
				if elapsed < MIN_DISPLAY_SECONDS then
					task.wait(MIN_DISPLAY_SECONDS - elapsed)
				end
				task.wait(POST_LOAD_BUFFER)
				updateStepProgress(1)
			end,
		},
	}

	local totalWeight = 0
	for _, step in ipairs(loadingSteps) do
		totalWeight += step.Weight
	end

	local completedWeight = 0
	for _, step in ipairs(loadingSteps) do
		if skipRequested then
			break
		end

		if os.clock() - startTime >= MAX_DISPLAY_SECONDS then
			warn("[Loading] Loading screen reached the maximum display time.")
			break
		end

		if statusLabel then
			statusLabel.Text = step.Label
		end

		local stepStartedAt = os.clock()
		local stepProgress = 0
		local success, err = xpcall(function()
			step.Run(function(progress)
				stepProgress = math.max(stepProgress, math.clamp(progress, 0, 1))
				updateProgress((completedWeight + step.Weight * stepProgress) / totalWeight)
			end)
		end, debug.traceback)

		if not success then
			warn("[Loading] Step failed:", step.Label, err)
		end
		print(("[Loading] %s completed in %.2fs"):format(step.Label, os.clock() - stepStartedAt))

		completedWeight += step.Weight
		updateProgress(completedWeight / totalWeight)
	end

	if statusLabel then
		statusLabel.Text = "READY"
	end
	updateProgress(1)

	if tipTask then
		task.cancel(tipTask)
	end

	screenGui:Destroy()
	print(("[Loading] Playable view ready in %.2fs"):format(os.clock() - startTime))
end

startLoading()
