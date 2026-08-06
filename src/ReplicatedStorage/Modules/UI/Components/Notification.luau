local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIModules = Modules:WaitForChild("UI")
local UIAudio = require(UIModules:WaitForChild("UIAudio"))
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)

local COLORS = {
	Background = UIColors.Background,
	Card = UIColors.Card,
	Text = UIColors.Text,
	SubText = UIColors.TextSecondary,
	Border = UIColors.Border,
	Shadow = UIColors.Shadow,
	Info = UIColors.Info,
	Success = UIColors.Success,
	Warning = UIColors.Warning,
	Error = UIColors.Error,
}

local DEFAULT_ICONS = {
	Info = "ℹ️",
	Success = "🏆",
	Warning = "⚠️",
	Error = "✖️",
}

local ANIMATION_CONFIG = {
	ENTRANCE_TIME = 0.3,
	EXIT_TIME = 0.3,
	FADE_TIME = 0.25,
	HOVER_TIME = 0.2,
	BUTTON_HOVER_TIME = 0.2,
	AUTO_DISMISS_DELAY = 4,
	REMOVAL_WAIT = 0.1,
	CLEANUP_DELAY = 0.3,

	ENTRANCE_EASING = Enum.EasingStyle.Back,
	EXIT_EASING = Enum.EasingStyle.Back,
	FADE_EASING = Enum.EasingStyle.Quad,
	EASING_DIRECTION_IN = Enum.EasingDirection.In,
	EASING_DIRECTION_OUT = Enum.EasingDirection.Out
}

local UI_CONFIG = {
	MAX_NOTIFICATIONS = 4,
	CONTAINER_WIDTH_SCALE = 0.4,
	CONTAINER_HEIGHT_SCALE = 0.44,
	CONTAINER_MARGIN_SCALE = 0.02,
	NOTIFICATION_HEIGHT_SCALE = 0.27,
	NOTIFICATION_SPACING_SCALE = 0.02,

	ACCENT_WIDTH_SCALE = 0.015,
	BORDER_THICKNESS = 1,
	BORDER_TRANSPARENCY = 0.3,
	CORNER_RADIUS = 12,
	ACCENT_CORNER_RADIUS = 3,

	ICON_CONTAINER_SIZE_X_SCALE = 0.12,
	ICON_CONTAINER_SIZE_Y_SCALE = 0.7,
	ICON_MARGIN_X_SCALE = 0.04,
	TEXT_WIDTH_SCALE = 0.66,
	TEXT_HEIGHT_SCALE = 0.72,
	TEXT_OFFSET_SCALE = 0.2,
	CLOSE_BUTTON_SIZE_X_SCALE = 0.06,
	CLOSE_BUTTON_SIZE_Y_SCALE = 0.42,
	CLOSE_HITBOX_SIZE_X_SCALE = 0.08,
	CLOSE_HITBOX_SIZE_Y_SCALE = 0.6,
	CLOSE_MARGIN_X_SCALE = 0.03,
	CLOSE_MARGIN_Y_SCALE = 0.06,

	TEXT_SIZE_MESSAGE = 16,
	TEXT_SIZE_ICON = 18,
	TEXT_SIZE_CLOSE = 18,

	MESSAGE_TOP_PADDING_SCALE = 0.08,
	MESSAGE_HEIGHT_WITH_ACTIONS_SCALE = 0.52,

	ACTION_CONTAINER_HEIGHT_SCALE = 0.4,
	ACTION_BUTTON_WIDTH_SCALE = 0.24,
	ACTION_BUTTON_HEIGHT_SCALE = 0.32,
	ACTION_BUTTON_PADDING_SCALE = 0.04,
	ACTION_BUTTON_TRANSPARENCY = 0.8,
	ACTION_BUTTON_HOVER_TRANSPARENCY = 0.6,
	ACTION_SPACING_SCALE = 0.02,

	DISPLAY_ORDER = 80,
	ENTRANCE_OFFSET_SCALE = 0.08
}

local UI = {
	gui = nil,
	container = nil,
	initialized = false
}

local NotificationList = {}
local Notification = {}

local function getLayout(container)
	local layout = container:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(UI_CONFIG.NOTIFICATION_SPACING_SCALE, 0)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = container
	end
	return layout
