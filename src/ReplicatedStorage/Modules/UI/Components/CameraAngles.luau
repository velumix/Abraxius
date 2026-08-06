local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local Signal = Mince.Signal
local Trove = require(Modules.Trove)

local PlayerModule = LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")
local ControlModule = require(PlayerModule.ControlModule)

local DEFAULT_FOV = 70
local MIN_FOV = 20
local MAX_FOV = 80

local BASIC_HEAD_UP = 3
local FREECAM_SPEED = 22
local BOOST_MULTIPLIER = 2.5
local MOUSE_SENSITIVITY = 0.0025
local BASIC_ROTATION_SENSITIVITY = 0.0033
local ROTATION_DELTA_CLAMP = 35
local GAMEPAD_LOOK_SENSITIVITY = 4
local TOUCH_MOVE_DEADZONE = 0.05
local TOUCH_ZOOM_SENSITIVITY = 0.035
local FOV_SPRING_STIFFNESS = 45
local FOV_SPRING_DAMPING = 10
local ZOOM_KICK = 4
local PITCH_MIN = math.rad(-80)
local PITCH_MAX = math.rad(80)
local TAU = math.pi * 2

local MOVE_SPRING_STIFFNESS = 8
local ROT_SPRING_STIFFNESS = 8
local BASIC_ROT_SPRING_STIFFNESS = 20

local Spring = {}
Spring.__index = Spring

function Spring.new(freq, pos)
	local self = setmetatable({}, Spring)
	self.f = freq
	self.p = pos
	self.v = pos * 0
	return self
end

function Spring:Update(dt, goal)
	local f = self.f * 2 * math.pi
	local p0 = self.p
	local v0 = self.v

	local offset = goal - p0
	local decay = math.exp(-f * dt)

	local p1 = goal + (v0 * dt - offset * (f * dt + 1)) * decay
	local v1 = (f * dt * (offset * f - v0) + v0) * decay

	self.p = p1
	self.v = v1

	return p1
end

function Spring:Reset(pos)
	self.p = pos
	self.v = pos * 0
end

local function wrapAngle(angle)
	angle = angle % TAU
	if angle > math.pi then
		angle -= TAU
	end
	return angle
end

local MOVE_KEYS = {
	[Enum.KeyCode.W] = {axis = "forward", value = 1},
	[Enum.KeyCode.S] = {axis = "forward", value = -1},
	[Enum.KeyCode.D] = {axis = "right", value = 1},
	[Enum.KeyCode.A] = {axis = "right", value = -1},
	[Enum.KeyCode.E] = {axis = "up", value = 1},
	[Enum.KeyCode.Q] = {axis = "up", value = -1},
	[Enum.KeyCode.Space] = {axis = "up", value = 1},
	[Enum.KeyCode.LeftShift] = {axis = "up", value = -1},
	[Enum.KeyCode.RightShift] = {axis = "up", value = -1},
}

local CameraAngles = {}
CameraAngles.FreecamChanged = Signal.new()
CameraAngles.FreecamEnabled = Signal.new()
CameraAngles.FreecamDisabled = Signal.new()

local CCM = nil
local UI = nil

local trove = Trove.new()
local buttonTrove = Trove.new()

local isActive = false
local isTransitioning = false
local ownsFreecam = false

local originalCameraType, originalCameraSubject, originalFOV

local cameraPosition = nil
local cameraYaw = 0
local cameraPitch = 0
local basicYaw = 0
local basicPitch = 0
local targetFOV = DEFAULT_FOV
local lastRootPosition = nil
local moveSpring = nil
local rotSpring = nil
local basicRotSpring = nil

local moveInput = {
	forward = 0,
	right = 0,
	up = 0,
	boost = false,
}

local isRotating = false
local gamepadLook = Vector2.new(0, 0)
local gamepadMove = Vector2.new(0, 0)
local gamepadUpValue = 0
local gamepadDownValue = 0
local gamepadUpDown = 0
local touchRotateInput = nil
local touchMoveInput = nil
local touchMoveStart = nil
local touchMoveVector = Vector2.new(0, 0)
local touchZoomLastDistance = nil

local scannerActive = false
local freecamEnabled = false
local externalFreecamActive = false

local freecamUi = {
	gui = nil,
	freecamButton = nil,
	hideAllButton = nil,
	swapModeButton = nil,
	exitButton = nil,
	movePad = nil,
}

local uiHidden = false
local hiddenUiStates = {}
local anglesMode = false
local cameraAngleParts = {}
local currentAngleIndex = 1
local anglesGui = nil
local anglesMain = nil
local anglesLeft = nil
local anglesRight = nil
local anglesLabel = nil
local anglesTrove = Trove.new()
local initializeCamera
local baseAngleCFrame = nil
local previousAngleCFrame = nil
local lastAngleUpdate = 0
local CAMERA_UPDATE_RATE = 1/60
local MOVEMENT_THRESHOLD = 0.1
local DAMPENING_FACTOR = 0.85
local ANGLES_PAN_RANGE_X = 3.5
local ANGLES_PAN_RANGE_Y = 1.75
local BASIC_PAN_RANGE = 2

local previousMouseBehavior = nil
local previousProximityEnabled = nil
local fovVelocity = 0
local hiddenCharacterParts = {}
local hiddenCharacterDecals = {}
local hiddenCharacterEffects = {}
local encyclopediaWasVisible = false

local function getCCM()
	if not CCM then
		CCM = Mince:Get("CameraControlManager")
	end
	return CCM
end

local function setAccent(button, state)
	if not button then
		return
	end

	local accent = button:FindFirstChild("Accent")
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if not accent then
		return
	end

	local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goals = {}

	if state == "active" then
		goals = {Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 0}
		if stroke then
			TweenService:Create(stroke, tweenInfo, {Transparency = 0}):Play()
		end
	elseif state == "hover" then
		goals = {Size = UDim2.new(1, 0, 0, 4), BackgroundTransparency = 0.05}
		if stroke then
			TweenService:Create(stroke, tweenInfo, {Transparency = 0.1}):Play()
		end
	elseif state == "pressed" then
		goals = {Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 0}
	else
		goals = {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}
		if stroke then
			TweenService:Create(stroke, tweenInfo, {Transparency = 0.4}):Play()
		end
	end

	TweenService:Create(accent, tweenInfo, goals):Play()
