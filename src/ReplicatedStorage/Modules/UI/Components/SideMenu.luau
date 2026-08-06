local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)
local Mince = require(ReplicatedStorage.Modules.Mince)

local TWEEN_CONFIG = {
	HOVER_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	CLICK_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
	MENU_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
}

local BUTTON_CONFIG = {
	HOVER_SCALE = 1.08,
	CLICK_SCALE = 0.92,
	HOVER_TRANSPARENCY_DELTA = -0.15,
	CLICK_TRANSPARENCY_DELTA = -0.22,
	HOVER_ROTATION = 15,
	CLICK_ROTATION = -20
}

local SPINNING_IMAGE_CONFIG = {
	SPIN_DURATION = 10,
	ROTATION_OFFSET = 120,
}

local UI = {
	gui = nil,
	main = nil,
	initialized = false
}

local currentTweens = {}
local connections = {}
local notificationSizeCache = setmetatable({}, {__mode = "k"})
local registeredButtons = {}

local SideMenu = {
	_originalPosition = nil,
	_hiddenPosition = nil,
	_isVisible = true,
}

local function addConnection(connection)
	if connection and typeof(connection) == "RBXScriptConnection" then
		table.insert(connections, connection)
	end
end

local function initUI()
	if UI.initialized then return end
	UI.gui = PlayerGui:WaitForChild("SideMenu")
	UI.main = UI.gui:WaitForChild("Main")
	UI.initialized = true
end

local function cleanupTweens(...)
	local specificKeys = {...}
	if #specificKeys > 0 then
		for _, key in specificKeys do
			if currentTweens[key] then
				currentTweens[key]:Cancel()
				currentTweens[key] = nil
			end
		end
	else
		for key, tween in currentTweens do
			if tween and typeof(tween) == "Instance" then
				tween:Cancel()
			end
			currentTweens[key] = nil
		end
		currentTweens = {}
	end
end

local function scaleUDim2(size, factor)
	return UDim2.new(
		size.X.Scale * factor,
		size.X.Offset ~= 0 and math.floor(size.X.Offset * factor + 0.5) or size.X.Offset,
		size.Y.Scale * factor,
		size.Y.Offset ~= 0 and math.floor(size.Y.Offset * factor + 0.5) or size.Y.Offset
	)
end

local function calculateButtonSizes(originalSize)
	local hoverSize = scaleUDim2(originalSize, BUTTON_CONFIG.HOVER_SCALE)
	local clickSize = scaleUDim2(originalSize, BUTTON_CONFIG.CLICK_SCALE)
	return hoverSize, clickSize
end

local function offsetPosition(pos, deltaX, deltaY)
	return UDim2.new(pos.X.Scale, pos.X.Offset + deltaX, pos.Y.Scale, pos.Y.Offset + deltaY)
end

local function computeHiddenPosition()
	if not UI.main then
		return nil
	end

	local original = SideMenu._originalPosition or UI.main.Position
	local width = UI.main.AbsoluteSize.X
	local buffer = 24
	local hiddenOffset = -(width + buffer)
	return offsetPosition(original, hiddenOffset, 0)
end

local function createButtonTween(object, tweenInfo, properties, key)
	cleanupTweens(key)
	local tween = TweenService:Create(object, tweenInfo, properties)
	currentTweens[key] = tween
	addConnection(tween.Completed:Connect(function()
		currentTweens[key] = nil
	end))
	return tween
end

local function clearAllConnections()
	for _, conn in ipairs(connections) do
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	connections = {}
end

local function clearAllTweens()
	cleanupTweens()
end

local function getNotificationTweenKey(notification)
	return notification or "notification_heartbeat"
end

local function isValidButton(button)
	return button and typeof(button) == "Instance" and button:IsA("GuiButton")
end

local function isValidUIComponent(component)
	return component and (component.Toggle or component.Show)
end

local function getAvailableUIComponents(uiMapping)
	local components = {}
	for name, _ in pairs(uiMapping) do
		table.insert(components, name)
	end
	return components
end