end

local function initializeUI(): boolean
	if UI.initialized then return true end

	local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild("NotificationSystem")
	if not (existingGui and existingGui:IsA("ScreenGui")) then
		warn("NotificationSystem ScreenGui not found in PlayerGui")
		return false
	end

	local existingContainer = existingGui:FindFirstChild("Container")
	if not (existingContainer and existingContainer:IsA("Frame")) then
		warn("NotificationSystem.Container not found in PlayerGui")
		return false
	end

	getLayout(existingContainer)
	UI.gui = existingGui
	UI.container = existingContainer
	UI.initialized = true
	return true
end

local function validateConfig(cfg)
	if not cfg or type(cfg) ~= "table" then
		return false, "Configuration must be a table"
	end

	if cfg.Message and type(cfg.Message) ~= "string" then
		return false, "Message must be a string"
	end

	if cfg.Type and not COLORS[cfg.Type] then
		return false, "Invalid notification type: " .. tostring(cfg.Type)
	end

	if cfg.Timeout and (type(cfg.Timeout) ~= "number" or cfg.Timeout < 0) then
		return false, "Timeout must be a positive number"
	end

	if cfg.Actions then
		if type(cfg.Actions) ~= "table" then
			return false, "Actions must be provided as an array"
		end

		for index, action in ipairs(cfg.Actions) do
			if type(action) ~= "table" then
				return false, string.format("Action %d must be a table", index)
			end
			if type(action.Text) ~= "string" or action.Text == "" then
				return false, string.format("Action %d must include Text", index)
			end
			if action.Callback and type(action.Callback) ~= "function" then
				return false, string.format("Action %d callback must be a function", index)
			end
			if action.Dismiss ~= nil and type(action.Dismiss) ~= "boolean" then
				return false, string.format("Action %d dismiss must be a boolean", index)
			end
		end
	end

	return true, nil
end

local function createFrame(parent, size, position, backgroundColor, transparency)
	local frame = Instance.new("Frame", parent)
	frame.Size = size
	frame.Position = position or UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = backgroundColor or COLORS.Card
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, 0)
	return frame
end

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner", parent)
	corner.CornerRadius = UDim.new(0, radius or UI_CONFIG.CORNER_RADIUS)
	return corner
end

local function createStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke", parent)
	stroke.Color = color or COLORS.Border
	stroke.Thickness = thickness or UI_CONFIG.BORDER_THICKNESS
	stroke.Transparency = transparency or UI_CONFIG.BORDER_TRANSPARENCY
	return stroke
end

local function createTextLabel(parent, size, position, text, textColor, textSize, font, alignment)
	local label = Instance.new("TextLabel", parent)
	label.Size = size
	label.Position = position or UDim2.new(0, 0, 0, 0)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = textColor or COLORS.Text
	label.TextSize = textSize or UI_CONFIG.TEXT_SIZE_MESSAGE
	label.Font = font or Enum.Font.SourceSans
	if alignment then
		label.TextXAlignment = alignment.X or Enum.TextXAlignment.Left
		label.TextYAlignment = alignment.Y or Enum.TextYAlignment.Center
	end
	return label
end

local function createButton(parent, size, position)
	local button = Instance.new("TextButton", parent)
	button.Size = size
	button.Position = position or UDim2.new(0, 0, 0, 0)
	button.AnchorPoint = Vector2.new(0, 0)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	return button
end

local function createTweenInfo(duration, easing, direction)
	return TweenInfo.new(duration, easing, direction)
end

local function createEntranceTween(target, endPosition)
	return TweenService:Create(target, 
		createTweenInfo(ANIMATION_CONFIG.ENTRANCE_TIME, ANIMATION_CONFIG.ENTRANCE_EASING, ANIMATION_CONFIG.EASING_DIRECTION_OUT),
		{Position = endPosition}
	)
end

local function createExitTween(target, endPosition, transparency)
	return TweenService:Create(target, 
		createTweenInfo(ANIMATION_CONFIG.EXIT_TIME, ANIMATION_CONFIG.EXIT_EASING, ANIMATION_CONFIG.EASING_DIRECTION_IN),
		{
			Position = endPosition,
			BackgroundTransparency = transparency or 1
		}
	)