end

local function isFreecamActive()
	return ownsFreecam and freecamEnabled
end

local function shouldShowMovePad()
	return UserInputService.TouchEnabled
		and (externalFreecamActive == true or isFreecamActive())
		and not anglesMode
		and not uiHidden
end

local function getFreecamEnabledMessage()
	return "Freecam enabled. Press Shift+P to exit."
end

local function syncFreecamButton()
	if not freecamUi.freecamButton then
		return
	end
	if freecamEnabled then
		setAccent(freecamUi.freecamButton, "active")
	else
		setAccent(freecamUi.freecamButton, "normal")
	end
	if freecamUi.movePad then
		freecamUi.movePad.Visible = shouldShowMovePad()
	end
end

local function setCharacterInvisible(invisible)
	local character = LocalPlayer.Character
	if not character then
		return
	end

	if invisible then
		if next(hiddenCharacterParts) or next(hiddenCharacterDecals) or next(hiddenCharacterEffects) then
			return
		end
		for _, inst in ipairs(character:GetDescendants()) do
			if inst:IsA("BasePart") then
				hiddenCharacterParts[inst] = inst.LocalTransparencyModifier
				inst.LocalTransparencyModifier = 1
			elseif inst:IsA("Decal") or inst:IsA("Texture") then
				hiddenCharacterDecals[inst] = inst.Transparency
				inst.Transparency = 1
			elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
				hiddenCharacterEffects[inst] = inst.Enabled
				inst.Enabled = false
			end
		end
		return
	end

	for part, value in pairs(hiddenCharacterParts) do
		if part and part.Parent then
			part.LocalTransparencyModifier = value
		end
	end
	for decal, value in pairs(hiddenCharacterDecals) do
		if decal and decal.Parent then
			decal.Transparency = value
		end
	end
	for effect, value in pairs(hiddenCharacterEffects) do
		if effect and effect.Parent then
			effect.Enabled = value
		end
	end
	table.clear(hiddenCharacterParts)
	table.clear(hiddenCharacterDecals)
	table.clear(hiddenCharacterEffects)
end

local function updateCharacterVisibility()
	local shouldHide = isActive and not anglesMode and not isFreecamActive()
	setCharacterInvisible(shouldHide)
end

local function setFreecamEnabled(enabled, source)
	if freecamEnabled == enabled then
		return
	end

	freecamEnabled = enabled

	if freecamEnabled then
		if moveSpring then
			moveSpring:Reset(Vector3.new())
		end
		if rotSpring then
			rotSpring:Reset(Vector2.new(cameraPitch, cameraYaw))
		end
	end

	CameraAngles.FreecamChanged:Fire(freecamEnabled, source)
	if freecamEnabled then
		CameraAngles.FreecamEnabled:Fire(source)
	else
		CameraAngles.FreecamDisabled:Fire(source)
	end

	updateCharacterVisibility()
	syncFreecamButton()
end

local function bindButtonFx(button)
	if not button then
		return
	end

	setAccent(button, "normal")

	buttonTrove:Connect(button.MouseEnter, function()
		if freecamUi.freecamButton == button and freecamEnabled then
			return
		end
		setAccent(button, "hover")
	end)

	buttonTrove:Connect(button.MouseLeave, function()
		if freecamUi.freecamButton == button and freecamEnabled then
			setAccent(button, "active")
			return
		end
		setAccent(button, "normal")
	end)

	buttonTrove:Connect(button.MouseButton1Down, function()
		setAccent(button, "pressed")
	end)

	buttonTrove:Connect(button.MouseButton1Up, function()
		if freecamUi.freecamButton == button and freecamEnabled then
			setAccent(button, "active")
			return
		end
		setAccent(button, "hover")
	end)

	buttonTrove:Connect(button.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			setAccent(button, "pressed")
		end
	end)

	buttonTrove:Connect(button.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if freecamUi.freecamButton == button and freecamEnabled then
				setAccent(button, "active")
				return
			end
			setAccent(button, "normal")
		end
	end)
end

local function bindMoveButton(button, axis, value)
	if not button then
		return
	end

	local function setState(isDown)
		moveInput[axis] = isDown and value or 0
	end

	buttonTrove:Connect(button.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setState(true)
		end
	end)

	buttonTrove:Connect(button.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setState(false)
		end
	end)

	buttonTrove:Connect(button.MouseLeave, function()
		setState(false)
	end)
end

local function resetUiInputState()
	moveInput.forward = 0
	moveInput.right = 0
	moveInput.up = 0
	moveInput.boost = false
	basicYaw = 0
	basicPitch = 0
	touchMoveInput = nil
	touchMoveStart = nil
	touchMoveVector = Vector2.new(0, 0)
	if uiHidden then
		for screenGui, wasEnabled in pairs(hiddenUiStates) do
			if screenGui and screenGui.Parent then
				screenGui.Enabled = wasEnabled
			end
		end
		hiddenUiStates = {}
		uiHidden = false
	end
	if freecamUi.freecamButton then
		freecamUi.freecamButton.Visible = true
	end
	if freecamUi.swapModeButton then
		freecamUi.swapModeButton.Visible = true
	end
	if freecamUi.exitButton then
		freecamUi.exitButton.Visible = true
	end
	if freecamUi.hideAllButton then
		local scale = freecamUi.hideAllButton:FindFirstChild("UIScale")
		if scale then
			scale.Scale = 1
		end
		freecamUi.hideAllButton.BackgroundTransparency = 0.2
		local corner = freecamUi.hideAllButton:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 8)
		end
		setAccent(freecamUi.hideAllButton, "normal")
	end
	if freecamUi.exitButton then
		setAccent(freecamUi.exitButton, "normal")
	end
	syncFreecamButton()
