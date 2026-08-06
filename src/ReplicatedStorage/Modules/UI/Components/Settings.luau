local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = Mince.Signal
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)

local SharedSettings = require(ReplicatedStorage.Runtime.Config.Shared.Settings)
local Colors = SharedSettings.Colors

local Types = {
	BUTTON = "Buttons",
	SLIDER = "Slider"
}

local DEFAULT_VALUES = {
	[Types.SLIDER] = 0.5,
	[Types.BUTTON] = 2
}

local QUALITY_PRESETS = {
	[1] = {
		Caustics = false,
		Shadows = false
	},
	[2] = {
		Caustics = false,
		Shadows = true
	},
	[3] = {
		Caustics = true,
		Shadows = true
	}
}

local FADE_IN = 0.3
local FADE_OUT = 0.2
local EASE_STYLE_IN = Enum.EasingStyle.Back
local EASE_STYLE_OUT = Enum.EasingStyle.Back
local EASE_DIR_IN = Enum.EasingDirection.Out
local EASE_DIR_OUT = Enum.EasingDirection.In

local TWEEN_INFO_IN = TweenInfo.new(FADE_IN, EASE_STYLE_IN, EASE_DIR_IN)
local TWEEN_INFO_OUT = TweenInfo.new(FADE_OUT, EASE_STYLE_OUT, EASE_DIR_OUT)

local BACKING_TWEEN_INFO_IN = TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BACKING_TWEEN_INFO_OUT = TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local ZERO_SIZE = UDim2.new(0, 0, 0, 0)
local CENTER_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)

local originalSizes = {}
local originalPositions = {}
local originalColors = {}
local currentTweens = {}
local settingsConnections = {}

local UserProfile = Mince:Get("UserProfile")
local InterfaceHandler = Mince:Get("InterfaceHandler")

local UIBlur = Lighting:FindFirstChild("UIBlurEffect")

local function cleanupTweens(...)
	local specificKeys = {...}

	if #specificKeys > 0 then
		for _, key in ipairs(specificKeys) do
			if currentTweens[key] then
				currentTweens[key]:Cancel()
				currentTweens[key] = nil
			end
		end
	else
		for key, tween in pairs(currentTweens) do
			if tween and typeof(tween) == "Instance" then
				tween:Cancel()
			end
			currentTweens[key] = nil
		end
		currentTweens = {}
	end
end

local function addSettingsConnection(connection)
	if connection and typeof(connection) == "RBXScriptConnection" then
		table.insert(settingsConnections, connection)
	end
end

local function cleanupSettingsConnections()
	for i = #settingsConnections, 1, -1 do
		local connection = settingsConnections[i]
		if connection then
			connection:Disconnect()
		end
		settingsConnections[i] = nil
	end
end

local Setting = {}
Setting.__index = Setting

