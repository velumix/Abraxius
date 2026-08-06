local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIModules = Modules:WaitForChild("UI")

local Mince = require(Modules:WaitForChild("Mince"))
local UIFactory = require(UIModules:WaitForChild("UIFactory"))
local UIColors = require(UIModules:WaitForChild("UIColors"))
local UIAudio = require(UIModules:WaitForChild("UIAudio"))

local Signal = Mince.Signal

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local DISPLAY_ORDER = 120
local CARD_SIZE = UDim2.new(0, 460, 0, 320)
local BUTTON_HEIGHT = 110
local OVERLAY_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local CARD_TWEEN_IN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CARD_TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local QUALITY_OPTIONS = {
	{
		Key = "High",
		Label = "High Quality",
		Description = "All effects with caustics.",
		Value = 3,
		Recommended = true,
		Theme = {
			Background = UIColors.ElevatorCurrentBg,
			Hover = UIColors.ElevatorCurrentBg:Lerp(UIColors.White, 0.08),
			Pressed = UIColors.ElevatorCurrentBg:Lerp(UIColors.White, 0.16),
			Border = UIColors.ElevatorCurrentIcon,
			Title = UIColors.ElevatorCurrentText,
			Subtitle = UIColors.ElevatorCurrentSubText,
		}
	},
	{
		Key = "Medium",
		Label = "Medium Quality",
		Description = "Balanced lighting + shadows.",
		Value = 2,
		Recommended = false,
		Theme = {
			Background = UIColors.ButtonHover,
			Hover = UIColors.ButtonHover:Lerp(UIColors.White, 0.05),
			Pressed = UIColors.ButtonHover:Lerp(UIColors.Black, 0.08),
			Border = UIColors.Stroke,
			Title = UIColors.Text,
			Subtitle = UIColors.TextSecondary,
		}
	},
	{
		Key = "Low",
		Label = "Low Quality",
		Description = "Keeps FPS up, no shadows.",
		Value = 1,
		Recommended = false,
		Theme = {
			Background = UIColors.Button,
			Hover = UIColors.ButtonHover,
			Pressed = UIColors.ButtonPressed,
			Border = UIColors.Border,
			Title = UIColors.Text,
			Subtitle = UIColors.TextSecondary,
		}
	}
}

local function createBlur()
	local blur = Lighting:FindFirstChild("QualityScreenBlur")
	if blur and blur:IsA("BlurEffect") then
		return blur
	end

	blur = Instance.new("BlurEffect")
	blur.Name = "QualityScreenBlur"
	blur.Enabled = false
	blur.Size = 0
	blur.Parent = Lighting
	return blur
end

local QualityScreen = {
	Showing = false,
	HasSelectedQuality = false,
	Shown = Signal.new(),
	Hidden = Signal.new(),
	QualityChosen = Signal.new(),
}

local function createShadow(parent)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Size = CARD_SIZE + UDim2.new(0, 20, 0, 20)
	shadow.Position = UDim2.fromScale(0.5, 0.5)
	shadow.BackgroundColor3 = UIColors.Shadow
	shadow.BackgroundTransparency = 0.5
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = shadow
	return shadow
end

local function createBadge(parent)
	local badge = UIFactory.createTextLabel(parent, {
		Name = "Badge",
		Text = "Best look",
		TextColor3 = UIColors.Button,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		BackgroundColor3 = UIColors.Accent,
		Size = UDim2.new(0, 120, 0, 26),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, -10),
		ZIndex = 4,
	}, {
		Corner = UDim.new(0, 8)
	})
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.TextYAlignment = Enum.TextYAlignment.Center
	return badge
end

