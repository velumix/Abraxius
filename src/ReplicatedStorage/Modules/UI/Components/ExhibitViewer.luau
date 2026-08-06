local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIModules = Modules:WaitForChild("UI")
local UIAudio = require(UIModules:WaitForChild("UIAudio"))
local UIFactory = require(UIModules:WaitForChild("UIFactory"))
local UIColors = require(UIModules:WaitForChild("UIColors"))

local LocalPlayer = Players.LocalPlayer

local COLORS = {
	Background = UIColors.Background,
	Card = UIColors.Card,
	Text = UIColors.Text,
	SubText = UIColors.TextSecondary,
	Border = UIColors.Border,
	Shadow = UIColors.Shadow,
	Button = UIColors.ExhibitButton,
	ButtonHover = UIColors.ButtonHoverAlt,
	ButtonPressed = UIColors.ButtonClick,
	Overlay = UIColors.Overlay,
}

local TWEEN_CONFIG = {
	FADE_DURATION = 0.3,
	BUTTON_HOVER_DURATION = 0.2,
	EXIT_SHOW_DURATION = 0.3,
	EXIT_HIDE_DURATION = 0.2,
	FADE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	BUTTON_ENTER_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
	BUTTON_LEAVE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	BUTTON_PRESS_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	EXIT_SHOW_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	EXIT_HIDE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
}

local UI_CONFIG = {
	EXIT_BUTTON_SIZE = {Width = 200, Height = 50},
	EXIT_BUTTON_POSITION = {X = 0.5, Y = 40},
	DISPLAY_ORDER = 100,
	MIN_EXHIBIT_TIME = 0.5,
	BUTTON_TEXT = "EXIT EXHIBITION [E]",
	BUTTON_TEXT_SIZE = 14,
	BUTTON_TEXT_SIZE_HOVER = 15,
	CORNER_RADIUS = UDim.new(1, 0),
	STROKE_THICKNESS = 2,
	BUTTON_TRANSPARENCY = 0
}

local UI = {
	gui = nil,
	overlay = nil,
	exitContainer = nil,
	exitButton = nil,
	initialized = false
}

local currentTweens = {}
local connections = {}
local currentExitCallback = nil
local exhibitOpenTime = nil

local ExhibitViewer = {}

local function addConnection(connection)
	if connection and typeof(connection) == "RBXScriptConnection" then
		table.insert(connections, connection)
	end
	return connection
end

local function clearAllConnections()
	for _, conn in ipairs(connections) do
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	connections = {}
end

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

local function clearAllTweens()
	cleanupTweens()
end

local function createTween(instance, tweenInfo, properties, key)
	if key then
		cleanupTweens(key)
	end
	local tween = TweenService:Create(instance, tweenInfo, properties)
	if key then
		currentTweens[key] = tween
		addConnection(tween.Completed:Connect(function()
			currentTweens[key] = nil
		end))
	end
	return tween
end

local function isExitAllowed()
	return exhibitOpenTime and (tick() - exhibitOpenTime) > UI_CONFIG.MIN_EXHIBIT_TIME
end

local function handleExitAction()
	if currentExitCallback and isExitAllowed() then
		UIAudio.PlayNotification("Info")
		currentExitCallback()
	end
end

local function setupExitKeyBinding()
	local keyConnection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E and not UserInputService:GetFocusedTextBox() then
			if UI.exitContainer.Visible then
				handleExitAction()
			end
		end
	end)
	addConnection(keyConnection)
end

local function setupExitButton()
	addConnection(UI.exitButton.Activated:Connect(handleExitAction))
	setupExitKeyBinding()
end