local function setupSpinningImages(container, buttonKey)
	if not container then return end

	local imageLabels = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ImageLabel") then
			table.insert(imageLabels, child)
		end
	end

	if #imageLabels == 0 then return end

	for index, imageLabel in ipairs(imageLabels) do
		imageLabel.Rotation = (index - 1) * SPINNING_IMAGE_CONFIG.ROTATION_OFFSET
	end

	for index, imageLabel in ipairs(imageLabels) do
		local spinKey = buttonKey .. "_spin_" .. index
		cleanupTweens(spinKey)

		local tweenInfo = TweenInfo.new(
			SPINNING_IMAGE_CONFIG.SPIN_DURATION,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut,
			-1,
			false,
			0
		)

		local tween = TweenService:Create(
			imageLabel,
			tweenInfo,
			{Rotation = 360 + (index - 1) * SPINNING_IMAGE_CONFIG.ROTATION_OFFSET}
		)

		currentTweens[spinKey] = tween
		addConnection(tween.Completed:Connect(function()
			currentTweens[spinKey] = nil
		end))
		tween:Play()
	end
end

function SideMenu.ShowNotification(buttonInstance)
	if not buttonInstance or not buttonInstance.Notification then
		return
	end

	local notification = buttonInstance.Notification
	local tweenKey = getNotificationTweenKey(notification)
	local originalSize = notificationSizeCache[notification]
	if not originalSize then
		return
	end

	notification.Size = originalSize
	notification.Visible = true

	cleanupTweens(tweenKey)
	local pulseSize = scaleUDim2(originalSize, 1.25)
	local breathingTween = TweenService:Create(
		notification,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0),
		{Size = pulseSize}
	)
	currentTweens[tweenKey] = breathingTween
	breathingTween:Play()
end

function SideMenu.HideNotification(buttonInstance)
	if not buttonInstance or not buttonInstance.Notification then
		return
	end

	local notification = buttonInstance.Notification
	local tweenKey = getNotificationTweenKey(notification)
	cleanupTweens(tweenKey)

	local originalSize = notificationSizeCache[notification]
	if originalSize then
		notification.Size = originalSize
	end
	buttonInstance.Notification.Visible = false
end

function SideMenu.SetupButtonHoverEffects(button, buttonKey, container)
	if not button then return end

	button.AutoButtonColor = false

	local target = container and container:IsA("GuiObject") and container or button

	local originalSize = target.Size
	local hoverSize, clickSize = calculateButtonSizes(originalSize)

	local hasBackground = target.BackgroundTransparency < 1
	local originalBackgroundColor = target.BackgroundColor3
	local originalBackgroundTransparency = target.BackgroundTransparency

	local stroke = target:FindFirstChildOfClass("UIStroke")
	local originalStrokeTransparency = stroke and stroke.Transparency or nil

	local hoverTransparency = hasBackground and math.clamp(originalBackgroundTransparency + BUTTON_CONFIG.HOVER_TRANSPARENCY_DELTA, 0, 1) or originalBackgroundTransparency
	local clickTransparency = hasBackground and math.clamp(originalBackgroundTransparency + BUTTON_CONFIG.CLICK_TRANSPARENCY_DELTA, 0, 1) or originalBackgroundTransparency

	local isHovered = false

	local stateConfigs = {
		normal = {
			size = originalSize,
			rotation = 0,
			backgroundTransparency = originalBackgroundTransparency,
			strokeTransparency = originalStrokeTransparency,
			tween = TWEEN_CONFIG.HOVER_INFO,
		},
		hover = {
			size = hoverSize,
			rotation = BUTTON_CONFIG.HOVER_ROTATION,
			backgroundTransparency = hoverTransparency,
			strokeTransparency = originalStrokeTransparency and math.max(originalStrokeTransparency - 0.25, 0) or nil,
			tween = TWEEN_CONFIG.HOVER_INFO,
		},
		click = {
			size = clickSize,
			rotation = BUTTON_CONFIG.CLICK_ROTATION,
			backgroundTransparency = clickTransparency,
			strokeTransparency = originalStrokeTransparency and math.max(originalStrokeTransparency - 0.4, 0) or nil,
			tween = TWEEN_CONFIG.CLICK_INFO,
		}
	}

	local function applyState(stateKey, suffix)
		local config = stateConfigs[stateKey]
		if not config then
			return
		end

		local frameProps = {
			Size = config.size
		}

		if hasBackground and config.backgroundTransparency ~= nil then
			frameProps.BackgroundTransparency = config.backgroundTransparency
		end

		local keyBase = buttonKey .. "_" .. (suffix or stateKey)
		createButtonTween(target, config.tween, frameProps, keyBase .. "_frame"):Play()

		createButtonTween(button, config.tween, {Rotation = config.rotation}, keyBase .. "_button"):Play()

		if stroke then
			local strokeProps = {}
			if config.strokeTransparency ~= nil then
				strokeProps.Transparency = config.strokeTransparency
			end
			if next(strokeProps) then
				createButtonTween(stroke, config.tween, strokeProps, keyBase .. "_stroke"):Play()
			end
		end
	end

	applyState("normal", "normal")

	addConnection(button.MouseEnter:Connect(function()
		isHovered = true
		applyState("hover", "hover")
	end))

	addConnection(button.MouseLeave:Connect(function()
		isHovered = false
		cleanupTweens(
			buttonKey .. "_hover_frame",
			buttonKey .. "_hover_stroke",
			buttonKey .. "_hover_button",
			buttonKey .. "_down_frame",
			buttonKey .. "_down_stroke",
			buttonKey .. "_down_button"
		)
		applyState("normal", "normal")
	end))

	addConnection(button.MouseButton1Down:Connect(function()
		applyState("click", "down")
	end))

	addConnection(button.MouseButton1Up:Connect(function()
		cleanupTweens(
			buttonKey .. "_down_frame",
			buttonKey .. "_down_stroke",
			buttonKey .. "_down_button"
		)
		if isHovered then
			applyState("hover", "hover")
		else
			applyState("normal", "normal")
		end
	end))