local function createQualityButton(parent, option)
	local button = UIFactory.createTextButton(parent, {
		Name = option.Key .. "Button",
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundColor3 = option.Theme.Background,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = option.LayoutOrder or 1,
		ZIndex = 3,
	}, {
		Corner = UDim.new(0, 12),
		Stroke = {
			Color = option.Theme.Border,
			Thickness = option.Recommended and 2 or 1,
			Transparency = 0.15,
		},
		Padding = {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}
	})

	UIFactory.applyButtonStates(button, {
		Default = option.Theme.Background,
		Hover = option.Theme.Hover,
		Pressed = option.Theme.Pressed,
	})

	local title = UIFactory.createTextLabel(button, {
		Name = "Title",
		Text = option.Label,
		TextColor3 = option.Theme.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local subtitle = UIFactory.createTextLabel(button, {
		Name = "Subtitle",
		Text = option.Description,
		TextColor3 = option.Theme.Subtitle,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 4,
	})

	if option.Recommended then
		createBadge(button)
	end

	return button
end

local function buildInterface()
	local gui = Instance.new("ScreenGui")
	gui.Name = "QualitySelection"
	gui.DisplayOrder = DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = PlayerGui

	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.BackgroundColor3 = UIColors.Overlay
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Selectable = false
	overlay.ZIndex = 1
	overlay.Parent = gui

	local shadow = createShadow(overlay)
	shadow.Visible = false

	local container = UIFactory.createFrame(overlay, {
		Name = "Container",
		Size = CARD_SIZE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = UIColors.Card,
		ZIndex = 2,
	}, {
		Corner = UDim.new(0, 16),
		Stroke = {
			Color = UIColors.Border,
			Transparency = 0.2,
			Thickness = 1,
		}
	})
	container.Visible = false

	UIFactory.createUIPadding(container, {
		PaddingTop = UDim.new(0, 28),
		PaddingBottom = UDim.new(0, 28),
		PaddingLeft = UDim.new(0, 32),
		PaddingRight = UDim.new(0, 32),
	})

	local title = UIFactory.createTextLabel(container, {
		Name = "Title",
		Text = "Pick how you wanna play",
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = UIColors.Text,
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	local subtitle = UIFactory.createTextLabel(container, {
		Name = "Subtitle",
		Text = "Hit a button to hop in.",
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextColor3 = UIColors.TextSecondary,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	local buttonColumn = UIFactory.createFrame(container, {
		Name = "Options",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -120),
		Position = UDim2.new(0, 0, 0, 90),
		ZIndex = 3,
	})

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 16)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = buttonColumn

	local buttons = {}
	for index, option in ipairs(QUALITY_OPTIONS) do
		option.LayoutOrder = index
		local button = createQualityButton(buttonColumn, option)
		buttons[option.Key] = {
			Button = button,
			Option = option,
		}
	end

	return {
		Gui = gui,
		Overlay = overlay,
		Container = container,
		Shadow = shadow,
		Buttons = buttons,
	}
end

function QualityScreen:makeGui()
	if self.Interface then
		return
	end
	self.Interface = buildInterface()
	self.Blur = createBlur()
	for _, buttonInfo in pairs(self.Interface.Buttons) do
		buttonInfo.Button.Activated:Connect(function()
			self:onOptionSelected(buttonInfo.Option)
		end)
	end
end

function QualityScreen:grabSettings()
	local timeout = 20
	local start = os.clock()
	while not (self.UI and self.UI.Settings) do
		if os.clock() - start > timeout then
			warn("[QualityScreen] Timed out waiting for Settings module")
			return nil
		end
		task.wait()
	end
	return self.UI.Settings
end

function QualityScreen:hookSettings(settings)
	self.Settings = settings
	if settings.WaitUntilLoaded then
		settings:WaitUntilLoaded()
	end

	print("Hooked", settings and settings.IsFirstSession)

	if settings.FirstSessionFlagged then
		settings.FirstSessionFlagged:Connect(function(isFirstSession)
			print("[QualityScreen] First session flag fired", isFirstSession)
			if isFirstSession then
				self:Show()
			end
		end)
	end

	if settings.IsFirstSession == true then
		self:Show()
	end
end

function QualityScreen.Init(UI)
	QualityScreen.UI = UI
	QualityScreen.SelectionLocked = false

	task.spawn(function()
		local settings = QualityScreen:grabSettings()
		if not settings then
			print("Failed to get settings")
			return
		end
		QualityScreen:hookSettings(settings)
	end)
end

function QualityScreen:canShow()
	if self.HasSelectedQuality then
		return false
	end
	if not self.Settings then
		return false
	end
	return self.Settings.IsFirstSession == true
end

function QualityScreen:Show()
	if self.Showing then
		return false
	end
	if not self:canShow() then
		print("Blocked from showing")
		return false
	end

	self:makeGui()
	local interface = self.Interface
	if not interface then
		return false
	end

	self.Showing = true
	print("Showing modal")
	interface.Gui.Enabled = true
	interface.Container.Visible = true
	interface.Shadow.Visible = true
	interface.Container.Size = UDim2.new(0, 0, 0, 0)
	interface.Container.Position = UDim2.fromScale(0.5, 0.5)
	interface.Overlay.BackgroundTransparency = 1

	if self.UI and self.UI.ScreenShown then
		self.UI.ScreenShown:Fire("QualityScreen", true)
	end

	local overlayTween = TweenService:Create(interface.Overlay, OVERLAY_TWEEN, {
		BackgroundTransparency = 0.65,
	})
	local containerTween = TweenService:Create(interface.Container, CARD_TWEEN_IN, {
		Size = CARD_SIZE,
	})

	if self.Blur then
		self.Blur.Enabled = true
		TweenService:Create(self.Blur, OVERLAY_TWEEN, {Size = 18}):Play()
	end

	overlayTween:Play()
	containerTween:Play()

	containerTween.Completed:Connect(function()
		self.Shown:Fire()
	end)

	return true
end

function QualityScreen:Hide()
	if not self.Showing or not self.Interface then
		return
	end

	self.Showing = false
	print("Hiding modal")
	local interface = self.Interface

	local overlayTween = TweenService:Create(interface.Overlay, OVERLAY_TWEEN, {
		BackgroundTransparency = 1,
	})
	local containerTween = TweenService:Create(interface.Container, CARD_TWEEN_OUT, {
		Size = UDim2.new(0, 0, 0, 0),
	})

	containerTween.Completed:Connect(function()
		if self.Showing then
			return
		end
		interface.Gui.Enabled = false
		interface.Container.Visible = false
		interface.Shadow.Visible = false
		self.Hidden:Fire()
	end)

	if self.Blur then
		TweenService:Create(self.Blur, OVERLAY_TWEEN, {Size = 0}):Play()
		task.delay(OVERLAY_TWEEN.Time, function()
			if not self.Showing then
				self.Blur.Enabled = false
			end
		end)
	end

	overlayTween:Play()
	containerTween:Play()
	if self.UI and self.UI.ScreenShown then
		self.UI.ScreenShown:Fire("QualityScreen", false)
	end
end

function QualityScreen:onOptionSelected(option)
	if self.SelectionLocked then
		return
	end
	self.SelectionLocked = true
	print("Option picked", option.Key)
	UIAudio.PlayNotification("Click")

	if self.Settings and self.Settings.ChangeSetting then
		self.Settings:ChangeSetting("GraphicsQuality", option.Value)
	end

	LocalPlayer:SetAttribute("QualityMode", option.Key)
	LocalPlayer:SetAttribute("GraphicsQuality", option.Value)
	self.HasSelectedQuality = true
	if self.Settings then
		self.Settings.IsFirstSession = false
	end
	self.QualityChosen:Fire(option.Key, option.Value)

	self:Hide()
	self.SelectionLocked = false
end

return QualityScreen