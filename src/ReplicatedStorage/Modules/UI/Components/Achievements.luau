local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIFolder = Modules:WaitForChild("UI")
local UIAudio = require(UIFolder:WaitForChild("UIAudio"))
local UIFactory = require(UIFolder:WaitForChild("UIFactory"))
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)

local DEFAULT_ICON = "rbxassetid://13655042488"

local COLORS = {
	Background = UIColors.Background,
	Card = UIColors.Card,
	CardStroke = UIColors.Border,
	Icon = UIColors.Card,
	IconStroke = UIColors.Stroke,
	Header = UIColors.Card,
	Text = UIColors.Text,
	TextSecondary = UIColors.TextSecondary,
	Accent = UIColors.Accent,
	Success = UIColors.Success,
	Progress = UIColors.Accent,
	Locked = UIColors.Disabled,
	Shadow = UIColors.Shadow,
	Button = UIColors.Button,
	ButtonHover = UIColors.ButtonHover,
	ButtonPressed = UIColors.ButtonPressed,
	EmptyText = UIColors.TextSecondary,
	Claimable = UIColors.Claimable,
	ClaimableHover = UIColors.ClaimableHover,
	ClaimablePressed = UIColors.ClaimablePressed,
	Claimed = UIColors.Claimed,
}

local CARD_GRADIENT = nil

local ICON_GRADIENT = nil

local function iconAsset(icon)
	local iconType = typeof(icon)
	if iconType == "number" then
		return "rbxassetid://" .. tostring(icon)
	end
	if iconType == "string" then
		if icon == "" then
			return DEFAULT_ICON
		end
		if icon:find("rbxassetid://") or icon:find("rbxasset://") then
			return icon
		end
		return "rbxassetid://" .. icon
	end
	return DEFAULT_ICON
end

local function createBadgeComponent(parent, config)
	local status = config.status or "locked"
	local badgeColor = (status == "unlocked" and COLORS.Success) or
		(status == "progress" and COLORS.Progress) or
		(status == "claimable" and COLORS.Claimable) or
		(status == "claimed" and COLORS.Claimed) or
		COLORS.Locked

	local isClickable = status == "claimable"
	local elementType = isClickable and "TextButton" or "TextLabel"

	local transparency = 0
	if status == "locked" then
		transparency = 0.2
	end

	local badge = UIFactory[isClickable and "createTextButton" or "createTextLabel"](parent, {
		Name = "Badge",
		AnchorPoint = config.anchorPoint or Vector2.new(1, 0),
		Size = config.size or UDim2.new(0, 0, 0, 26),
		Position = config.position or UDim2.new(1, -12, 0, 12),
		BackgroundColor3 = badgeColor,
		BackgroundTransparency = transparency,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = config.text or "Locked",
		AutomaticSize = Enum.AutomaticSize.X,
	}, {
		Corner = UDim.new(1, 0),
		Padding = {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		},
		Stroke = {
			Color = badgeColor,
			Thickness = 2,
			Transparency = 0.3,
		},
	})

	if isClickable and config.onClicked then
		print("Button is clickable, connecting...")
		badge.Activated:Connect(function()
			print("Button clicked!")
			config.onClicked()
		end)

		badge.MouseEnter:Connect(function()
			print("hovered")
			badge.BackgroundColor3 = COLORS.ClaimableHover
		end)

		badge.MouseLeave:Connect(function()
			badge.BackgroundColor3 = COLORS.Claimable
		end)

		badge.MouseButton1Down:Connect(function()
			badge.BackgroundColor3 = COLORS.ClaimablePressed
		end)

		badge.MouseButton1Up:Connect(function()
			badge.BackgroundColor3 = COLORS.ClaimableHover
		end)
	end

	return badge
end

local function createProgressBarComponent(parent, config)
	local status = config.status or "progress"
	local fillColor = (status == "unlocked" and COLORS.Success) or
		(status == "claimable" and COLORS.Claimable) or
		(status == "claimed" and COLORS.Claimed) or
		COLORS.Progress

	local progressBar = UIFactory.createFrame(parent, {
		Name = "ProgressBar",
		Size = config.size or UDim2.new(0, 220, 0, 6),
		Position = config.position or UDim2.new(0, 80, 1, -20),
		BackgroundColor3 = UIColors.DarkBackground,
		BorderSizePixel = 0,
	}, {
		Corner = UDim.new(0, 3),
	})

	local fill = UIFactory.createFrame(progressBar, {
		Name = "Fill",
		Size = UDim2.new(math.clamp(config.percent or 0, 0, 1), 0, 1, 0),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
	}, {
		Corner = UDim.new(0, 3),
	})

	return progressBar, fill