end

function SideMenu.newButton(button, UIManager, frameName, container)
	if not isValidButton(button) or not frameName then 
		warn("SideMenu: Invalid button or frameName provided")
		return nil
	end

	local self = setmetatable({}, {__index = SideMenu})
	self.Button = button
	self.FrameName = frameName
	self.Notification = container and container:FindFirstChild("Notification") or nil

	addConnection(button.MouseButton1Click:Connect(function()
		SideMenu.HideNotification(self)
		SideMenu.HandleButtonClick(UIManager, frameName)
	end))

	SideMenu.SetupButtonHoverEffects(button, frameName, container)

	registeredButtons[frameName] = self

	return self
end

function SideMenu.GetButton(frameName)
	return registeredButtons[frameName]
end

function SideMenu.GetButtonInstance(frameName)
	local entry = registeredButtons[frameName]
	return entry and entry.Button or nil
end

function SideMenu.HandleButtonClick(UIManager, frameName)
	local uiMapping = {
		["Settings"] = UIManager.Settings,
		["Shop"] = UIManager.Shop,
		["Achievements"] = UIManager.Achievements,
		["CameraAngles"] = UIManager.CameraAngles,
		["Encyclopedia"] = UIManager.Encyclopedia,
		["Starterpack"] = UIManager.StarterPack,
	}

	local targetUI = uiMapping[frameName]

	if targetUI and isValidUIComponent(targetUI) then
		if targetUI.Toggle then
			targetUI:Toggle()
		else
			targetUI.Show()
		end
	elseif targetUI then
		warn("SideMenu: UI component '" .. frameName .. "' doesn't have Toggle() or Show() method")
	else
		warn("SideMenu: No UI mapping found for frame '" .. frameName .. "'")
		local availableComponents = getAvailableUIComponents(uiMapping)
		print("Available UI components:", table.concat(availableComponents, ", "))
	end
end

function SideMenu.Hide()
	initUI()

	if not UI.main or not UI.main:IsDescendantOf(PlayerGui) then
		return
	end

	if not SideMenu._isVisible then
		return
	end

	SideMenu._originalPosition = SideMenu._originalPosition or UI.main.Position
	SideMenu._hiddenPosition = computeHiddenPosition() or SideMenu._hiddenPosition or UI.main.Position

	local targetPosition = SideMenu._hiddenPosition
	if not targetPosition then
		return
	end

	SideMenu._isVisible = false
	UI.main.Visible = true

	local tween = createButtonTween(UI.main, TWEEN_CONFIG.MENU_INFO, {Position = targetPosition}, "menu_position")
	addConnection(tween.Completed:Connect(function()
		if not SideMenu._isVisible then
			UI.main.Visible = false
		end
	end))
	tween:Play()
end