local function setupButtonHoverEffects(button)
	local uiScale = button:FindFirstChild("UIScale")
	local uiGradient = button:FindFirstChild("UIGradient")
	local uiStroke = button:FindFirstChild("UIStroke") or button:FindFirstChildOfClass("UIStroke")

	addConnection(button.MouseEnter:Connect(function()
		UIAudio.PlayNotification("Hover")

		if uiScale then
			createTween(uiScale, TWEEN_CONFIG.BUTTON_ENTER_INFO, {Scale = 1.1}, "btnScale")
		end
		if uiGradient then
			createTween(uiGradient, TWEEN_CONFIG.BUTTON_ENTER_INFO, {Rotation = 135, Offset = Vector2.new(0, -0.1)}, "btnGrad")
		end
		if uiStroke then
			createTween(uiStroke, TWEEN_CONFIG.BUTTON_ENTER_INFO, {Thickness = 3, Color = COLORS.Text}, "btnStroke")
		end
		createTween(button, TWEEN_CONFIG.BUTTON_ENTER_INFO, {BackgroundColor3 = COLORS.ButtonHover}, "btnColor")
	end))

	addConnection(button.MouseLeave:Connect(function()
		if uiScale then
			createTween(uiScale, TWEEN_CONFIG.BUTTON_LEAVE_INFO, {Scale = 1}, "btnScale")
		end
		if uiGradient then
			createTween(uiGradient, TWEEN_CONFIG.BUTTON_LEAVE_INFO, {Rotation = 90, Offset = Vector2.new(0, 0)}, "btnGrad")
		end
		if uiStroke then
			createTween(uiStroke, TWEEN_CONFIG.BUTTON_LEAVE_INFO, {Thickness = UI_CONFIG.STROKE_THICKNESS, Color = COLORS.Border}, "btnStroke")
		end
		createTween(button, TWEEN_CONFIG.BUTTON_LEAVE_INFO, {BackgroundColor3 = COLORS.Button}, "btnColor")
	end))

	addConnection(button.MouseButton1Down:Connect(function()
		UIAudio.PlayNotification("Click")

		if uiScale then
			createTween(uiScale, TWEEN_CONFIG.BUTTON_PRESS_INFO, {Scale = 0.95}, "btnScale")
		end
		if uiStroke then
			createTween(uiStroke, TWEEN_CONFIG.BUTTON_PRESS_INFO, {Thickness = 2}, "btnStroke")
		end
		createTween(button, TWEEN_CONFIG.BUTTON_PRESS_INFO, {BackgroundColor3 = COLORS.ButtonPressed}, "btnColor")
	end))

	addConnection(button.MouseButton1Up:Connect(function()
		if uiScale then
			createTween(uiScale, TWEEN_CONFIG.BUTTON_ENTER_INFO, {Scale = 1.1}, "btnScale")
		end
		if uiStroke then
			createTween(uiStroke, TWEEN_CONFIG.BUTTON_ENTER_INFO, {Thickness = 3}, "btnStroke")
		end
		createTween(button, TWEEN_CONFIG.BUTTON_ENTER_INFO, {BackgroundColor3 = COLORS.ButtonHover}, "btnColor")
	end))
end

local function createExhibitUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExhibitViewerSystem"
	gui.DisplayOrder = UI_CONFIG.DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local overlay = UIFactory.createFrame(gui, {
		Name = "TransitionOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = COLORS.Overlay,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1
	})

	local exitContainer = UIFactory.createFrame(gui, {
		Name = "ExitContainer",
		Size = UDim2.new(0, UI_CONFIG.EXIT_BUTTON_SIZE.Width, 0, UI_CONFIG.EXIT_BUTTON_SIZE.Height),
		Position = UDim2.new(UI_CONFIG.EXIT_BUTTON_POSITION.X, -UI_CONFIG.EXIT_BUTTON_SIZE.Width/2, 0, UI_CONFIG.EXIT_BUTTON_POSITION.Y),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		ClipsDescendants = false
	})

	local exitButton = UIFactory.createTextButton(exitContainer, {
		Name = "ExitButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = UI_CONFIG.BUTTON_TRANSPARENCY,
		BorderSizePixel = 0,
		Text = UI_CONFIG.BUTTON_TEXT,
		TextSize = UI_CONFIG.BUTTON_TEXT_SIZE,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false
	}, {
		Corner = UI_CONFIG.CORNER_RADIUS,
		Stroke = {
			Color = COLORS.Border,
			Thickness = UI_CONFIG.STROKE_THICKNESS,
			Transparency = 0
		}
	})

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = exitButton

	local uiGradient = Instance.new("UIGradient")
	uiGradient.Rotation = 90
	uiGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.85, 0.85, 0.85))
	})
	uiGradient.Parent = exitButton

	return gui, overlay, exitContainer, exitButton