local Settings = {
	SettingLookup = {},
	IsLoaded = false,
	Loaded = Signal.new(),
	Retrieved = Signal.new(),
	IsFirstSession = false,
	FirstTimeChallengeCompleted = false,
	FirstSessionFlagged = Signal.new(),
	SettingData = {
		[Types.BUTTON] = {
			DefaultValue = DEFAULT_VALUES[Types.BUTTON],
			ValidateValue = function(value, buttons)
				return math.clamp(value, 1, #buttons)
			end,
			GetDisplayValue = function(value, buttons)
				return buttons[value].Text
			end
		},
		[Types.SLIDER] = {
			DefaultValue = DEFAULT_VALUES[Types.SLIDER],
			ValidateValue = function(value)
				return math.clamp(value or 0, 0, 1)
			end,
			GetDisplayValue = function(value)
				return string.format("%.0f%%", (value or 0) * 100)
			end
		}
	}
}

function Setting.new(proto)
	assert(proto and proto.Identifier, "Setting requires an identifier")
	assert(proto.Type, "Setting requires a type")

	local self = setmetatable(proto or {}, Setting)
	self:Init()

	Settings.SettingLookup[self.Identifier] = self
	return self
end

function Setting:Init()
	self.AskToChangeValue = Signal.new()
	self.Changed = Signal.new()
	self.ValueChanged = Signal.new()
	self.UIUpdated = Signal.new()

	self.IsAValidatedSetting = true
	self.Data = Settings.SettingData[self.Type] or {}

	self:InitializeDefaultValue()
end

function Setting:InitializeDefaultValue()
	if self.Type == Types.SLIDER then
		self.Value = self.Data.DefaultValue or DEFAULT_VALUES[Types.SLIDER]
	elseif self.Type == Types.BUTTON then
		if self.Identifier == "GraphicsQuality" then
			self.Value = DEFAULT_VALUES[Types.BUTTON]
			local preset = QUALITY_PRESETS[self.Value]
			if preset and preset.Shadows ~= nil then
				Settings:UpdateShadows(preset.Shadows)
			end
		else
			self:InitializeButtonValue()
		end
	end
end

function Setting:InitializeButtonValue()
	if self.Buttons then
		for _, button in ipairs(self.Buttons) do
			if button.Value == true then
				self.Value = true
				return
			end
		end
		self.Value = self.Buttons[1].Value
	end
end

function Setting:SetupUI()
	if self.UI then
		return
	end

	self:CreateBaseUI()

	if self.Type == Types.BUTTON then
		self:SetupButtonUI()
	elseif self.Type == Types.SLIDER then
		self:SetupSliderUI()
	end

	InterfaceHandler.Tools.ScaleDescendantStrokes(self.UI)
end

function Setting:CreateBaseUI()
	local TweenFrame = Settings.Interface.TweenFrame
	self.UI = ReplicatedStorage.Assets.Interface.Settings.SettingOption:Clone()
	self.UI.SettingName.Text = self.Name
	self.UI.SettingDescription.Text = self.Description or "A description of a setting."
	self.UI.Parent = TweenFrame.ScrollingFrame

	if self.Order then
		self.UI.LayoutOrder = self.Order
	end

	if self.Hidden and not RunService:IsStudio() then
		self.UI.Visible = false
	end
end

function Setting:SetOrder(Order)
	self.Order = Order
	if self.UI then
		self.UI.LayoutOrder = self.Order
	end
end 

function Setting:SetupButtonUI()
	if self.Type == Types.BUTTON then 
		self.ButtonPosition = 0 

		local Button = ReplicatedStorage.Assets.Interface.Settings.Button:Clone() 
		Button.Parent = self.UI
		Button.Name = self.Identifier .. "_Button"

		InterfaceHandler:NewButton(Button).Activated:Connect(function()
			self:NextButton()
		end)

		self.AskToChangeValue:Connect(function(Value)
			self:SyncButtonToValue(Value)
		end)

		self.Button = Button

		self.ValueChanged:Connect(function()
			self.UIUpdated:Fire()
		end)

		self.AskToChangeValue:Fire(self.Buttons[1].Value)
	end
end

function Setting:SetupSliderUI()
	local SliderInstance = ReplicatedStorage.Assets.Interface.Settings.Slider:Clone() 
	SliderInstance.Name = self.Identifier .. "_Slider"
	SliderInstance.Parent = self.UI 

	local SliderController = InterfaceHandler:NewSlider(SliderInstance, {
		Padding = 0.1,
		Identifier = self.Identifier
	})

	SliderController.Changed:Connect(function(Position)
		self:SetValue(Position)
	end)

	self.AskToChangeValue:Connect(function(NewValue)
		self:SetValue(NewValue)
		SliderController:SetPosition(NewValue)
	end)

	self.ValueChanged:Connect(function()
		self.UIUpdated:Fire()
	end)

	self.Slider = SliderController

	self.AskToChangeValue:Fire(self.Data.DefaultValue or 0.5)
end

function Setting:SetSubuttonToButton(SubButton)
	if not self.Button then return end

	self.Button.BackgroundColor3 = SubButton.Color or UIColors.SettingsButtonDefault
	self.Button.TextLabel.Text = SubButton.Text
end

function Setting:SyncButtonToValue(Value)
	for Position, SubButton in self.Buttons do 
		if SubButton.Value == Value then
			self:SetSubuttonToButton(SubButton) 
			self.Value = Value
			self.ButtonPosition = Position
			self.Changed:Fire(self.Value) 
		end
	end
end

function Setting:NextButton()
	if not (self.Type == "Buttons") then return end 
	self.ButtonPosition += 1
	if self.ButtonPosition > #self.Buttons then 
		self.ButtonPosition = 1 
	end 

	local CurrentButton = self.Buttons[self.ButtonPosition] 
	self:SetSubuttonToButton(CurrentButton) 
	self.Value = CurrentButton.Value
	self.Changed:Fire(self.Value) 
	Settings:ChangeSetting(self.Identifier, self.Value)
end

function Setting:SetValue(newValue)
	if self.Data.ValidateValue then
		local oldValue = newValue
		newValue = self.Data.ValidateValue(newValue, self.Buttons)
	end

	if self.Value ~= newValue then
		self.Value = newValue
		self.ValueChanged:Fire(newValue)
		self.Changed:Fire(newValue)
		Settings:ChangeSetting(self.Identifier, self.Value)
	end
end

function Setting:GetDisplayValue()
	if self.Data.GetDisplayValue then
		return self.Data.GetDisplayValue(self.Value, self.Buttons)
	end
	return tostring(self.Value)
end

function Settings:SerializeSettings()
	local settingsSave = {}

	settingsSave.FirstOpen = self.IsFirstSession == true
	settingsSave.FirstTimeChallengeCompleted = self.FirstTimeChallengeCompleted == true

	for identifier, setting in self.SettingLookup do
		if setting.IsAValidatedSetting and not setting.DisregardAfterSession then
			settingsSave[identifier] = setting.Value
		end
	end

	return settingsSave
end

function Settings:DeserializeSettings(settingsSave)
	local isNewPlayer = settingsSave.FirstOpen == true
	settingsSave.FirstOpen = nil
	local firstTimeChallengeCompleted = settingsSave.FirstTimeChallengeCompleted == true
	settingsSave.FirstTimeChallengeCompleted = nil

	self.IsFirstSession = isNewPlayer
	LocalPlayer:SetAttribute("IsFirstSession", isNewPlayer)
	self.FirstTimeChallengeCompleted = firstTimeChallengeCompleted
	LocalPlayer:SetAttribute("FirstTimeChallengeCompleted", firstTimeChallengeCompleted)
	self.FirstSessionFlagged:Fire(isNewPlayer)

	local wasRetrieved = self.SettingsRetrived
	self.SettingsRetrived = false

	for identifier, value in settingsSave do
		self:ApplySavedSetting(identifier, value)
	end

	self.SettingsRetrived = wasRetrieved or true
	if self.SettingsRetrived then
		self.Retrieved:Fire()
	end
end

function Settings:ApplySavedSetting(identifier, value)
	local setting = self.SettingLookup[identifier]

	if not setting then
		warn(`Settings lost in config because it no longer exists '{identifier}'!`)
		return
	end

	LocalPlayer:SetAttribute(identifier, value)

	if setting.Type == Types.BUTTON then
		self:ApplyButtonSetting(setting, value)
	elseif setting.IsAValidatedSetting and not setting.DisregardAfterSession then
		setting.AskToChangeValue:Fire(value or setting.Value)
	end

end

function Settings:ApplyButtonSetting(setting, value)
	setting.Value = value
	setting.Changed:Fire(value)

	for _, button in ipairs(setting.Buttons) do
		if button.Value == value then
			setting.AskToChangeValue:Fire(value)
			break
		end
	end
end

function Settings:ChangeSetting(identifier, value)
	local setting = self.SettingLookup[identifier]
	if not setting then return end

	setting.Value = value
	LocalPlayer:SetAttribute(identifier, value)

	if setting.Identifier == "Shadows" then
		self:UpdateShadows(value)
	elseif setting.Identifier == "MusicVol" then
		self:UpdateMusicVolume(value)
	elseif setting.Identifier == "SFXVol" then
		self:UpdateSFXVolume(value)
	elseif setting.Identifier == "GraphicsQuality" then
		self:ApplyQualityPreset(value)
	elseif setting.Identifier == "ReplayFirstTimeChallenge" then
		local controller = Mince:Get("FirstTimeChallengeController")
		if controller and controller.StartTutorial then
			controller:StartTutorial(true)
		end
	end

	if setting.Type == Types.BUTTON then
		setting:SyncButtonToValue(value)
	end

	if self.SettingsRetrived then
		local settingsSave = self:SerializeSettings()
		self.SaveSettings:Fire(settingsSave)
	end
end

function Settings:SetFirstTimeChallengeCompleted(value)
	self.FirstTimeChallengeCompleted = value == true
	LocalPlayer:SetAttribute("FirstTimeChallengeCompleted", self.FirstTimeChallengeCompleted)
	if self.SettingsRetrived then
		local settingsSave = self:SerializeSettings()
		self.SaveSettings:Fire(settingsSave)
	else
		task.defer(function()
			if self.SettingsRetrived then
				local settingsSave = self:SerializeSettings()
				self.SaveSettings:Fire(settingsSave)
			end
		end)
	end
end

function Settings:GetValue(identifier)
	if not Settings.SettingsRetrived then
		Settings.Retrieved:Wait()
	end
	local setting = self.SettingLookup[identifier]
	return setting and setting.Value
end

function Settings:GetSetting(identifier)
	if not self.SettingsRetrived then
		warn("Tried to get setting before settings were retrieved!")
		return nil
	end

	local setting = self.SettingLookup[identifier]
	if not setting then
		warn(string.format("No setting found with identifier '%s'", identifier))
		return nil
	end

	return setting
end

function Settings:IsFirstSession()
	return self.IsFirstSession == true
end

function Settings:WaitUntilLoaded()
	if not Settings.IsLoaded then
		Settings.Loaded:Wait()
	end
end

function Settings:OnSideButtonClick()
	Settings.Interface:Trigger()
end

function Settings:ResetButtonStates()
	if self.CloseButton and originalColors.closeButton then
		self.CloseButton.BackgroundColor3 = originalColors.closeButton
	end
end

function Settings:Show()
	cleanupTweens()

	if not self.Interface then
		warn("Settings interface not initialized")
		return false
	end

	if not self.Tweens or not self.Tweens.Show then
		warn("Settings tweens not properly initialized")
		return false
	end

	local mainFrame = self.Interface.TweenFrame
	local backing = self:GetBackingFrame()

	self.Interface.ScreenGui.Enabled = true
	mainFrame.Visible = true
	if backing then
		backing.Visible = true
	end

	mainFrame.Size = ZERO_SIZE
	mainFrame.Position = CENTER_POSITION

	if backing then
		backing.Size = ZERO_SIZE
		backing.Position = CENTER_POSITION
	end

	currentTweens.showMain = self.Tweens.Show.Main

	addSettingsConnection(self.Tweens.Show.Main.Completed:Connect(function()
		currentTweens.showMain = nil
	end))

	if backing and self.Tweens.Show.Backing then
		currentTweens.showBacking = self.Tweens.Show.Backing
		addSettingsConnection(self.Tweens.Show.Backing.Completed:Connect(function()
			currentTweens.showBacking = nil
		end))

		self.Tweens.Show.Backing:Play()
	end

	Settings.UI.ScreenShown:Fire("Settings", true)
	self.Tweens.Show.Main:Play()

	return true
end

function Settings:Hide()
	cleanupTweens()

	if not self.Interface then
		warn("Settings interface not initialized")
		return false
	end

	if not self.Tweens or not self.Tweens.Hide then
		warn("Settings hide tweens not properly initialized")
		return false
	end

	local backing = self:GetBackingFrame()

	if backing and self.Tweens.Hide.Backing then
		currentTweens.hideBacking = self.Tweens.Hide.Backing
		addSettingsConnection(self.Tweens.Hide.Backing.Completed:Connect(function()
			currentTweens.hideBacking = nil
		end))
		self.Tweens.Hide.Backing:Play()
	end

	currentTweens.hideMain = self.Tweens.Hide.Main

	addSettingsConnection(self.Tweens.Hide.Main.Completed:Connect(function()
		if currentTweens.hideMain == self.Tweens.Hide.Main then
			self.Interface.ScreenGui.Enabled = false
		end
		currentTweens.hideMain = nil
	end))

	Settings.UI.ScreenShown:Fire("Settings", false)
	self.Tweens.Hide.Main:Play()

	self:ResetButtonStates()

	return true
end

function Settings:Toggle()
	if currentTweens.showMain or currentTweens.hideMain then
		return false
	end

	if self:IsVisible() then
		return self:Hide()
	else
		return self:Show()
	end
end

function Settings:IsVisible()
	if not self.Interface or not self.Interface.ScreenGui then
		return false
	end

	if not self.Interface.ScreenGui.Enabled then
		return false
	end

	if currentTweens.hideMain then
		return false
	end

	return true
end

function Settings:GetBackingFrame()
	if not self.Interface or not self.Interface.ScreenGui then
		return nil
	end
	local backing = self.Interface.ScreenGui:FindFirstChild("Backing")
	return backing
end

function Settings:SetupBackingTweens(backing)
	if not backing then return end

	if backing.ZIndex then
		backing.ZIndex = (self.Interface.TweenFrame.ZIndex or 1) - 1
	end
end

function Settings.Init(UI)
	Settings.UI = UI

	Settings.SettingLookup = {}

	Settings.SettingsChangedEvent = Instance.new("BindableEvent")
	Settings.SettingsChanged = Settings.SettingsChangedEvent.Event

	Settings:CacheObjectsWithShadows()

	Settings.CurrentQuality = 2

	for order, object in Mince.Config.Settings.Objects do
		Setting.new(object):SetOrder(order)
	end

	Settings:UpdateShadows(true)
	Settings.Setup()

	task.spawn(function()
		if UI and UI.LoadedSignal then
			if not UI.Loaded then
				UI.LoadedSignal:Wait()
			end
		end

		if UI and UI.ScreenShown then
			UI.ScreenShown:Connect(function(componentName, isVisible)
				if isVisible and componentName ~= "Settings" and Settings:IsVisible() then
					Settings:Hide()
				end
			end)
		end

	end)

end

function Settings.Setup()
	Mince.UponStart:Once(function()
		Settings:SetupInterface()
		Settings:SetupTopbar()
		Settings:SetupUIComponents()
		Settings:SetupUserProfile()
		Settings:SetupQualityChanges()
	end)
end

function Settings:SetupInterface()
	local InterfaceHandler = Mince:Get("InterfaceHandler")

	self.SaveSettings = Mince:GetEvent("SaveSettings")
	self.Interface = InterfaceHandler:Get("Settings", "Main")

	if not self.Interface then
		warn("Failed to get Settings interface from InterfaceHandler")
		return
	end

	self.FPSLabel = self.Interface.ScreenGui:FindFirstChild("FPS", true)
	self.PINGLabel = self.Interface.ScreenGui:FindFirstChild("PING", true)
	self.CloseButton = self.Interface.ScreenGui:FindFirstChild("ExitButton", true) and
		self.Interface.ScreenGui:FindFirstChild("ExitButton", true):FindFirstChild("Exit")

	if not self.FPSLabel or not self.PINGLabel then
		warn("Failed to find FPS or PING labels")
		return
	end

	cleanupSettingsConnections()

	if self.Connections and self.Connections.RenderStepped then
		self.Connections.RenderStepped:Disconnect()
	end

	local PingCurrent = tick()
	local PingUpdateRate = 1

	local accumulatedTime = 0
	local frameCount = 0
	local averagedFPS = 0
	local fpsUpdateWindow = 0.5

	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local updateInterval = isMobile and 0.1 or 0.05
	local lastRenderUpdate = 0

	self.Connections = {}

	self.Connections.RenderStepped = game:GetService("RunService").RenderStepped:Connect(function(deltaTime)
		local CurrentTick = tick()

		if CurrentTick - lastRenderUpdate < updateInterval then
			return
		end
		lastRenderUpdate = CurrentTick

		accumulatedTime = accumulatedTime + deltaTime
		frameCount = frameCount + 1
		if accumulatedTime >= fpsUpdateWindow then
			averagedFPS = math.floor(frameCount / accumulatedTime + 0.5)
			accumulatedTime = 0
			frameCount = 0
		end

		if self.FPSLabel then
			self.FPSLabel.Text = string.format("FPS: %d", averagedFPS)
			self.FPSLabel.TextColor3 = Colors:GetFPSColor(averagedFPS)
		end

		if self.PINGLabel then
			if CurrentTick - PingCurrent >= PingUpdateRate then
				local pingMs = LocalPlayer:GetNetworkPing() * 2000
				self.PINGLabel.Text = string.format("PING: %d", pingMs)
				self.PINGLabel.TextColor3 = Colors:GetPingColor(pingMs)
				PingCurrent = CurrentTick
			end
		end

	end)

	if UIBlur then
		local originalOpened = self.Interface.Opened
		local originalClosed = self.Interface.Closed

		if self.Interface._openedConnection then
			self.Interface._openedConnection:Disconnect()
		end
		if self.Interface._closedConnection then
			self.Interface._closedConnection:Disconnect()
		end

		addSettingsConnection(originalOpened:Connect(function()
			UIBlur.Enabled = true
		end))

		addSettingsConnection(originalClosed:Connect(function()
			UIBlur.Enabled = false
		end))
	end

	addSettingsConnection(self.Interface.Closed:Connect(function()
		self:SerializeSettings()
		cleanupTweens()
	end))


	self:SetupCloseButton()
	self:SetupBackingFrame()
	self:InitializeTweens()
end

function Settings:InitializeTweens()
	if not self.Interface or not self.Interface.TweenFrame then
		return
	end

	local mainFrame = self.Interface.TweenFrame
	local backing = self:GetBackingFrame()

	if not originalSizes.Main then
		originalSizes.Main = mainFrame.Size or UDim2.new(0, 800, 0, 600)
		originalPositions.Main = mainFrame.Position or UDim2.new(0.5, 0, 0.5, 0)
	end
	if backing and not originalSizes.Backing then
		originalSizes.Backing = backing.Size or UDim2.new(0, 820, 0, 620)
		originalPositions.Backing = backing.Position or UDim2.new(0.52, 0, 0.51, 0)
	end

	self.Tweens = {
		Show = {
			Main = TweenService:Create(mainFrame, TWEEN_INFO_IN, {
				Size = originalSizes.Main,
				Position = originalPositions.Main
			}),
			Backing = backing and TweenService:Create(backing, BACKING_TWEEN_INFO_IN, {
				Size = originalSizes.Backing,
				Position = originalPositions.Backing
			})
		},
		Hide = {
			Main = TweenService:Create(mainFrame, TWEEN_INFO_OUT, {
				Size = ZERO_SIZE,
				Position = CENTER_POSITION
			}),
			Backing = backing and TweenService:Create(backing, BACKING_TWEEN_INFO_OUT, {
				Size = ZERO_SIZE,
				Position = CENTER_POSITION
			})
		}
	}
end

function Settings:SetupBackingFrame()
	local backing = self:GetBackingFrame()
	if backing then
		backing.Visible = false
		self:SetupBackingTweens(backing)
	end
end

function Settings:SetupCloseButton()
	if not self.CloseButton then
		warn("Exit button not found in Settings UI")
		return
	end

	local originalSize = self.CloseButton.Size
	local hoverSize = UDim2.new(originalSize.X.Scale * 1.15, originalSize.X.Offset, originalSize.Y.Scale * 1.15, originalSize.Y.Offset)
	local clickSize = UDim2.new(originalSize.X.Scale * 0.85, originalSize.X.Offset, originalSize.Y.Scale * 0.85, originalSize.Y.Offset)

	local hoverTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local clickTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local originalColor = self.CloseButton.BackgroundColor3 or UIColors.ExitBackground
	originalColors.closeButton = originalColor
	local hoverColor = UIColors.ExitHover
	local clickColor = UIColors.ExitClick

	local tweens = {
		hoverIn = TweenService:Create(self.CloseButton, hoverTweenInfo, {
			Size = hoverSize,
			BackgroundColor3 = hoverColor
		}),
		hoverOut = TweenService:Create(self.CloseButton, hoverTweenInfo, {
			Size = originalSize,
			BackgroundColor3 = originalColor
		}),
		clickDown = TweenService:Create(self.CloseButton, clickTweenInfo, {
			Size = clickSize,
			BackgroundColor3 = clickColor
		}),
		clickUp = TweenService:Create(self.CloseButton, clickTweenInfo, {
			Size = hoverSize,
			BackgroundColor3 = hoverColor
		})
	}

	addSettingsConnection(self.CloseButton.MouseEnter:Connect(function()
		tweens.hoverOut:Cancel()
		tweens.hoverIn:Play()
	end))

	addSettingsConnection(self.CloseButton.MouseLeave:Connect(function()
		tweens.hoverIn:Cancel()
		tweens.clickUp:Cancel()
		tweens.hoverOut:Play()
	end))

	addSettingsConnection(self.CloseButton.MouseButton1Down:Connect(function()
		tweens.hoverIn:Cancel()
		tweens.clickDown:Play()
	end))

	addSettingsConnection(self.CloseButton.MouseButton1Up:Connect(function()
		tweens.clickDown:Cancel()
		tweens.clickUp:Play()
	end))

	addSettingsConnection(self.CloseButton.Activated:Connect(function()
		if self.ToggleButton then
			self.ToggleButton:deselect()
		else
			self:Hide()
		end
	end))

	self:SetupEscapeKeySupport()
end

function Settings:SetupEscapeKeySupport()
	local UserInputService = game:GetService("UserInputService")

	if self.EscapeConnection then
		self.EscapeConnection:Disconnect()
	end

	self.EscapeConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Escape then
			if self:IsVisible() then
				if self.ToggleButton then
					self.ToggleButton:deselect()
				else
					self:Hide()
				end
			end
		end
	end)

	addSettingsConnection(self.EscapeConnection)