end

local function refreshCameraAngleParts()
	cameraAngleParts = {}
	for _, instance in ipairs(CollectionService:GetTagged("CameraAngle")) do
		if instance and instance.CFrame then
			table.insert(cameraAngleParts, instance)
		end
	end
	table.sort(cameraAngleParts, function(a, b)
		return a.Name < b.Name
	end)
end

local function ensureAnglesGui()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end
	local screenGui = playerGui:FindFirstChild("CameraAngles")
	if not screenGui then
		return false
	end
	anglesGui = screenGui
	anglesMain = anglesGui:FindFirstChild("Main")
	anglesLeft = anglesMain and anglesMain:FindFirstChild("Left")
	anglesRight = anglesMain and anglesMain:FindFirstChild("Right")
	anglesLabel = anglesMain and anglesMain:FindFirstChild("TextLabel")
	return true
end

local function updateAnglesDisplay()
	if anglesLabel then
		if #cameraAngleParts > 0 then
			anglesLabel.Text = cameraAngleParts[currentAngleIndex].Name
		else
			anglesLabel.Text = "No Camera Angles Found"
		end
	end
end

local function moveToAngle(index)
	if #cameraAngleParts == 0 then
		return
	end
	if index < 1 then
		index = #cameraAngleParts
	elseif index > #cameraAngleParts then
		index = 1
	end
	currentAngleIndex = index
	local part = cameraAngleParts[currentAngleIndex]
	if not part then
		return
	end
	CurrentCamera.CFrame = part.CFrame
	CurrentCamera.FieldOfView = DEFAULT_FOV
	baseAngleCFrame = part.CFrame
	previousAngleCFrame = part.CFrame
	targetFOV = DEFAULT_FOV
	lastAngleUpdate = 0
	updateAnglesDisplay()
end

local function panAngleCamera(dt, panRangeX, panRangeY)
	if not baseAngleCFrame then
		return
	end
	local rangeX = panRangeX or ANGLES_PAN_RANGE_X
	local rangeY = panRangeY or ANGLES_PAN_RANGE_Y
	local currentTime = tick()
	if currentTime - lastAngleUpdate < CAMERA_UPDATE_RATE then
		return
	end
	lastAngleUpdate = currentTime

	local mousePosition = UserInputService:GetMouseLocation()
	local screenSize = CurrentCamera.ViewportSize
	local screenCenter = screenSize / 2
	local offset = (mousePosition - screenCenter)
	if offset.Magnitude < MOVEMENT_THRESHOLD then
		return
	end

	local offsetX = offset.X * (rangeX / screenSize.X)
	local offsetY = offset.Y * (rangeY / screenSize.Y)
	local clampedOffset = Vector2.new(
		math.clamp(offsetX, -rangeX, rangeX),
		math.clamp(offsetY, -rangeY, rangeY)
	)

	local newCFrame = baseAngleCFrame * CFrame.new(clampedOffset.X, -clampedOffset.Y, 0)
	if not previousAngleCFrame then
		previousAngleCFrame = CurrentCamera.CFrame
	end
	CurrentCamera.CFrame = previousAngleCFrame:Lerp(newCFrame, dt * DAMPENING_FACTOR)
	previousAngleCFrame = CurrentCamera.CFrame
end

local function setAnglesMode(enabled)
	if anglesMode == enabled then
		return
	end
	anglesMode = enabled
	anglesTrove:Clean()

	if anglesMode then
		refreshCameraAngleParts()
		if #cameraAngleParts == 0 then
			anglesMode = false
			return
		end
		ensureAnglesGui()
		if anglesGui then
			anglesGui.Enabled = true
		end
		if anglesMain then
			anglesMain.Visible = true
		end
		if anglesLeft then
			anglesTrove:Connect(anglesLeft.MouseButton1Click, function()
				moveToAngle(currentAngleIndex - 1)
			end)
		end
		if anglesRight then
			anglesTrove:Connect(anglesRight.MouseButton1Click, function()
				moveToAngle(currentAngleIndex + 1)
			end)
		end
		resetUiInputState()
		setFreecamEnabled(false, "AnglesMode")
		if freecamUi.freecamButton then
			freecamUi.freecamButton.Visible = false
		end
		if freecamUi.exitButton then
			freecamUi.exitButton.Visible = false
		end
		if freecamUi.movePad then
			freecamUi.movePad.Visible = false
		end
		if freecamUi.swapModeButton then
			freecamUi.swapModeButton.Visible = true
		end
		if freecamUi.hideAllButton then
			freecamUi.hideAllButton.Visible = true
		end
		moveToAngle(currentAngleIndex)
	else
		if anglesGui then
			anglesGui.Enabled = false
		end
		if anglesMain then
			anglesMain.Visible = false
		end
		baseAngleCFrame = nil
		previousAngleCFrame = nil
		if freecamUi.freecamButton then
			freecamUi.freecamButton.Visible = not anglesMode
		end
		if freecamUi.swapModeButton then
			freecamUi.swapModeButton.Visible = true
		end
		if freecamUi.exitButton then
			freecamUi.exitButton.Visible = not anglesMode
		end
		syncFreecamButton()
		initializeCamera()
	end
	updateCharacterVisibility()
end