end

local LayoutManager = {}
LayoutManager.__index = LayoutManager

function LayoutManager.new(frame)
	local self = setmetatable({}, LayoutManager)
	self.frame = frame
	self.updateCallbacks = {}
	self.connections = {}
	return self
end

function LayoutManager:addUpdateCallback(callback)
	table.insert(self.updateCallbacks, callback)
end

function LayoutManager:bindToProperty(object, property)
	local connection = object:GetPropertyChangedSignal(property):Connect(function()
		self:update()
	end)
	table.insert(self.connections, connection)
end

function LayoutManager:update()
	for _, callback in self.updateCallbacks do
		callback()
	end
end

function LayoutManager:destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.connections = {}
	self.updateCallbacks = {}
end

local function formatNumber(value)
	local num = math.floor(tonumber(value) or 0)
	local formatted = tostring(num)
	local k
	repeat
		formatted, k = formatted:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

local function formatCoins(amount)
	return string.format("💰 %s", formatNumber(amount or 0))
end

local AchievementsPanel = {}
AchievementsPanel.__index = AchievementsPanel
AchievementsPanel.ComponentName = "Achievements"
AchievementsPanel.UI = nil
AchievementsPanel._instances = {}
AchievementsPanel.Controller = nil

local function addConnection(target, connection)
	table.insert(target, connection)
end

local function createHeader(parent, categoryName, categoryColor, layoutOrder)
	local accent = categoryColor or COLORS.Accent
	local header = UIFactory.createTextLabel(parent, {
		Name = "CategoryHeader",
		Size = UDim2.new(1, -8, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = accent,
		Text = string.upper(categoryName or "Category"),
		LayoutOrder = layoutOrder,
	})

	UIFactory.createFrame(header, {
		Name = "Underline",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(0, 32, 0, 2),
		Position = UDim2.new(0, 2, 1, -2),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	})

	return header
end

local function createAchievementFrame(parent, entry, layoutOrder, controller)
	local status = entry.badgeTheme or "locked"
	local progressStatus = entry.progressTheme or "progress"

	local frame = UIFactory.createFrame(parent, {
		Name = entry.id or "Achievement",
		Size = UDim2.new(1, -8, 0, 92),
		BackgroundColor3 = COLORS.Card,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		Corner = UDim.new(0, 12),
		Stroke = {
			Color = COLORS.CardStroke,
			Thickness = 1,
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
		},
	})

	local iconHolder = UIFactory.createFrame(frame, {
		Name = "IconHolder",
		Size = UDim2.new(0, 48, 0, 48),
		Position = UDim2.new(0, 16, 0.5, -24),
		BackgroundTransparency = 0.85,
		BackgroundColor3 = COLORS.Accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		Corner = UDim.new(0, 24),
		Stroke = {
			Color = COLORS.IconStroke,
			Thickness = 1,
			Transparency = 0.7,
		},
	})

	UIFactory.createImageLabel(iconHolder, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1,
		Image = iconAsset(entry.icon),
		ImageColor3 = Color3.new(1, 1, 1),
		ImageTransparency = 0,
		ZIndex = 3,
	})

	local badge = createBadgeComponent(frame, {
		status = status,
		text = entry.statusText or "Locked",
		position = UDim2.new(1, -12, 0, 12),
		onClicked = (status == "claimable") and function()
			print("Claim button clicked for:", entry.id)
			print("Controller:", controller)
			if controller and controller.ClaimAchievement then
				print("Calling ClaimAchievement")
				controller:ClaimAchievement(entry.id)
			else
				print("Controller or ClaimAchievement method not found!")
			end
		end or nil,
	})

	local contentArea = UIFactory.createFrame(frame, {
		Name = "ContentArea",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 80, 0, 12),
		Size = UDim2.new(1, -212, 1, -28),
	})

	local title = UIFactory.createTextLabel(contentArea, {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = entry.name or entry.id or "Achievement",
	})

	local description = UIFactory.createTextLabel(contentArea, {
		Name = "Description",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 26),
		BackgroundTransparency = 1,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = COLORS.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.None,
		Text = entry.description or "",
	})

	local progressBar, fill = createProgressBarComponent(frame, {
		status = progressStatus,
		percent = entry.percent or 0,
		position = UDim2.new(0, 80, 1, -20),
		size = UDim2.new(0, 220, 0, 6),
	})

	local progressText = UIFactory.createTextLabel(progressBar, {
		Name = "ProgressText",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamSemibold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = COLORS.Text,
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = UIColors.StrokeBlack,
		ZIndex = 2,
		Text = entry.progressText or "",
	})

	return frame