function SideMenu.Show()
	initUI()

	if not UI.main or not UI.main:IsDescendantOf(PlayerGui) then
		return
	end

	if SideMenu._isVisible then
		return
	end

	local original = SideMenu._originalPosition or UI.main.Position
	local hidden = SideMenu._hiddenPosition or computeHiddenPosition()

	SideMenu._isVisible = true
	UI.main.Visible = true

	if hidden then
		UI.main.Position = hidden
	end

	local tween = createButtonTween(UI.main, TWEEN_CONFIG.MENU_INFO, {Position = original}, "menu_position")
	addConnection(tween.Completed:Connect(function()
		if SideMenu._isVisible then
			UI.main.Position = original
		end
	end))
	tween:Play()
end

function SideMenu.Init(UIManager)
	initUI()

	if not UIManager then
		warn("SideMenu: UIManager is required for initialization")
		return
	end

	SideMenu._originalPosition = UI.main.Position
	SideMenu._hiddenPosition = computeHiddenPosition()
	SideMenu._isVisible = true

	UI.main.Visible = true

	local starterpackFrame = nil

	for _, frame in UI.main:GetChildren() do
		if frame:IsA("Frame") and frame.Name then
			if frame.Name == "Starterpack" then
				starterpackFrame = frame
				if LocalPlayer:GetAttribute("StarterPackPass") == true then
					frame.Visible = false
					continue
				end
			end

			local imageButton = frame:FindFirstChildWhichIsA("ImageButton")
			if imageButton then
				local buttonInstance = SideMenu.newButton(imageButton, UIManager, frame.Name, frame)
				local notification = frame:FindFirstChild("Notification")
				if notification then
					notificationSizeCache[notification] = notification.Size
				end
				if buttonInstance then
					SideMenu[frame.Name] = buttonInstance
				end

				if frame.Name == "Starterpack" then
					setupSpinningImages(frame, frame.Name)
				end
			end
		end
	end

	Mince.UponStart:Once(function()
		local scanController = Mince:Get("ScanController")
		if scanController and scanController.FishScanned then
			addConnection(scanController.FishScanned:Connect(function(fishId, fishName, scanCount, discoveredCount, isNewDiscovery)
				if isNewDiscovery and SideMenu.Encyclopedia then
					SideMenu.ShowNotification(SideMenu.Encyclopedia)
				end
			end))
		end

		local discoveryManager = Mince:Get("DiscoveryManager")
		if discoveryManager and discoveryManager.Discoveries and SideMenu.Encyclopedia then
			local hasDiscoveries = false
			for _, discoveries in pairs(discoveryManager.Discoveries) do
				if discoveries and next(discoveries) then
					hasDiscoveries = true
					break
				end
			end
			if hasDiscoveries then
				SideMenu.ShowNotification(SideMenu.Encyclopedia)
			end
		end

		local achievementController = Mince:Get("AchievementController")
		local achievementRemote = Mince:GetEvent("Achievements")
		if achievementRemote and achievementController then
			local function updateNotif()
				if SideMenu.Achievements and achievementController.AchievementData then
					local fullData = achievementController.AchievementData

					local hasClaimable = false
					local claimedMap = fullData.Claimed or {}
					if fullData and fullData.Progress then
						for achievementId, progress in pairs(fullData.Progress) do
							if progress.Unlocked and not claimedMap[achievementId] then
								hasClaimable = true
								break
							end
						end
					end
					if not hasClaimable then
						SideMenu.HideNotification(SideMenu.Achievements)
					else
						SideMenu.ShowNotification(SideMenu.Achievements)
					end
				end
			end

			local updateEvent = achievementRemote:Extend("Update")
			if updateEvent then
				addConnection(updateEvent.Event:Connect(function(achievementData)
					updateNotif()
				end))
			end

			local toastEvent = achievementRemote:Extend("Toast")
			if toastEvent then
				addConnection(toastEvent.Event:Connect(function()
					if SideMenu.Achievements then
						updateNotif()
					end
				end))
			end

			task.wait(0.1)
			updateNotif()
		end

		addConnection(LocalPlayer:GetAttributeChangedSignal("StarterPackPass"):Connect(function()
			if LocalPlayer:GetAttribute("StarterPackPass") == true and starterpackFrame then
				starterpackFrame.Visible = false
			end
		end))
	end)
end

function SideMenu.Cleanup()
	clearAllConnections()
	clearAllTweens()

	if UI.main then
		UI.main.Visible = true
		if SideMenu._originalPosition then
			UI.main.Position = SideMenu._originalPosition
		end
	end

	SideMenu._isVisible = true
	SideMenu._hiddenPosition = nil
	SideMenu._originalPosition = nil
end

return SideMenu