end

function Settings:SetupTopbar()

end

function Settings:SetupUIComponents()
	for _, setting in self.SettingLookup do
		setting:SetupUI()
	end
end

function Settings:SetupUserProfile()
	UserProfile:Upon("Settings", function(settingsSave)
		self:DeserializeSettings(settingsSave)
		if not self.IsLoaded then
			self.IsLoaded = true
			self.Loaded:Fire()
		end
	end)
end

function Settings:SetupQualityChanges()

	if not self.IsLoaded then
		self.Loaded:Wait()
	end

	local graphicsQuality = self:GetSetting("GraphicsQuality")
	if not graphicsQuality then
		warn("GraphicsQuality setting not found")
		return
	end

	graphicsQuality.Changed:Connect(function(buttonPosition)
		local button = graphicsQuality.Buttons[buttonPosition]
		if button then
			self:ApplyQualityPreset(button.Value)
		else
			warn("No button found at position:", buttonPosition)
		end
	end)

	local initialQuality = graphicsQuality.Value
	if initialQuality then
		self:ApplyQualityPreset(initialQuality)
	else
		self:ApplyQualityPreset(2) 
	end

	if self:GetValue("Shadows") then
		self:UpdateShadows(true)
	end

	local musicVolume = self:GetValue("MusicVol")
	if musicVolume then
		self:UpdateMusicVolume(musicVolume)
	else
		self:UpdateMusicVolume(0.5)
	end

	local sfxVolume = self:GetValue("SFXVol")
	if sfxVolume then
		self:UpdateSFXVolume(sfxVolume)
	else
		self:UpdateSFXVolume(0.5)
	end