end

function AchievementsPanel.new(parent, callbacks, controller)
	local self = setmetatable({}, AchievementsPanel)
	callbacks = callbacks or {}

	table.insert(AchievementsPanel._instances, self)

	self._connections = {}
	self._entries = {}
	self._onClose = callbacks.OnClose
	self._screenConnection = nil
	self._controller = controller

	local shell = UIFactory.createSidebar(parent, {
		Name = "AchievementInterface",
		DisplayOrder = 45,
		RootSize = UDim2.new(0.34, 0, 0.78, 0),
		RootPosition = UDim2.new(1, -24, 0.12, 0),
		MinSize = Vector2.new(380, 420),
		MaxSize = Vector2.new(620, 760),
		ContainerBackgroundTransparency = 0,
		ContainerStrokeThickness = 1.2,
		ContainerStrokeTransparency = 0.5,
		Colors = {
			Background = COLORS.Background,
			Header = COLORS.Header,
			ContainerStroke = COLORS.CardStroke,
			Shadow = COLORS.Shadow,
		},
		ShadowTransparency = 1,
		HeaderHeight = 68,
		Title = {
			Text = "Achievements",
			Font = Enum.Font.GothamBold,
			TextSize = 28,
			TextColor3 = COLORS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -160, 0, 30),
			Position = UDim2.new(0, 20, 0.5, -15),
		},
		CloseButton = {
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(1, -20, 0.5, 0),
			BackgroundColor3 = COLORS.Button,
			TextColor3 = COLORS.Text,
			Text = "X",
			TextSize = 20,
			ZIndex = 10,
		},
	})

	local gui = shell.Gui
	local root = shell.Root
	local shadow = shell.Shadow
	local container = shell.Container
	local headerFrame = shell.Header
	local closeButton = shell.CloseButton

	local backing = UIFactory.createFrame(container, {
		Name = "Backing",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = COLORS.Shadow,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = container.ZIndex - 1,
	}, {
		Corner = UDim.new(0, 12),
	})

	local currencyPill = UIFactory.createFrame(headerFrame, {
		Name = "CurrencyPill",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, 160, 0, 32),
		Position = UDim2.new(1, -68, 0.5, 0),
		BackgroundColor3 = COLORS.Background,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, {
		Corner = UDim.new(1, 0),
		Stroke = {
			Color = COLORS.CardStroke,
			Thickness = 1,
			Transparency = 0.5,
		},
	})

	local currencyLabel = UIFactory.createTextLabel(currencyPill, {
		Name = "CurrencyLabel",
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = formatCoins(0),
		ZIndex = 4,
	})

	local descriptionLabel = UIFactory.createTextLabel(container, {
		Name = "Description",
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.new(0, 20, 0, 96),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = COLORS.TextSecondary,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Complete milestones to unlock new rewards and perks.",
		ZIndex = 2,
	})

	local scroll = UIFactory.createScrollingFrame(container, {
		Name = "List",
		Position = UDim2.new(0, 20, 0, 130),
		Size = UDim2.new(1, -40, 1, -170),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COLORS.Accent,
		ScrollBarImageTransparency = 0.2,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 1,
	})

	UIFactory.createUIPadding(scroll, {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 24),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	})

	if closeButton then
		table.insert(self._connections, closeButton.Activated:Connect(function()
			self:Hide()
		end))

		for _, connection in ipairs(UIFactory.applyButtonStates(closeButton, {
			Default = COLORS.Button,
			Hover = COLORS.ButtonHover,
			Pressed = COLORS.ButtonPressed,
			})) do
			addConnection(self._connections, connection)
		end
	end

	local listLayout = UIFactory.createUIListLayout(scroll, {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	})

	local emptyLabel = UIFactory.createTextLabel(scroll, {
		Name = "EmptyLabel",
		Size = UDim2.new(1, -20, 0, 72),
		Position = UDim2.new(0, 10, 0, 16),
		BackgroundTransparency = 1,
		Text = "Progress will appear here as you explore!",
		TextWrapped = true,
		TextColor3 = COLORS.EmptyText,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 1,
		Visible = false,
	})

	local layoutConnection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 32)
	end)

	table.insert(self._connections, layoutConnection)

	self.Gui = gui
	self.Root = root
	self.Shadow = shadow
	self.Container = container
	self.DescriptionLabel = descriptionLabel
	self.CurrencyLabel = currencyLabel
	self.ScrollFrame = scroll
	self.EmptyLabel = emptyLabel
	self.ListLayout = listLayout
	self._scale = shell.Scale
	self._control = nil
	self._isVisible = false
	self._activeTween = nil
	self._activeTweenConnection = nil

	return self