end

function ExhibitViewer.ShowExitButton(callback)
	if not UI.initialized then return end

	currentExitCallback = callback
	exhibitOpenTime = tick()

	UI.exitContainer.Visible = true
	UI.exitContainer.Position = UDim2.new(UI_CONFIG.EXIT_BUTTON_POSITION.X, 0, 0, UI_CONFIG.EXIT_BUTTON_POSITION.Y)
	UI.exitContainer.Size = UDim2.new(0, 0, 0, UI_CONFIG.EXIT_BUTTON_SIZE.Height)

	local tween = createTween(UI.exitContainer, TWEEN_CONFIG.EXIT_SHOW_INFO, {
		Position = UDim2.new(UI_CONFIG.EXIT_BUTTON_POSITION.X, -UI_CONFIG.EXIT_BUTTON_SIZE.Width/2, 0, UI_CONFIG.EXIT_BUTTON_POSITION.Y),
		Size = UDim2.new(0, UI_CONFIG.EXIT_BUTTON_SIZE.Width, 0, UI_CONFIG.EXIT_BUTTON_SIZE.Height)
	}, "exitShow")
	tween:Play()
end

function ExhibitViewer.HideExitButton()
	if not UI.initialized then return end

	currentExitCallback = nil

	local tween = createTween(UI.exitContainer, TWEEN_CONFIG.EXIT_HIDE_INFO, {
		Position = UDim2.new(UI_CONFIG.EXIT_BUTTON_POSITION.X, 0, 0, UI_CONFIG.EXIT_BUTTON_POSITION.Y),
		Size = UDim2.new(0, 0, 0, UI_CONFIG.EXIT_BUTTON_SIZE.Height)
	}, "exitHide")
	tween:Play()

	tween.Completed:Connect(function()
		UI.exitContainer.Visible = false
	end)
end

function ExhibitViewer.FadeIn(duration, callback)
	if not UI.initialized then return end

	duration = duration or TWEEN_CONFIG.FADE_DURATION

	UI.overlay.BackgroundTransparency = 1

	local tween = createTween(UI.overlay, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		BackgroundTransparency = 0
	}, "fadeIn")
	tween:Play()

	if callback then
		tween.Completed:Connect(callback)
	end

	return tween
end

function ExhibitViewer.FadeOut(duration, callback)
	if not UI.initialized then return end
	duration = duration or TWEEN_CONFIG.FADE_DURATION

	local tween = createTween(UI.overlay, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		BackgroundTransparency = 1
	}, "fadeOut")
	tween:Play()

	if callback then
		tween.Completed:Connect(callback)
	end

	return tween
end

function ExhibitViewer.IsVisible()
	return UI.initialized and UI.exitContainer.Visible
end

function ExhibitViewer.Cleanup()
	clearAllConnections()
	clearAllTweens()

	if UI.gui then
		UI.gui:Destroy()
		UI.gui = nil
	end

	UI.overlay = nil
	UI.exitContainer = nil
	UI.exitButton = nil

	currentExitCallback = nil
	exhibitOpenTime = nil
	UI.initialized = false
end

function ExhibitViewer.Init()
	if UI.initialized then return end

	UI.gui, UI.overlay, UI.exitContainer, UI.exitButton = createExhibitUI()
	setupButtonHoverEffects(UI.exitButton)
	setupExitButton()
	UI.initialized = true
end

return ExhibitViewer