end

function Settings:ApplyQualityPreset(qualityLevel : number)
	local preset = QUALITY_PRESETS[qualityLevel]

	if not preset then
		warn("No preset found for quality level:", qualityLevel)
		return
	end

	for setting, value in pairs(preset) do
		local settingObj = self:GetSetting(setting)
		if settingObj then
			self:ChangeSetting(setting, value)
		else
			warn("Setting not found:", setting)
		end
	end

	return preset
end

function Settings:UpdateShadows(enabled)
	Lighting.GlobalShadows = enabled

	if not self.ObjectsWithShadows then
		self:CacheObjectsWithShadows()
	end

	for object in pairs(self.ObjectsWithShadows) do
		if object and object.Parent then
			if object:IsA("BasePart") or object:IsA("MeshPart") then
				object.CastShadow = enabled
			end
		else
			self.ObjectsWithShadows[object] = nil
		end
	end

	if not Settings._shadowConnection then
		Settings._shadowConnection = workspace.DescendantAdded:Connect(function(object)
			if object:IsA("BasePart") or object:IsA("MeshPart") then
				if object.CastShadow then
					Settings.ObjectsWithShadows[object] = true
				end

				if Settings:GetValue("Shadows") then
					object.CastShadow = true
				else
					object.CastShadow = false
				end
			end
		end)
	end