end

local function createFadeTween(target, transparency)
	local properties = {}
	if target:IsA("Frame") then
		properties.BackgroundTransparency = transparency
	elseif target:IsA("TextLabel") or target:IsA("TextButton") then
		properties.TextTransparency = transparency
		if target:IsA("TextButton") then
			properties.BackgroundTransparency = transparency
		end
	end

	return TweenService:Create(target,
		createTweenInfo(ANIMATION_CONFIG.FADE_TIME, ANIMATION_CONFIG.FADE_EASING, ANIMATION_CONFIG.EASING_DIRECTION_OUT),
		properties
	)
end

local function createColorTween(target, color)
	return TweenService:Create(target,
		createTweenInfo(ANIMATION_CONFIG.HOVER_TIME, ANIMATION_CONFIG.FADE_EASING, ANIMATION_CONFIG.EASING_DIRECTION_OUT),
		{TextColor3 = color}
	)
end

local function createBackgroundTween(target, transparency)
	return TweenService:Create(target,
		createTweenInfo(ANIMATION_CONFIG.BUTTON_HOVER_TIME, ANIMATION_CONFIG.FADE_EASING, ANIMATION_CONFIG.EASING_DIRECTION_OUT),
		{BackgroundTransparency = transparency}
	)
end

local function applyMessageLayout(label, hasActions)
	if hasActions then
		label.AnchorPoint = Vector2.new(0, 0)
		label.Position = UDim2.new(UI_CONFIG.TEXT_OFFSET_SCALE, 0, UI_CONFIG.MESSAGE_TOP_PADDING_SCALE, 0)
		label.Size = UDim2.new(UI_CONFIG.TEXT_WIDTH_SCALE, 0, UI_CONFIG.MESSAGE_HEIGHT_WITH_ACTIONS_SCALE, 0)
		label.TextYAlignment = Enum.TextYAlignment.Top
	else
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(UI_CONFIG.TEXT_OFFSET_SCALE, 0, 0.5, 0)
		label.Size = UDim2.new(UI_CONFIG.TEXT_WIDTH_SCALE, 0, UI_CONFIG.TEXT_HEIGHT_SCALE, 0)
		label.TextYAlignment = Enum.TextYAlignment.Center
	end
end

local function remove(entry)
	if entry.Removed then
		return
	end

	entry.Removed = true

	for i, v in ipairs(NotificationList) do
		if v == entry then table.remove(NotificationList, i) break end
	end

	local exitTween = createExitTween(entry.Frame, 
		UDim2.new(1 + UI_CONFIG.ENTRANCE_OFFSET_SCALE, 0, entry.Frame.Position.Y.Scale, entry.Frame.Position.Y.Offset)
	)
	exitTween:Play()

	for _, child in pairs(entry.Frame:GetChildren()) do
		local fadeTween = createFadeTween(child, 1)
		if fadeTween then
			fadeTween:Play()
		end
	end

	task.delay(ANIMATION_CONFIG.CLEANUP_DELAY, function()
		if entry.Frame then entry.Frame:Destroy() end
	end)
end