local function bindFreecamUi()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local gui = playerGui:FindFirstChild("FreecamControls")
	if not gui then
		return
	end

	local container = gui:FindFirstChild("Container") or gui
	local movePad = gui:FindFirstChild("MovePad", true)
	local moveRoot = movePad or container
	local freecamButton = container:FindFirstChild("FreecamToggle", true)
	local swapModeButton = container:FindFirstChild("FreecamSwapMode", true)
	local hideAllButton = container:FindFirstChild("FreecamHideAll", true)
	local exitButton = container:FindFirstChild("FreecamExit", true)
	local moveForward = moveRoot:FindFirstChild("CameraMoveForward", true)
	local moveBack = moveRoot:FindFirstChild("CameraMoveBack", true)
	local moveLeft = moveRoot:FindFirstChild("CameraMoveLeft", true)
	local moveRight = moveRoot:FindFirstChild("CameraMoveRight", true)
	local moveUp = moveRoot:FindFirstChild("CameraMoveUp", true)
	local moveDown = moveRoot:FindFirstChild("CameraMoveDown", true)

	freecamUi.gui = gui
	freecamUi.freecamButton = freecamButton
	freecamUi.swapModeButton = swapModeButton
	freecamUi.hideAllButton = hideAllButton
	freecamUi.exitButton = exitButton
	freecamUi.movePad = movePad

	if freecamButton then
		bindButtonFx(freecamButton)
		buttonTrove:Connect(freecamButton.Activated, function()
			CameraAngles.Toggle()
			syncFreecamButton()
		end)
		setAccent(freecamButton, "normal")
	end

	if exitButton then
		bindButtonFx(exitButton)
		buttonTrove:Connect(exitButton.Activated, function()
			resetUiInputState()
			CameraAngles.Hide()
		end)
		setAccent(exitButton, "normal")
	end

	if swapModeButton then
		bindButtonFx(swapModeButton)
		buttonTrove:Connect(swapModeButton.Activated, function()
			CameraAngles.ToggleMode()
		end)
		setAccent(swapModeButton, "normal")
	end

	if hideAllButton then
		bindButtonFx(hideAllButton)
		local scale = hideAllButton:FindFirstChild("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Parent = hideAllButton
		end
		local corner = hideAllButton:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 8)
		end
		buttonTrove:Connect(hideAllButton.Activated, function()
			uiHidden = not uiHidden
			if uiHidden then
				hiddenUiStates = {}
				for _, child in ipairs(playerGui:GetChildren()) do
					if child:IsA("ScreenGui") and child ~= gui then
						hiddenUiStates[child] = child.Enabled
						child.Enabled = false
					end
				end
				if movePad then
					movePad.Visible = false
				end
				if freecamButton then
					freecamButton.Visible = false
				end
				if swapModeButton then
					swapModeButton.Visible = false
				end
				if exitButton then
					exitButton.Visible = false
				end
				scale.Scale = 0.75
				hideAllButton.BackgroundTransparency = 0.6
				if corner then
					corner.CornerRadius = UDim.new(1, 0)
				end
				setAccent(hideAllButton, "active")
			else
				for screenGui, wasEnabled in pairs(hiddenUiStates) do
					if screenGui and screenGui.Parent then
						screenGui.Enabled = wasEnabled
					end
				end
				hiddenUiStates = {}
				syncFreecamButton()
				if freecamButton then
					freecamButton.Visible = not anglesMode
				end
				if swapModeButton then
					swapModeButton.Visible = true
				end
				if exitButton then
					exitButton.Visible = not anglesMode
				end
				scale.Scale = 1
				hideAllButton.BackgroundTransparency = 0.2
				if corner then
					corner.CornerRadius = UDim.new(0, 8)
				end
				setAccent(hideAllButton, "normal")
			end
		end)
		setAccent(hideAllButton, "normal")
	end

	if movePad then
		movePad.Visible = shouldShowMovePad()
	end
	if movePad then
		local moveButtons = {
			{button = moveForward, axis = "up", value = 1},
			{button = moveBack, axis = "up", value = -1},
			{button = moveLeft, axis = "right", value = -1},
			{button = moveRight, axis = "right", value = 1},
			{button = moveUp, axis = "forward", value = 1},
			{button = moveDown, axis = "forward", value = -1},
		}
		for _, entry in ipairs(moveButtons) do
			bindButtonFx(entry.button)
			bindMoveButton(entry.button, entry.axis, entry.value)
		end
	end

	syncFreecamButton()
	freecamUi.gui.Enabled = isActive
end

local function getCharacterRoot(): BasePart?
	local character = LocalPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getCharacterFocus(): BasePart?
	local character = LocalPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function FreecamPassId()
	local config = Mince.Config and Mince.Config.FreecamPass
	if type(config) ~= "table" then
		local ok, fallback = pcall(function()
			return require(ReplicatedStorage.Runtime.Config.Passes.FreecamPass)
		end)
		if ok then
			config = fallback
		end
	end
	if type(config) == "table" then
		return config.GamepassId or config.Id
	end
	return nil
end

local function refreshFreecamOwnership(callback)
	local passId = FreecamPassId()
	local ownedAttribute = LocalPlayer:GetAttribute("FreecamPass")
	if ownedAttribute ~= nil then
		ownsFreecam = ownedAttribute == true
		if callback then
			callback(ownsFreecam)
		end
		return
	end

	if not passId or passId <= 0 then
		ownsFreecam = false
		if callback then
			callback(false)
		end
		return
	end

	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, passId)
	end)
	if success then
		ownsFreecam = result == true
	else
		ownsFreecam = false
	end
	if callback then
		callback(ownsFreecam)
	end
end

local function promptFreecamPurchase()
	local passId = FreecamPassId()
	if not passId or passId <= 0 then
		return false
	end
	local okPrompt = pcall(function()
		MarketplaceService:PromptGamePassPurchase(LocalPlayer, passId)
	end)
	return okPrompt
end

local function saveCameraState()
	if originalCameraType then
		return
	end
	originalCameraType = CurrentCamera.CameraType
	originalCameraSubject = CurrentCamera.CameraSubject
	originalFOV = CurrentCamera.FieldOfView
end

local function restoreCameraState()
	if not originalCameraType then
		return
	end
	CurrentCamera.CameraType = originalCameraType
	CurrentCamera.CameraSubject = originalCameraSubject
	CurrentCamera.FieldOfView = originalFOV or DEFAULT_FOV
	originalCameraType = nil
	originalCameraSubject = nil
	originalFOV = nil
end