end

function Settings:UpdateMusicVolume(volume)
	local masterGroup = SoundService:FindFirstChild("Master")
	if masterGroup then
		local musicGroup = masterGroup:FindFirstChild("Music")
		if musicGroup and musicGroup:IsA("SoundGroup") then
			musicGroup.Volume = volume
		else
			print("Music SoundGroup not found")
		end
	else
		print("Master SoundGroup not found")
	end
end

function Settings:UpdateSFXVolume(volume)
	local masterGroup = SoundService:FindFirstChild("Master")
	if masterGroup then
		local sfxGroup = masterGroup:FindFirstChild("SFX")
		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			sfxGroup.Volume = volume
		else
			print("SFX SoundGroup not found")
		end
	else
		print("Master SoundGroup not found")
	end
end

function Settings:CacheObjectsWithShadows()
	self.ObjectsWithShadows = {}
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local maxPerStep = isMobile and 100 or 300
	local maxTime = isMobile and 0.001 or 0.003

	local queue = workspace:GetDescendants()

	local function step()
		local startTime = os.clock()
		local processed = 0
		while processed < maxPerStep and #queue > 0 do
			local object = queue[#queue]
			queue[#queue] = nil
			if (object:IsA("BasePart") or object:IsA("MeshPart")) and object.CastShadow then
				self.ObjectsWithShadows[object] = true
			end
			processed += 1
			if os.clock() - startTime >= maxTime then
				break
			end
		end

		if #queue > 0 then
			if isMobile then
				task.wait()
				task.defer(step)
			else
				task.defer(step)
			end
		end
	end

	step()
end

function Settings:Cleanup()
	cleanupTweens()
	cleanupSettingsConnections()

	if self.EscapeConnection then
		self.EscapeConnection:Disconnect()
		self.EscapeConnection = nil
	end

	if self.Connections then
		for _, connection in pairs(self.Connections) do
			if connection then
				connection:Disconnect()
			end
		end
		self.Connections = {}
	end
end

return Settings