local function createNotificationFrame(parent, notificationType)
	local frame = createFrame(parent, 
		UDim2.new(1, 0, UI_CONFIG.NOTIFICATION_HEIGHT_SCALE, 0),
		UDim2.new(1 + UI_CONFIG.ENTRANCE_OFFSET_SCALE, 0, 0, 0),
		COLORS.Card
	)

	createCorner(frame)
	createStroke(frame)

	local padding = Instance.new("UIPadding", frame)
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)

	local accent = createFrame(frame,
		UDim2.new(UI_CONFIG.ACCENT_WIDTH_SCALE, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		COLORS[notificationType] or COLORS.Info,
		0
	)

	createCorner(accent, UI_CONFIG.ACCENT_CORNER_RADIUS)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(COLORS.Card, UIColors.Background)
	gradient.Rotation = 90
	gradient.Parent = frame

	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://1316045217"
	shadow.ImageColor3 = COLORS.Shadow
	shadow.ImageTransparency = 0.75
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.Size = UDim2.new(1.03, 0, 1.06, 0)
	shadow.Position = UDim2.new(-0.015, 0, -0.02, 0)
	shadow.ZIndex = frame.ZIndex - 1
	shadow.Parent = frame

	return frame
end

local function createNotificationIcon(parent, notificationType, iconText)
	local iconContainer = createFrame(parent,
		UDim2.new(UI_CONFIG.ICON_CONTAINER_SIZE_X_SCALE, 0, UI_CONFIG.ICON_CONTAINER_SIZE_Y_SCALE, 0),
		UDim2.new(UI_CONFIG.ICON_MARGIN_X_SCALE, 0, 0.5, 0),
		(COLORS[notificationType] or COLORS.Info),
		0.15
	)
	iconContainer.AnchorPoint = Vector2.new(0, 0.5)
	createCorner(iconContainer, UI_CONFIG.CORNER_RADIUS)
	createStroke(iconContainer, COLORS.Border, 1, 0.45)

	local iconLabel = createTextLabel(iconContainer,
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0.5, 0),
		iconText or DEFAULT_ICONS[notificationType] or DEFAULT_ICONS.Info,
		COLORS.Text,
		UI_CONFIG.TEXT_SIZE_ICON,
		Enum.Font.GothamBold,
		{X = Enum.TextXAlignment.Center, Y = Enum.TextYAlignment.Center}
	)
	iconLabel.TextScaled = true
	return iconLabel
end

local function createNotificationMessage(parent, messageText)
	local msg = createTextLabel(parent,
		UDim2.new(UI_CONFIG.TEXT_WIDTH_SCALE, 0, UI_CONFIG.TEXT_HEIGHT_SCALE, 0),
		UDim2.new(UI_CONFIG.TEXT_OFFSET_SCALE, 0, 0.5, 0),
		messageText or "Notification",
		COLORS.Text,
		UI_CONFIG.TEXT_SIZE_MESSAGE,
		Enum.Font.Gotham,
		{X = Enum.TextXAlignment.Left, Y = Enum.TextYAlignment.Center}
	)
	msg.TextWrapped = true
	msg.TextScaled = false
	msg.TextSize = UI_CONFIG.TEXT_SIZE_MESSAGE
	local sizeConstraint = msg:FindFirstChildOfClass("UITextSizeConstraint")
	if not sizeConstraint then
		sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.Parent = msg
	end
	sizeConstraint.MinTextSize = 12
	sizeConstraint.MaxTextSize = 18
	return msg
end

local function clearActionButtons(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end



local function createCloseButton(parent, onClose)
	local closeBtn = createTextLabel(parent,
		UDim2.new(UI_CONFIG.CLOSE_BUTTON_SIZE_X_SCALE, 0, UI_CONFIG.CLOSE_BUTTON_SIZE_Y_SCALE, 0),
		UDim2.new(1 - UI_CONFIG.CLOSE_MARGIN_X_SCALE, 0, UI_CONFIG.CLOSE_MARGIN_Y_SCALE, 0),
		"←",
		COLORS.SubText,
		UI_CONFIG.TEXT_SIZE_CLOSE,
		Enum.Font.SourceSansBold
	)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.TextScaled = true

	local closeHitBox = createButton(parent,
		UDim2.new(UI_CONFIG.CLOSE_HITBOX_SIZE_X_SCALE, 0, UI_CONFIG.CLOSE_HITBOX_SIZE_Y_SCALE, 0),
		UDim2.new(1, 0, 0, 0)
	)
	closeHitBox.AnchorPoint = Vector2.new(1, 0)

	closeHitBox.MouseEnter:Connect(function()
		createColorTween(closeBtn, UIColors.ExitBackground):Play()
	end)

	closeHitBox.MouseLeave:Connect(function()
		createColorTween(closeBtn, COLORS.SubText):Play()
	end)

	closeHitBox.MouseButton1Click:Connect(onClose)

	return closeBtn, closeHitBox
end

local function createActionContainer(parent)
	local container = Instance.new("Frame", parent)
	container.Name = "Actions"
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1 - (UI_CONFIG.ACTION_BUTTON_PADDING_SCALE * 2), 0, UI_CONFIG.ACTION_CONTAINER_HEIGHT_SCALE, 0)
	container.Position = UDim2.new(0.5, 0, 1 - UI_CONFIG.ACTION_BUTTON_PADDING_SCALE, 0)
	container.AnchorPoint = Vector2.new(0.5, 1)

	local layout = Instance.new("UIListLayout", container)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(UI_CONFIG.ACTION_SPACING_SCALE, 0)

	return container