initializeCamera = function()
	local rootPart = getCharacterRoot()
	local focusPart = getCharacterFocus()
	local fallbackPosition = CurrentCamera.CFrame.Position
	local focusPosition = fallbackPosition + CurrentCamera.CFrame.LookVector

	if rootPart then
		local headPosition = rootPart.Position + Vector3.new(0, BASIC_HEAD_UP, 0)
		cameraPosition = headPosition
		focusPosition = headPosition + rootPart.CFrame.LookVector
		lastRootPosition = rootPart.Position
	elseif focusPart then
		cameraPosition = focusPart.Position + Vector3.new(0, BASIC_HEAD_UP, 0)
		focusPosition = focusPart.Position + focusPart.CFrame.LookVector
		lastRootPosition = focusPart.Position
	else
		cameraPosition = fallbackPosition
		lastRootPosition = nil
	end

	baseAngleCFrame = CFrame.new(cameraPosition, focusPosition)
	previousAngleCFrame = baseAngleCFrame
	lastAngleUpdate = 0
	CurrentCamera.CFrame = baseAngleCFrame

	local cf = CFrame.new(cameraPosition, focusPosition)
	local pitch, yaw = cf:ToEulerAnglesYXZ()
	cameraPitch = math.clamp(pitch, PITCH_MIN, PITCH_MAX)
	cameraYaw = wrapAngle(yaw)

	if not moveSpring then
		moveSpring = Spring.new(MOVE_SPRING_STIFFNESS, Vector3.new())
	else
		moveSpring:Reset(Vector3.new())
	end

	if not rotSpring then
		rotSpring = Spring.new(ROT_SPRING_STIFFNESS, Vector2.new(cameraPitch, cameraYaw))
	else
		rotSpring:Reset(Vector2.new(cameraPitch, cameraYaw))
	end

	if not basicRotSpring then
		basicRotSpring = Spring.new(BASIC_ROT_SPRING_STIFFNESS, Vector2.new(basicPitch, basicYaw))
	else
		basicRotSpring:Reset(Vector2.new(basicPitch, basicYaw))
	end
	basicPitch = 0
	basicYaw = 0
	targetFOV = DEFAULT_FOV
end


local function applyInputState(keyCode, isDown)
	if MOVE_KEYS[keyCode] then
		local info = MOVE_KEYS[keyCode]
		moveInput[info.axis] = isDown and info.value or 0
		return
	end

	if keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.RightControl then
		moveInput.boost = isDown
		return
	end
end

local function getMoveVector(rotation: CFrame, useFreecam: boolean)
	local forward = moveInput.forward - gamepadMove.Y - touchMoveVector.Y
	local right = moveInput.right + gamepadMove.X + touchMoveVector.X
	local up = moveInput.up + gamepadUpDown

	if UserInputService.TouchEnabled and not useFreecam and math.abs(moveInput.forward) < 0.001 and math.abs(moveInput.right) < 0.001 then
		local moveVector
		if ControlModule and ControlModule.GetMoveVector then
			moveVector = ControlModule:GetMoveVector()
		else
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local moveDirection = humanoid and humanoid.MoveDirection or Vector3.new(0, 0, 0)
			moveVector = CurrentCamera.CFrame:VectorToObjectSpace(moveDirection)
		end
		right = moveVector.X
		forward = -moveVector.Z
	end

	local direction = rotation.LookVector * forward + rotation.RightVector * right + rotation.UpVector * up
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	return direction
end

local function updateFov(dt)
	local currentFov = CurrentCamera.FieldOfView
	local clampedTarget = math.clamp(targetFOV, MIN_FOV, MAX_FOV)
	local delta = clampedTarget - currentFov
	local accel = delta * FOV_SPRING_STIFFNESS
	fovVelocity = (fovVelocity + accel * dt) * math.exp(-FOV_SPRING_DAMPING * dt)
	CurrentCamera.FieldOfView = math.clamp(currentFov + fovVelocity * dt, MIN_FOV, MAX_FOV)
end


local function updateCamera(dt)
	if not cameraPosition then
		if anglesMode then
			panAngleCamera(dt, ANGLES_PAN_RANGE_X, ANGLES_PAN_RANGE_Y)
			updateFov(dt)
		end
		return
	end

	if anglesMode then
		panAngleCamera(dt, ANGLES_PAN_RANGE_X, ANGLES_PAN_RANGE_Y)
		updateFov(dt)
		return
	end

	if freecamEnabled then
		return
	end

	if not (ownsFreecam and freecamEnabled) then
		if gamepadLook.Magnitude > 0.05 then
			basicYaw = wrapAngle(basicYaw - gamepadLook.X * GAMEPAD_LOOK_SENSITIVITY * dt)
			basicPitch = math.clamp(basicPitch - gamepadLook.Y * GAMEPAD_LOOK_SENSITIVITY * dt, PITCH_MIN, PITCH_MAX)
		end
		local rootPart = getCharacterRoot()
		local focusPart = rootPart or getCharacterFocus()
		if focusPart then
			local basePosition = (rootPart and (rootPart.Position + Vector3.new(0, BASIC_HEAD_UP, 0)))
				or (focusPart.Position + Vector3.new(0, BASIC_HEAD_UP, 0))
			basicPitch = math.clamp(basicPitch, PITCH_MIN, PITCH_MAX)
			local targetRot = Vector2.new(basicPitch, basicYaw)
			local smoothedRot = basicRotSpring and basicRotSpring:Update(dt, targetRot) or targetRot
			local rotation = CFrame.fromOrientation(smoothedRot.X, smoothedRot.Y, 0)
			CurrentCamera.CFrame = CFrame.new(basePosition) * rotation
		end
		updateFov(dt)
		return
	end

	if gamepadLook.Magnitude > 0.05 then
		cameraYaw = wrapAngle(cameraYaw - gamepadLook.X * GAMEPAD_LOOK_SENSITIVITY * dt)
		cameraPitch = math.clamp(cameraPitch - gamepadLook.Y * GAMEPAD_LOOK_SENSITIVITY * dt, PITCH_MIN, PITCH_MAX)
	end

	local focusPart = getCharacterFocus()
	if focusPart and lastRootPosition then
		cameraPosition += (focusPart.Position - lastRootPosition)
		lastRootPosition = focusPart.Position
	elseif focusPart then
		lastRootPosition = focusPart.Position
	else
		lastRootPosition = nil
	end

	local useFreecam = ownsFreecam and freecamEnabled
	local speed = FREECAM_SPEED
	if moveInput.boost then
		speed *= BOOST_MULTIPLIER
	end

	local rotation = CFrame.fromOrientation(cameraPitch, cameraYaw, 0)
	local desiredVelocity = getMoveVector(rotation, true) * speed
	local blendedVelocity = moveSpring and moveSpring:Update(dt, desiredVelocity) or desiredVelocity

	cameraPosition += blendedVelocity * dt
	CurrentCamera.CFrame = CFrame.new(cameraPosition) * rotation

	updateFov(dt)