end

function AchievementsPanel:_clearEntries()
	for _, entry in ipairs(self._entries) do
		if entry and entry.Parent then
			entry:Destroy()
		end
	end
	self._entries = {}
end

function AchievementsPanel:_bindScreenShown()
	if self._screenConnection then
		return
	end

	if AchievementsPanel.UI and AchievementsPanel.UI.ScreenShown then
		self._screenConnection = AchievementsPanel.UI.ScreenShown:Connect(function(componentName, isVisible)
			if componentName ~= AchievementsPanel.ComponentName and isVisible and self:IsVisible() then
				if self._onClose then
					self._onClose()
				else
					self:Hide()
				end
			end
		end)
		table.insert(self._connections, self._screenConnection)
	end
end

function AchievementsPanel:_getControl()
	if self._control or not AchievementsPanel.UI or not self.Root then
		return self._control
	end

	local control = AchievementsPanel.UI:Get(self.Root)
	local startPosition = self.Root.Position
	control.ComponentName = AchievementsPanel.ComponentName
	control.StartPosition = startPosition
	control.HiddenPosition = UDim2.new(startPosition.X.Scale + 0.42, startPosition.X.Offset, startPosition.Y.Scale, startPosition.Y.Offset)
	control.TweenStyles = {
		InTweenInfo = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		OutTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
	}
	control:CreateTweens()

	self._control = control
	return control
end

function AchievementsPanel:_stopActiveTween()
	if self._activeTween then
		self._activeTween:Cancel()
		self._activeTween = nil
	end

	if self._activeTweenConnection then
		self._activeTweenConnection:Disconnect()
		self._activeTweenConnection = nil
	end
end

function AchievementsPanel:_playScaleTween(targetScale, tweenInfo, onComplete)
	if not self._scale then
		if onComplete then
			onComplete()
		end
		return
	end

	self:_stopActiveTween()

	local tween = TweenService:Create(self._scale, tweenInfo, {
		Scale = targetScale,
	})
	self._activeTween = tween
	self._activeTweenConnection = tween.Completed:Connect(function()
		if self._activeTween == tween then
			self:_stopActiveTween()
			if onComplete then
				onComplete()
			end
		end
	end)

	tween:Play()
end

function AchievementsPanel:Destroy()
	self:_clearEntries()
	self:_stopActiveTween()
	for index, instance in ipairs(AchievementsPanel._instances) do
		if instance == self then
			table.remove(AchievementsPanel._instances, index)
			break
		end
	end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
	self._screenConnection = nil

	if self.Gui then
		self.Gui:Destroy()
		self.Gui = nil
	end
end

function AchievementsPanel:Show()
	if not self.Gui then
		return
	end

	if self._isVisible then
		self.Gui.Enabled = true
		return
	end

	self:_stopActiveTween()

	self.Gui.Enabled = true

	if self.Root then
		self.Root.Visible = true
	end

	if self.Shadow then
		self.Shadow.Visible = true
	end

	if self._scale then
		self._scale.Scale = 1
	end

	local control = self:_getControl()
	if control then
		self.Root.Position = control.Positions.Hidden
		control:Show()
	end

	self._isVisible = true

	if UIAudio and UIAudio.PlayNotification then
		UIAudio.PlayNotification("Open")
	end
