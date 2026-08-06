local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIModules = Modules:WaitForChild("UI")
local UIAudio = require(UIModules:WaitForChild("UIAudio"))
local Signal = require(ReplicatedStorage.Modules.Signal)
local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)

local ElevatorScreen = {
	Showing = false,
	Opened = Signal.new(),
	Closed = Signal.new()
}

local COLORS = {
	Background = UIColors.Background,
	Card = UIColors.Card,
	Text = UIColors.Text,
	SubText = UIColors.TextSecondary,
	Border = UIColors.Border,
	Shadow = UIColors.Shadow,
	Button = UIColors.Button,
	ButtonHover = UIColors.ButtonHover,
	ButtonPressed = UIColors.ButtonPressed,
	CurrentFloor = UIColors.CurrentFloor,
	Disabled = UIColors.Disabled,
}

local elevatorSystem
local onTeleportCallback

local function isGamepadInput()
	local inputType = UserInputService:GetLastInputType()
	return inputType.Value >= Enum.UserInputType.Gamepad1.Value and inputType.Value <= Enum.UserInputType.Gamepad8.Value
end

local function createStroke(button: GuiObject, cornerRadius: UDim?)
	local selectionFrame = Instance.new("Frame")
	selectionFrame.Name = "SelectionStroke"
	selectionFrame.BackgroundTransparency = 1
	selectionFrame.Size = UDim2.fromScale(1, 1)
	selectionFrame.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.ElevatorCurrentIcon
	stroke.Thickness = 2
	stroke.Parent = selectionFrame

	if cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = cornerRadius
		corner.Parent = selectionFrame
	end

	return selectionFrame
end

function ElevatorScreen.Init(UI)
	ElevatorScreen.Interface = UI
end

local function getElevatorSystem()
	if elevatorSystem then return elevatorSystem end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ElevatorSystem"
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

	local container = Instance.new("Frame", gui)
	container.Name = "ElevatorContainer"
	container.Size = UDim2.new(0, 400, 0, 350)
	container.Position = UDim2.new(0.5, -200, 0.5, -175)
	container.BackgroundColor3 = COLORS.Background
	container.BorderSizePixel = 0
	container.Visible = false
	container.ClipsDescendants = true

	local corner = Instance.new("UICorner", container)
	corner.CornerRadius = UDim.new(0, 12)

	local shadow = Instance.new("Frame", gui)
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(0, 410, 0, 360)
	shadow.Position = UDim2.new(0.5, -205, 0.5, -170)
	shadow.BackgroundColor3 = COLORS.Shadow
	shadow.BackgroundTransparency = 0.3
	shadow.BorderSizePixel = 0
	shadow.ZIndex = container.ZIndex - 1
	shadow.Visible = false

	local shadowCorner = Instance.new("UICorner", shadow)
	shadowCorner.CornerRadius = UDim.new(0, 12)

	local header = Instance.new("Frame", container)
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = COLORS.Card
	header.BorderSizePixel = 0

	local headerCorner = Instance.new("UICorner", header)
	headerCorner.CornerRadius = UDim.new(0, 12)

	local headerFix = Instance.new("Frame", header)
	headerFix.Size = UDim2.new(1, 0, 0, 12)
	headerFix.Position = UDim2.new(0, 0, 1, -12)
	headerFix.BackgroundColor3 = COLORS.Card
	headerFix.BorderSizePixel = 0

	local title = Instance.new("TextLabel", header)
	title.Name = "Title"
	title.Size = UDim2.new(1, -60, 0, 30)
	title.Position = UDim2.new(0, 20, 0.5, -15)
	title.BackgroundTransparency = 1
	title.Text = "Elevator"
	title.TextColor3 = COLORS.Text
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Center

	local closeButton = Instance.new("TextButton", header)
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0.5, -20)
	closeButton.BackgroundColor3 = COLORS.Button
	closeButton.BorderSizePixel = 0
	closeButton.Text = "×"
	closeButton.TextColor3 = COLORS.Text
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold

	local closeCorner = Instance.new("UICorner", closeButton)
	closeCorner.CornerRadius = UDim.new(0, 8)

	closeButton.MouseButton1Click:Connect(function()
		UIAudio.PlayNotification("Close")
		ElevatorScreen.Hide()
	end)

	local returnButton = Instance.new("TextButton", header)
	returnButton.Name = "ReturnButton"
	returnButton.Size = UDim2.new(0, 40, 0, 40)
	returnButton.Position = UDim2.new(1, -100, 0.5, -20)
	returnButton.BackgroundColor3 = COLORS.Button
	returnButton.BorderSizePixel = 0
	returnButton.Text = "↩"
	returnButton.TextColor3 = COLORS.Text
	returnButton.TextSize = 22
	returnButton.Font = Enum.Font.GothamBold

	local returnCorner = Instance.new("UICorner", returnButton)
	returnCorner.CornerRadius = UDim.new(0, 8)


	local content = Instance.new("Frame", container)
	content.Name = "Content"
	content.Size = UDim2.new(1, -40, 1, -100)
	content.Position = UDim2.new(0, 20, 0, 80)
	content.BackgroundTransparency = 1
	content.ClipsDescendants = false


	local floorContainer = Instance.new("ScrollingFrame", content)
	floorContainer.Name = "FloorContainer"
	floorContainer.Size = UDim2.new(1, 0, 1, 0)
	floorContainer.Position = UDim2.new(0, 0, 0, 0)
	floorContainer.BackgroundTransparency = 1
	floorContainer.BorderSizePixel = 0
	floorContainer.ScrollBarThickness = 6
	floorContainer.ScrollBarImageColor3 = COLORS.Border
	floorContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	floorContainer.ClipsDescendants = false

	local layout = Instance.new("UIListLayout", floorContainer)
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		floorContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
	end)

	elevatorSystem = {
		GUI = gui,
		Container = container,
		Shadow = shadow,
		Content = content,
		FloorContainer = floorContainer,
		Layout = layout,
		CloseButton = closeButton,
		ReturnButton = returnButton,
		FloorButtons = {}
	}

	ElevatorScreen.Interface.ScreenShown:Connect(function(componentName, isVisible)
		if isVisible and componentName ~= "ElevatorScreen" and ElevatorScreen.IsVisible() then
			ElevatorScreen.Hide()
		end
	end)

	return elevatorSystem