end

local function connectInput()
	trove:Clean()
	local moveAction = "CameraAnglesMove"
	local upDownAction = "CameraAnglesUpDown"
	local toggleAction = "CameraAnglesToggleMode"
	local exitAction = "CameraAnglesExit"

	RunService:BindToRenderStep("CameraAnglesUpdate", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not isActive or isTransitioning or scannerActive then
			return
		end
		local ccm = getCCM()
		if ccm and not ccm:HasControl("CameraAngles") then
			CameraAngles.Hide(true)
			return
		end
		updateCamera(dt)
	end)

	trove:Add(function()
		RunService:UnbindFromRenderStep("CameraAnglesUpdate")
	end)

	trove:Connect(UserInputService.InputBegan, function(input, gameProcessed)
		if not isActive then
			return
		end
		if anglesMode and input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
				moveToAngle(currentAngleIndex - 1)
				return
			elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
				moveToAngle(currentAngleIndex + 1)
				return
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if anglesMode then
				return
			end
			isRotating = true
			if not previousMouseBehavior then
				previousMouseBehavior = UserInputService.MouseBehavior
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if not touchRotateInput then
				touchRotateInput = input
				isRotating = true
				touchMoveStart = input.Position
				touchMoveVector = Vector2.new(0, 0)
				touchZoomLastDistance = nil
			elseif not touchMoveInput then
				touchMoveInput = input
				if touchRotateInput then
					touchZoomLastDistance = (touchRotateInput.Position - touchMoveInput.Position).Magnitude
				end
			end
			return
		end
		if gameProcessed then
			return
		end
		applyInputState(input.KeyCode, true)
	end)

	trove:Connect(UserInputService.InputEnded, function(input)
		if not isActive then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isRotating = false
			if previousMouseBehavior then
				UserInputService.MouseBehavior = previousMouseBehavior
				previousMouseBehavior = nil
			else
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.new(0, 0)
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if touchRotateInput == input then
				touchRotateInput = nil
				isRotating = false
				if touchMoveInput then
					touchRotateInput = touchMoveInput
					touchMoveInput = nil
					touchMoveStart = touchRotateInput.Position
				end
				touchMoveVector = Vector2.new(0, 0)
				touchZoomLastDistance = nil
				return
			end
			if touchMoveInput == input then
				touchMoveInput = nil
				touchMoveStart = nil
				touchMoveVector = Vector2.new(0, 0)
				touchZoomLastDistance = nil
				return
			end
		end
		applyInputState(input.KeyCode, false)
	end)

	trove:Connect(UserInputService.InputChanged, function(input, gameProcessed)
		if not isActive then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if anglesMode then
				return
			end
			if isRotating or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				local dx = math.clamp(input.Delta.X, -ROTATION_DELTA_CLAMP, ROTATION_DELTA_CLAMP)
				local dy = math.clamp(input.Delta.Y, -ROTATION_DELTA_CLAMP, ROTATION_DELTA_CLAMP)
				if isFreecamActive() then
					cameraYaw -= dx * MOUSE_SENSITIVITY
					cameraPitch = math.clamp(cameraPitch - dy * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
				else
					basicYaw = wrapAngle(basicYaw - dx * MOUSE_SENSITIVITY)
					basicPitch = math.clamp(basicPitch - dy * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
				end
			end
			return
		end
		if gameProcessed and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			if touchRotateInput and touchMoveInput then
				local distance = (touchRotateInput.Position - touchMoveInput.Position).Magnitude
				if touchZoomLastDistance then
					local delta = distance - touchZoomLastDistance
					local zoomStep = delta * TOUCH_ZOOM_SENSITIVITY
					targetFOV = math.clamp(targetFOV - zoomStep, MIN_FOV, MAX_FOV)
					fovVelocity += (-zoomStep) * ZOOM_KICK
				end
				touchZoomLastDistance = distance
				return
			end
			if touchRotateInput == input then
				local dx = math.clamp(input.Delta.X, -ROTATION_DELTA_CLAMP, ROTATION_DELTA_CLAMP)
				local dy = math.clamp(input.Delta.Y, -ROTATION_DELTA_CLAMP, ROTATION_DELTA_CLAMP)
				if isFreecamActive() then
					cameraYaw = wrapAngle(cameraYaw - dx * MOUSE_SENSITIVITY)
					cameraPitch = math.clamp(cameraPitch - dy * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
				else
					basicYaw = wrapAngle(basicYaw - dx * MOUSE_SENSITIVITY)
					basicPitch = math.clamp(basicPitch - dy * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
				end
			elseif touchMoveInput == input and touchMoveStart then
				if not isFreecamActive() then
					return
				end
				local viewport = CurrentCamera.ViewportSize
				local delta = input.Position - touchMoveStart
				local normalized = Vector2.new(
					delta.X / math.max(viewport.X * 0.25, 1),
					delta.Y / math.max(viewport.Y * 0.25, 1)
				)
				local clamped = Vector2.new(
					math.clamp(normalized.X, -1, 1),
					math.clamp(normalized.Y, -1, 1)
				)
				if clamped.Magnitude < TOUCH_MOVE_DEADZONE then
					clamped = Vector2.new(0, 0)
				end
				touchMoveVector = clamped
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local zoomStep = input.Position.Z * 2
			targetFOV = math.clamp(targetFOV - zoomStep, MIN_FOV, MAX_FOV)
			fovVelocity += (-zoomStep) * ZOOM_KICK
		end
	end)

	ContextActionService:BindActionAtPriority(moveAction, function(_, inputState, inputObject)
		if not isActive then
			return Enum.ContextActionResult.Pass
		end
		if inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then
			if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				gamepadMove = Vector2.new(0, 0)
			else
				gamepadMove = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Thumbstick1)

	ContextActionService:BindActionAtPriority(upDownAction, function(_, inputState, inputObject)
		if not isActive then
			return Enum.ContextActionResult.Pass
		end
		if inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
			gamepadUpValue = (inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel) and 0 or 1
			gamepadUpDown = gamepadUpValue - gamepadDownValue
			return Enum.ContextActionResult.Sink
		elseif inputObject.KeyCode == Enum.KeyCode.ButtonL2 then
			gamepadDownValue = (inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel) and 0 or 1
			gamepadUpDown = gamepadUpValue - gamepadDownValue
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)

	ContextActionService:BindAction(toggleAction, function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		if not isActive then
			return Enum.ContextActionResult.Pass
		end

		local hasPass = ownsFreecam
		local passAttr = LocalPlayer:GetAttribute("FreecamPass")
		if passAttr ~= nil then
			hasPass = passAttr == true
			ownsFreecam = hasPass
		end

		if hasPass then
			setFreecamEnabled(not freecamEnabled, "Input")
			if UI and UI.Notify then
				if freecamEnabled then
					UI.Notify(getFreecamEnabledMessage(), "Info", 8)
				else
					UI.Notify("Freecam disabled.", "Info", 8)
				end
			end
			return Enum.ContextActionResult.Sink
		end

		local success = promptFreecamPurchase()

		if success then
			if UI and UI.Notify then
				UI.Notify("Purchase the Freecam gamepass to unlock this feature!", "Info", 3)
			end
		else
			if UI and UI.Notify then
				UI.Notify("Unable to prompt Freecam purchase. Please try again.", "Warning", 3)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)

	trove:Add(function()
		ContextActionService:UnbindAction(moveAction)
		ContextActionService:UnbindAction(upDownAction)
		ContextActionService:UnbindAction(toggleAction)
	end)
end

local function closeInternal(skipScreenShownEvent)
	if not isActive then
		return false
	end

	isTransitioning = true
	local ccm = getCCM()
	if ccm then
		ccm:ReleaseControl("CameraAngles")
	end
	resetUiInputState()
	if anglesMode then
		anglesMode = false
		anglesTrove:Clean()
		if anglesGui then
			anglesGui.Enabled = false
		end
		if anglesMain then
			anglesMain.Visible = false
		end
	end

	setFreecamEnabled(false, "Close")

	ControlModule:Enable()
	if previousProximityEnabled ~= nil then
		ProximityPromptService.Enabled = previousProximityEnabled
		previousProximityEnabled = nil
	end
	restoreCameraState()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if CurrentCamera.CameraType == Enum.CameraType.Scriptable then
			CurrentCamera.CameraType = Enum.CameraType.Custom
		end
		if CurrentCamera.CameraSubject == nil then
			CurrentCamera.CameraSubject = humanoid
		end
	end
	LocalPlayer:SetAttribute("ViewingCameraAngles", nil)

	isActive = false
	isTransitioning = false
	setCharacterInvisible(false)
	isRotating = false
	if previousMouseBehavior then
		UserInputService.MouseBehavior = previousMouseBehavior
		previousMouseBehavior = nil
	end
	gamepadLook = Vector2.new(0, 0)
	gamepadMove = Vector2.new(0, 0)
	gamepadUpValue = 0
	gamepadDownValue = 0
	gamepadUpDown = 0
	touchRotateInput = nil
	touchMoveInput = nil
	touchMoveStart = nil
	touchMoveVector = Vector2.new(0, 0)
	moveInput.forward = 0
	moveInput.right = 0
	moveInput.up = 0
	moveInput.boost = false

	if moveSpring then
		moveSpring:Reset(Vector3.new())
	end
	if rotSpring then
		rotSpring:Reset(Vector2.new())
	end
	if basicRotSpring then
		basicRotSpring:Reset(Vector2.new())
	end

	cameraPosition = nil
	lastRootPosition = nil

	if UI and UI.ScreenShown and not skipScreenShownEvent then
		UI.ScreenShown:Fire("CameraAngles", false)
	end
	if UI and UI.SideMenu and UI.SideMenu.Show then
		UI.SideMenu.Show()
	end
	if freecamUi.gui then
		freecamUi.gui.Enabled = false
	end

	if encyclopediaWasVisible and UI and UI.Encyclopedia and UI.Encyclopedia.Show then
		UI.Encyclopedia.Show()
	end
	encyclopediaWasVisible = false

	trove:Clean()
	return true
end

function CameraAngles.Show()
	if isTransitioning or isActive then
		return false
	end

	if LocalPlayer:GetAttribute("ViewingExhibit") then
		warn("Cannot open while viewing an exhibit")
		return false
	end

	if scannerActive then
		warn("Cannot open while scanner is active")
		return false
	end

	isActive = true
	setFreecamEnabled(false, "Show")
	saveCameraState()
	previousProximityEnabled = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	ControlModule:Disable()
	if not previousMouseBehavior then
		previousMouseBehavior = UserInputService.MouseBehavior
	end
	CurrentCamera.CameraType = Enum.CameraType.Scriptable
	CurrentCamera.CameraSubject = nil
	initializeCamera()
	updateCharacterVisibility()
	local ccm = getCCM()
	if ccm then
		ccm:RequestControl("CameraAngles", ccm.Priority.CAMERA_ANGLES)
	end
	if freecamUi.gui then
		freecamUi.gui.Enabled = true
	end
	connectInput()
	LocalPlayer:SetAttribute("ViewingCameraAngles", true)

	refreshFreecamOwnership(function(hasPass)
		if not hasPass and UI and UI.Notify then
			UI.Notify("Freecam upgrade available in the Shop.", "Info", 4)
		end
	end)

	if UI and UI.ScreenShown then
		UI.ScreenShown:Fire("CameraAngles", true)
	end
	if UI and UI.SideMenu and UI.SideMenu.Hide then
		UI.SideMenu.Hide()
	end

	return true
end

function CameraAngles.Hide(skipScreenShownEvent)
	return closeInternal(skipScreenShownEvent)
end

function CameraAngles.Close()
	return closeInternal(true)
end

function CameraAngles.Toggle()
	if not CameraAngles.IsVisible() then
		return CameraAngles.Show()
	end

	local hasPass = ownsFreecam
	local passAttr = LocalPlayer:GetAttribute("FreecamPass")
	if passAttr ~= nil then
		hasPass = passAttr == true
		ownsFreecam = hasPass
	end

	if hasPass then
		setFreecamEnabled(not freecamEnabled, "Toggle")
		if UI and UI.Notify then
			if freecamEnabled then
				UI.Notify(getFreecamEnabledMessage(), "Info", 8)
			else
				UI.Notify("Freecam disabled.", "Info", 8)
			end
		end
		return true
	end

	refreshFreecamOwnership(function(result)
		if result then
			setFreecamEnabled(true, "Toggle")
			if UI and UI.Notify then
				UI.Notify(getFreecamEnabledMessage(), "Info", 8)
			end
			return
		end
		local success = promptFreecamPurchase()
		if success then
			if UI and UI.Notify then
				UI.Notify("Purchase the Freecam gamepass to unlock this feature!", "Info", 3)
			end
		else
			if UI and UI.Notify then
				UI.Notify("Unable to prompt Freecam purchase. Please try again.", "Warning", 3)
			end
		end
	end)
	return false
end

function CameraAngles.SetExternalFreecamActive(active)
	externalFreecamActive = active == true
	if freecamEnabled ~= externalFreecamActive then
		setFreecamEnabled(externalFreecamActive, "External")
	end
end

function CameraAngles.ToggleMode()
	if not CameraAngles.IsVisible() then
		return false
	end
	setAnglesMode(not anglesMode)
	syncFreecamButton()
	return true
end

function CameraAngles.IsVisible()
	return isActive
end

function CameraAngles.Init(UIManager)
	CCM = Mince:Get("CameraControlManager")
	UI = UIManager

	bindFreecamUi()
	buttonTrove:Connect(LocalPlayer:WaitForChild("PlayerGui").ChildAdded, function(child)
		if child.Name == "FreecamControls" then
			bindFreecamUi()
			syncFreecamButton()
		end
	end)

	buttonTrove:Connect(MarketplaceService.PromptGamePassPurchaseFinished, function(player, gamePassId, wasPurchased)
		if player ~= LocalPlayer then
			return
		end
		local freecamPassId = FreecamPassId()
		if freecamPassId and gamePassId == freecamPassId then
			if wasPurchased then
				refreshFreecamOwnership(function(hasPass)
					if hasPass and UI and UI.Notify then
						UI.Notify("Freecam unlocked! Press F to toggle.", "Success", 3)
					end
					syncFreecamButton()
				end)
			else
				if UI and UI.Notify then
					UI.Notify("Freecam purchase cancelled.", "Info", 2)
				end
			end
		end
	end)

	local toStayOpen = {
		["CameraAngles"] = true,
		["Settings"] = true,
		["Encyclopedia"] = true,
	}

	task.spawn(function()
		if UIManager and UIManager.LoadedSignal then
			if not UIManager.Loaded then
				UIManager.LoadedSignal:Wait()
			end
		end

		if UIManager and UIManager.ScreenShown then
			buttonTrove:Connect(UIManager.ScreenShown, function(componentName, isVisible)
				if componentName == "CameraAngles" then
					if isVisible then
						if UI and UI.Encyclopedia and UI.Encyclopedia.IsVisible and UI.Encyclopedia.Hide then
							encyclopediaWasVisible = UI.Encyclopedia.IsVisible()
							if encyclopediaWasVisible then
								UI.Encyclopedia.Hide()
							end
						end
					else
						if encyclopediaWasVisible and UI and UI.Encyclopedia and UI.Encyclopedia.Show then
							UI.Encyclopedia.Show()
						end
						encyclopediaWasVisible = false
					end
					return
				end

				if isVisible and CameraAngles.IsVisible() then
					if not toStayOpen[componentName] then
						CameraAngles.Hide(true)
					end
				end
			end)
		end
	end)

	buttonTrove:Connect(LocalPlayer:GetAttributeChangedSignal("ViewingExhibit"), function()
		if LocalPlayer:GetAttribute("ViewingExhibit") and CameraAngles.IsVisible() then
			CameraAngles.Hide()
		end
	end)

	buttonTrove:Connect(LocalPlayer:GetAttributeChangedSignal("FreecamPass"), function()
		refreshFreecamOwnership()
		syncFreecamButton()
	end)

	buttonTrove:Connect(LocalPlayer.CharacterAdded, function()
		updateCharacterVisibility()
	end)

	Mince.UponStart:Once(function()
		local ScanController = Mince:Get("ScanController")
		if not ScanController then
			return
		end

		buttonTrove:Connect(ContextActionService.LocalToolEquipped, function(tool)
			if tool.Name == "Scanner" then
				scannerActive = true
			end
		end)

		if ScanController.CreatureLocked and ScanController.CreatureLocked.Connect then
			buttonTrove:Connect(ScanController.CreatureLocked, function()
				if CameraAngles.IsVisible() then
					CameraAngles.Close()
				end
			end)
		end

		if ScanController.FishScanned and ScanController.FishScanned.Connect then
			buttonTrove:Connect(ScanController.FishScanned, function()
				scannerActive = false
			end)
		end

		buttonTrove:Connect(ContextActionService.LocalToolUnequipped, function(tool)
			if tool.Name == "Scanner" then
				scannerActive = false
			end
		end)
	end)
end

return CameraAngles