end

function AchievementsPanel:Hide()
	if not self.Gui then
		return
	end

	if not self._isVisible and not self.Gui.Enabled then
		return
	end

	self:_stopActiveTween()

	local finalize = function()
		if self.Gui then
			self.Gui.Enabled = false
		end

		if self.Root then
			self.Root.Visible = false
		end

		if self.Shadow then
			self.Shadow.Visible = false
		end

		if self._scale then
			self._scale.Scale = 1
		end
	end

	local wasVisible = self._isVisible
	self._isVisible = false

	if wasVisible then
		if UIAudio and UIAudio.PlayNotification then
			UIAudio.PlayNotification("Close")
		end
		local control = self:_getControl()
		if control then
			control:Hide()
			finalize()
		else
			finalize()
		end
	else
		finalize()
	end
end

function AchievementsPanel:IsVisible()
	return self._isVisible == true
end

function AchievementsPanel:SetCoins(amount)
	if self.CurrencyLabel then
		self.CurrencyLabel.Text = formatCoins(amount)
	end
end

function AchievementsPanel:Render(entries)
	if not self.ScrollFrame then
		return
	end

	self:_clearEntries()

	if not entries or #entries == 0 then
		self.EmptyLabel.Visible = true
		return
	end

	self.EmptyLabel.Visible = false

	local layoutOrder = 0
	local currentCategory = nil

	for _, entry in ipairs(entries) do
		local category = entry.category or {}
		local categoryName = category.name or "General"
		local categoryColor = category.color

		if currentCategory ~= categoryName then
			currentCategory = categoryName
			local header = createHeader(self.ScrollFrame, categoryName, categoryColor, layoutOrder)
			table.insert(self._entries, header)
			layoutOrder += 1
		end

		local frame = createAchievementFrame(self.ScrollFrame, entry, layoutOrder, self._controller)
		table.insert(self._entries, frame)
		layoutOrder += 1
	end
end

function AchievementsPanel.Init(ui)
	AchievementsPanel.UI = ui
	for _, instance in ipairs(AchievementsPanel._instances) do
		if instance and instance._bindScreenShown then
			instance:_bindScreenShown()
		end
	end

	task.spawn(function()
		if ui and ui.LoadedSignal then
			if not ui.Loaded then
				ui.LoadedSignal:Wait()
			end
		end

		if ui and ui.ScreenShown then
			ui.ScreenShown:Connect(function(componentName, isVisible)
				if isVisible and componentName ~= AchievementsPanel.ComponentName then
					for _, instance in ipairs(AchievementsPanel._instances) do
						if instance and instance:IsVisible() then
							instance:Hide()
						end
					end
				end
			end)
		end
	end)
end

local function getActivePanel()
	for index = #AchievementsPanel._instances, 1, -1 do
		local instance = AchievementsPanel._instances[index]
		if instance and instance.Gui then
			return instance
		end
	end
	return nil
end

local function Show()
	if AchievementsPanel.Controller and AchievementsPanel.Controller.Show then
		AchievementsPanel.Controller:Show()
		return
	end

	local panel = getActivePanel()
	if panel then
		panel:Show()
	end
end

local function Hide()
	if AchievementsPanel.Controller and AchievementsPanel.Controller.Hide then
		AchievementsPanel.Controller:Hide()
		return
	end

	local panel = getActivePanel()
	if panel then
		panel:Hide()
	end
end

local function Toggle()
	if AchievementsPanel.Controller and AchievementsPanel.Controller.Toggle then
		AchievementsPanel.Controller:Toggle()
		return
	end

	local panel = getActivePanel()
	if not panel then
		return
	end

	if panel:IsVisible() then
		panel:Hide()
	else
		panel:Show()
	end
end

local function IsVisible()
	local panel = getActivePanel()
	if not panel then
		return false
	end

	return panel:IsVisible()
end

return {
	new = AchievementsPanel.new,
	Init = AchievementsPanel.Init,
	Show = Show,
	Hide = Hide,
	Toggle = Toggle,
	IsVisible = IsVisible,
}