end

local function getAccentColor(actionAccent, fallbackType)
	if actionAccent then
		if typeof(actionAccent) == "Color3" then
			return actionAccent
		elseif type(actionAccent) == "string" and COLORS[actionAccent] then
			return COLORS[actionAccent]
		end
	end

	return COLORS[fallbackType] or COLORS.Info
end

local function createActionButton(parent, action, entry)
	local button = Instance.new("TextButton")
	button.Name = "ActionButton"
	button.Size = UDim2.new(UI_CONFIG.ACTION_BUTTON_WIDTH_SCALE, 0, UI_CONFIG.ACTION_BUTTON_HEIGHT_SCALE, 0)
	button.BackgroundColor3 = getAccentColor(action.Accent, entry.Type)
	button.BackgroundTransparency = UI_CONFIG.ACTION_BUTTON_TRANSPARENCY
	button.AutoButtonColor = false
	button.Text = action.Text
	button.TextSize = UI_CONFIG.TEXT_SIZE_MESSAGE
	button.Font = Enum.Font.SourceSans
	button.TextColor3 = COLORS.Text
	button.Parent = parent
	button.TextScaled = true

	createCorner(button, UI_CONFIG.CORNER_RADIUS)
	createStroke(button, button.BackgroundColor3, 1, 0.65)

	button.MouseEnter:Connect(function()
		createBackgroundTween(button, UI_CONFIG.ACTION_BUTTON_HOVER_TRANSPARENCY):Play()
	end)

	button.MouseLeave:Connect(function()
		createBackgroundTween(button, UI_CONFIG.ACTION_BUTTON_TRANSPARENCY):Play()
	end)

	button.MouseButton1Click:Connect(function()
		local shouldDismiss = action.Dismiss
		if shouldDismiss == nil then
			shouldDismiss = true
		end

		if action.Callback then
			local ok, err = pcall(action.Callback, entry)
			if not ok then
				warn("Notification action error:", err)
			end
		end

		if shouldDismiss then
			remove(entry)
		end
	end)

	return button
end

local function createActions(frame, entry, actions)
	if not actions or #actions == 0 then
		return nil
	end

	local container = createActionContainer(frame)
	for _, action in ipairs(actions) do
		createActionButton(container, action, entry)
	end

	return container
end

local function applyTemplate(frame, notificationType, cfg, hasActions, entry)
	frame.Visible = true

	local accent = frame:FindFirstChild("Accent")
	if accent and accent:IsA("Frame") then
		accent.BackgroundColor3 = COLORS[notificationType] or COLORS.Info
	end

	local iconContainer = frame:FindFirstChild("IconContainer")
	if iconContainer and iconContainer:IsA("Frame") then
		iconContainer.BackgroundColor3 = COLORS[notificationType] or COLORS.Info
		local iconLabel = iconContainer:FindFirstChild("IconLabel")
		if iconLabel and iconLabel:IsA("TextLabel") then
			iconLabel.Text = cfg.Icon or DEFAULT_ICONS[notificationType] or DEFAULT_ICONS.Info
		end
	end

	local messageLabel = frame:FindFirstChild("Message")
	if messageLabel and messageLabel:IsA("TextLabel") then
		messageLabel.Text = cfg.Message or "Notification"
		messageLabel.TextScaled = false
		messageLabel.TextSize = UI_CONFIG.TEXT_SIZE_MESSAGE
		local sizeConstraint = messageLabel:FindFirstChildOfClass("UITextSizeConstraint")
		if not sizeConstraint then
			sizeConstraint = Instance.new("UITextSizeConstraint")
			sizeConstraint.Parent = messageLabel
		end
		sizeConstraint.MinTextSize = 12
		sizeConstraint.MaxTextSize = 18
	end

	local closeLabel = frame:FindFirstChild("CloseLabel")
	if closeLabel and closeLabel:IsA("TextLabel") then
		closeLabel.Text = "←"
	end

	local closeHitBox = frame:FindFirstChild("CloseHitBox")
	if closeHitBox and closeHitBox:IsA("TextButton") then
		closeHitBox.Text = ""
		closeHitBox.MouseEnter:Connect(function()
			if closeLabel and closeLabel:IsA("TextLabel") then
				createColorTween(closeLabel, UIColors.ExitBackground):Play()
			end
		end)
		closeHitBox.MouseLeave:Connect(function()
			if closeLabel and closeLabel:IsA("TextLabel") then
				createColorTween(closeLabel, COLORS.SubText):Play()
			end
		end)
		closeHitBox.MouseButton1Click:Connect(function()
			remove(entry)
		end)
	end

	local actionsContainer = frame:FindFirstChild("Actions")
	if actionsContainer and actionsContainer:IsA("Frame") then
		if hasActions then
			actionsContainer.Visible = true
			clearActionButtons(actionsContainer)
			for _, action in ipairs(cfg.Actions) do
				createActionButton(actionsContainer, action, entry)
			end
		else
			actionsContainer.Visible = false
			clearActionButtons(actionsContainer)
		end
	elseif hasActions then
		entry.ActionsContainer = createActions(frame, entry, cfg.Actions)
	end

	return closeLabel, closeHitBox
