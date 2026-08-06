local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Mince = require(Modules:WaitForChild("Mince"))
local UI = require(Modules:WaitForChild("UI"))

local FirstTimeChallenge = require(Modules:WaitForChild("Tutorials"):WaitForChild("FirstTimeChallenge"))

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

local function Blink(totalDuration)
	local overlay = playerGui:FindFirstChild("TutorialReplayBlackout")
	if not overlay then
		overlay = Instance.new("ScreenGui")
		overlay.Name = "TutorialReplayBlackout"
		overlay.IgnoreGuiInset = true
		overlay.ResetOnSpawn = false
		overlay.DisplayOrder = 1_000_000
		overlay.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Position = UDim2.fromScale(0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = overlay

		local logo = Instance.new("ImageLabel")
		logo.Name = "Logo"
		logo.BackgroundTransparency = 1
		logo.Size = UDim2.fromScale(0.18, 0.18)
		logo.AnchorPoint = Vector2.new(0.5, 0.5)
		logo.Position = UDim2.fromScale(0.5, 0.5)
		logo.Image = "rbxassetid://115605544455144"
		logo.ImageRectOffset = Vector2.new(0, 0)
		logo.ImageRectSize = Vector2.new(0, 0)
		logo.ImageTransparency = 1
		logo.ScaleType = Enum.ScaleType.Fit
		logo.Parent = overlay
	end

	local frame = overlay:FindFirstChild("Frame")
	local logo = overlay:FindFirstChild("Logo")
	if not frame then
		return
	end

	overlay.Enabled = true
	frame.BackgroundTransparency = 1
	if logo then
		logo.ImageTransparency = 1
	end

	local duration = totalDuration or 2
	local fadeInTime = duration * 0.5
	local fadeOutTime = duration * 0.5

	local fadeIn = TweenService:Create(frame, TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
	local fadeOut = TweenService:Create(frame, TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })

	local logoFadeIn = logo and TweenService:Create(logo, TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageTransparency = 0 }) or nil
	local logoFadeOut = logo and TweenService:Create(logo, TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 }) or nil

	fadeIn:Play()
	if logoFadeIn then
		logoFadeIn:Play()
	end
	fadeIn.Completed:Connect(function()
		fadeOut:Play()
		if logoFadeOut then
			logoFadeOut:Play()
		end
		fadeOut.Completed:Connect(function()
			overlay.Enabled = false
		end)
	end)
end

local function getSpawnCFrame()
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation and spawnLocation.CFrame then
		return spawnLocation.CFrame + Vector3.new(0, 3, 0)
	end
	return nil
end

local FirstTimeChallengeController = {
	Started = false,
	ActiveTutorial = nil,
}

function FirstTimeChallengeController:GameStart()
	self:HookSettings()
end

function FirstTimeChallengeController:HookSettings()
	local settings = UI.Settings
	local function done()
		if settings and settings.FirstTimeChallengeCompleted ~= nil then
			return settings.FirstTimeChallengeCompleted == true
		end
		return LocalPlayer:GetAttribute("FirstTimeChallengeCompleted") == true
	end

	local function tryStart()
		if not done() then
			self:StartTutorial()
		end
	end

	if settings then
		if settings.IsLoaded then
			tryStart()
		elseif settings.Loaded then
			settings.Loaded:Connect(tryStart)
		end
	else
		tryStart()
	end

	LocalPlayer:GetAttributeChangedSignal("FirstTimeChallengeCompleted"):Connect(function()
		tryStart()
	end)
end

function FirstTimeChallengeController:StartTutorial(forceRestart)
	if self.Started and not forceRestart and not RunService:IsStudio() then
		return
	end

	local teleportCFrame = nil
	if forceRestart then
		teleportCFrame = getSpawnCFrame()
		Blink(2)
		if UI and UI.Settings and UI.Settings.Hide then
			UI.Settings:Hide()
		end
	end

	if self.ActiveTutorial and self.ActiveTutorial.Cancel then
		self.ActiveTutorial:Cancel()
	end

	self.Started = true
	self.ActiveTutorial = FirstTimeChallenge.Start()

	if teleportCFrame and forceRestart == true then
		task.delay(0.75, function()
			local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = teleportCFrame
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end

		end)
	end
end

return FirstTimeChallengeController