end

function ElevatorScreen.Show(locations, currentLocation, onFloorSelect)
	if ElevatorScreen.Showing then return end
	ElevatorScreen.Showing = true

	local sys = getElevatorSystem()
	onTeleportCallback = onFloorSelect

	for _, button in pairs(sys.FloorButtons) do
		button:Destroy()
	end

	sys.FloorButtons = {}

	local locationOrder = {"Main Observatory", "Lower Observatory", "Dive"}
	local orderedButtons = {}
	local currentButton

	for index, locationName in ipairs(locationOrder) do
		local locationData = locations[locationName]
		if locationData then
			local isCurrentFloor = (locationName == currentLocation)
			local isShowcase = locationData[1] == false
			local isDiveAction = locationData.Action == "Swim"

			local button = Instance.new("TextButton", sys.FloorContainer)
			button.Name = locationName .. "Button"
			button.Size = UDim2.new(1, 0, 0, 60)
			button.BackgroundColor3 = isCurrentFloor and COLORS.CurrentFloor or (isShowcase and UIColors.ElevatorShowcase or COLORS.Button)
			button.BorderSizePixel = 0
			button.Text = ""
			button.AutoButtonColor = false
			button.Selectable = true
			button.SelectionOrder = index

			local corner = Instance.new("UICorner", button)
			corner.CornerRadius = UDim.new(0, 8)

			button.SelectionImageObject = createStroke(button, corner.CornerRadius)
			button.MouseEnter:Connect(function()
				if GamepadService.GamepadCursorEnabled or isGamepadInput() then
					GuiService.SelectedObject = button
				end
			end)
			button.MouseLeave:Connect(function()
				if (GamepadService.GamepadCursorEnabled or isGamepadInput()) and GuiService.SelectedObject == button then
					GuiService.SelectedObject = nil
				end
			end)

			local nameLabel = Instance.new("TextLabel", button)
			nameLabel.Name = "NameLabel"
			nameLabel.Size = UDim2.new(1, -20, 0, 30)
			nameLabel.Position = UDim2.new(0, 10, 0, 8)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = locationName
			nameLabel.TextColor3 = isCurrentFloor and UIColors.Black or (isShowcase and UIColors.ElevatorShowcaseText or COLORS.Text)
			nameLabel.TextSize = 18
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left

			local statusLabel = Instance.new("TextLabel", button)
			statusLabel.Name = "StatusLabel"
			statusLabel.Size = UDim2.new(1, -20, 0, 20)
			statusLabel.Position = UDim2.new(0, 10, 0, 32)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Text = isCurrentFloor and "Current Floor" or (isShowcase and "Coming Soon" or (isDiveAction and "Tap to dive" or "Tap to travel"))
			statusLabel.TextColor3 = isCurrentFloor and UIColors.ElevatorCurrentDefault or (isShowcase and UIColors.ElevatorShowcaseText or COLORS.SubText)
			statusLabel.TextSize = 12
			statusLabel.Font = Enum.Font.Gotham
			statusLabel.TextXAlignment = Enum.TextXAlignment.Left

			if isCurrentFloor then
				button.BackgroundColor3 = UIColors.ElevatorCurrentBg
				nameLabel.TextColor3 = UIColors.ElevatorCurrentText
				statusLabel.TextColor3 = UIColors.ElevatorCurrentSubText
				local currentIcon = Instance.new("TextLabel", button)
				currentIcon.Name = "CurrentIcon"
				currentIcon.Size = UDim2.new(0, 60, 0, 20)
				currentIcon.Position = UDim2.new(1, -70, 0, 5)
				currentIcon.BackgroundTransparency = 1
				currentIcon.Text = "● YOU ARE HERE"
				currentIcon.TextColor3 = UIColors.ElevatorCurrentIcon
				currentIcon.TextSize = 10
				currentIcon.Font = Enum.Font.GothamBold
				currentIcon.TextXAlignment = Enum.TextXAlignment.Right
			else
				button.MouseEnter:Connect(function()
					if not isCurrentFloor then
						button.BackgroundColor3 = isShowcase and UIColors.ElevatorShowcaseHover or COLORS.ButtonHover
					end
				end)
				button.MouseLeave:Connect(function()
					if not isCurrentFloor then
						button.BackgroundColor3 = isShowcase and UIColors.ElevatorShowcase or COLORS.Button
					end
				end)
				button.MouseButton1Down:Connect(function()
					if not isCurrentFloor then
						button.BackgroundColor3 = isShowcase and UIColors.ElevatorShowcasePressed or COLORS.ButtonPressed
					end
				end)
				button.MouseButton1Up:Connect(function()
					if not isCurrentFloor then
						button.BackgroundColor3 = isShowcase and UIColors.ElevatorShowcaseHover or COLORS.ButtonHover
					end
				end)
				button.MouseButton1Click:Connect(function()
					if not isCurrentFloor and onTeleportCallback then
						UIAudio.PlayNotification("Click")
						if not isShowcase then
							ElevatorScreen.Hide()
						end
						onTeleportCallback(locationName)
					end
				end)
			end
			sys.FloorButtons[locationName] = button
			orderedButtons[#orderedButtons + 1] = button
			if isCurrentFloor then
				currentButton = button
			end
		end
	end

	for i, button in ipairs(orderedButtons) do
		button.NextSelectionUp = orderedButtons[i - 1] or button
		button.NextSelectionDown = orderedButtons[i + 1] or button
		button.NextSelectionLeft = button
		button.NextSelectionRight = button
	end

	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = currentButton or orderedButtons[1]
	end

	sys.ReturnButton.Visible = false
	sys.ReturnButton.MouseButton1Click:Connect(function()
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		sys.ReturnButton.Visible = false
		sys.CloseButton.Visible = true
	end)

	sys.Container.Visible = true
	sys.Shadow.Visible = true

	sys.Container.Size = UDim2.new(0, 0, 0, 0)
	sys.Container.Position = UDim2.new(0.5, 0, 0.5, 0)
	sys.Shadow.Size = UDim2.new(0, 10, 0, 10)
	sys.Shadow.Position = UDim2.new(0.5, -5, 0.5, 5)

	local containerTween = TweenService:Create(sys.Container, 
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(0, 400, 0, 350),
			Position = UDim2.new(0.5, -200, 0.5, -175)
		}
	)

	local shadowTween = TweenService:Create(sys.Shadow,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(0, 410, 0, 360),
			Position = UDim2.new(0.5, -205, 0.5, -170)
		}
	)

	UIAudio.PlayNotification("Open")
	containerTween:Play()
	shadowTween:Play()
	ElevatorScreen.Opened:Fire()

end

function ElevatorScreen.Hide()
	if not ElevatorScreen.Showing then return end
	ElevatorScreen.Showing = false

	local sys = getElevatorSystem()

	local containerTween = TweenService:Create(sys.Container,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0)
		}
	)

	local shadowTween = TweenService:Create(sys.Shadow,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{
			Size = UDim2.new(0, 10, 0, 10),
			Position = UDim2.new(0.5, -5, 0.5, 5)
		}
	)

	ElevatorScreen.Closed:Fire()

	containerTween:Play()
	shadowTween:Play()

	containerTween.Completed:Connect(function()
		sys.Container.Visible = false
		sys.Shadow.Visible = false
	end)

	if GuiService.SelectedObject and sys.Container and GuiService.SelectedObject:IsDescendantOf(sys.Container) then
		GuiService.SelectedObject = nil
	end

end

function ElevatorScreen.IsVisible()
	return ElevatorScreen.Showing
end

return ElevatorScreen