end

local function resolveTimeout(timeout, hasActions)
	if timeout == nil then
		return hasActions and nil or ANIMATION_CONFIG.AUTO_DISMISS_DELAY
	end

	return timeout > 0 and timeout or nil
end

local function newNotification(cfg)
	local isValid, errorMsg = validateConfig(cfg)
	if not isValid then
		warn("Notification error: " .. errorMsg)
		return nil
	end

	if not initializeUI() then
		return nil
	end

	while #NotificationList >= UI_CONFIG.MAX_NOTIFICATIONS do
		remove(NotificationList[1])
		task.wait(ANIMATION_CONFIG.REMOVAL_WAIT)
	end

	local notificationType = cfg.Type or "Info"
	local entry = {Type = notificationType, Removed = false}
	local actions = cfg.Actions
	local hasActions = type(actions) == "table" and #actions > 0

	local template = UI.container:FindFirstChild("NotificationTemplate")
	if not (template and template:IsA("Frame")) then
		warn("NotificationTemplate missing under NotificationSystem.Container")
		return nil
	end

	local frame = template:Clone()
	frame.Name = "Notification"
	frame.Parent = UI.container
	entry.Frame = frame
	local closeBtn, closeHitBox = applyTemplate(frame, notificationType, cfg, hasActions, entry)
	entry.CloseButton = closeBtn
	entry.CloseHitBox = closeHitBox

	table.insert(NotificationList, entry)

	local entranceTween = createEntranceTween(frame, UDim2.new(0, 0, 0, 0))
	entranceTween:Play()

	UIAudio.PlayNotification(notificationType)

	local timeoutDelay = resolveTimeout(cfg.Timeout, hasActions)
	if timeoutDelay then
		task.delay(timeoutDelay, function()
			if frame and frame.Parent and entry and not entry.Removed then
				remove(entry)
			end
		end)
	end

	return entry
end

function Notification.Hide(entry)
	if entry then
		remove(entry)
	end
end

function Notification.HideAll()
	local listCopy = {}
	for i, entry in ipairs(NotificationList) do
		listCopy[i] = entry
	end

	for _, entry in ipairs(listCopy) do
		remove(entry)
	end
end

function Notification.Init()
	initializeUI()
end

local function createConfig(message, defaultType, options)
	if type(options) == "table" then
		local config = table.clone(options)
		config.Message = config.Message or message
		config.Type = config.Type or defaultType
		return config
	end

	return {
		Message = message,
		Type = defaultType,
		Timeout = options
	}
end

function Notification.Show(cfg)
	return newNotification(cfg)
end

function Notification.Info(message, options)
	return newNotification(createConfig(message, "Info", options))
end

function Notification.Success(message, options)
	return newNotification(createConfig(message, "Success", options))
end

function Notification.Warning(message, options)
	return newNotification(createConfig(message, "Warning", options))
end

function Notification.Error(message, options)
	return newNotification(createConfig(message, "Error", options))
end

return Notification