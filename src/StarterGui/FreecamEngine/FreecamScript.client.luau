local FREECAM_ENABLED_ATTRIBUTE_NAME = "FreecamEnabled"

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	ThumbstickVisibleForMobile = true,
	FovWheelSpeed = 1.0,
	FovGamepadSpeed = 0.25,
	UpDownSpeed = 0.75,
	ShiftSpeed = 0.25,
	MobileSpeed = 0.5,
}

local pi = math.pi
local abs = math.abs
local clamp = math.clamp
local exp = math.exp
local rad = math.rad
local sign = math.sign
local sqrt = math.sqrt
local tan = math.tan

local exceptions = {
	[script.Parent] = true,
}

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCamera = Workspace.CurrentCamera
	if newCamera then
		Camera = newCamera
	end
end)

local function removeStrayFreecams(container)
	for _, g in ipairs(container:GetChildren()) do
		if g ~= script.Parent and g:IsA("ScreenGui") and g.Name == "Freecam" then
			pcall(function()
				g:Destroy()
			end)
		end
	end
end

task.spawn(function()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	removeStrayFreecams(playerGui)
	playerGui.ChildAdded:Connect(function(child)
		if child ~= script.Parent and child:IsA("ScreenGui") and child.Name == "Freecam" then
			pcall(function()
				child:Destroy()
			end)
		end
	end)
end)

local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value

local NAV_GAIN = Vector3.new(1, 1, 1) * 64
local PAN_GAIN = Vector2.new(0.75, 1) * 8
local FOV_GAIN = 300

local PITCH_LIMIT = rad(90)

local VEL_STIFFNESS = 1.5
local PAN_STIFFNESS = (UserInputService.TouchEnabled and 4 or 1)
local FOV_STIFFNESS = (UserInputService.TouchEnabled and 2 or 4.0)

local Spring = {}
do
	Spring.__index = Spring

	function Spring.new(freq, pos)
		local self = setmetatable({}, Spring)
		self.f = freq
		self.p = pos
		self.v = pos * 0
		return self
	end

	function Spring:Update(dt, goal)
		local f = self.f * 2 * pi
		local p0 = self.p
		local v0 = self.v

		local offset = goal - p0
		local decay = exp(-f * dt)

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
end

local cameraPos = Vector3.new()
local cameraRot = Vector2.new()
local cameraFov = 0

local velSpring = Spring.new(VEL_STIFFNESS, Vector3.new())
local panSpring = Spring.new(PAN_STIFFNESS, Vector2.new())
local fovSpring = Spring.new(FOV_STIFFNESS, 0)

local globalMouse
local globalKp

local Input = {}
do
	local thumbstickCurve
	do
		local K_CURVATURE = 2.0
		local K_DEADZONE = 0.15

		local function fCurve(x)
			return (exp(K_CURVATURE * x) - 1) / (exp(K_CURVATURE) - 1)
		end

		local function fDeadzone(x)
			return fCurve((x - K_DEADZONE) / (1 - K_DEADZONE))
		end

		function thumbstickCurve(x)
			return sign(x) * clamp(fDeadzone(abs(x)), 0, 1)
		end
	end

	local gamepad = {
		ButtonX = 0,
		ButtonY = 0,
		DPadDown = 0,
		DPadUp = 0,
		ButtonL2 = 0,
		ButtonR2 = 0,
		Thumbstick1 = Vector2.new(),
		Thumbstick2 = Vector2.new(),
	}

	local keyboard = {
		W = 0, A = 0, S = 0, D = 0,
		E = 0, Q = 0, U = 0, H = 0,
		J = 0, K = 0, I = 0, Y = 0,
		Up = 0, Down = 0,
		LeftShift = 0, RightShift = 0,
	}

	local mouse = {
		Delta = Vector2.new(),
		MouseWheel = 0,
	}

	local NAV_GAMEPAD_SPEED = Vector3.new(1, 1, 1)
	local NAV_KEYBOARD_SPEED = Vector3.new(1, 1, 1)
	local PAN_MOUSE_SPEED = Vector2.new(1, 1) * (pi / 64)
	local PAN_GAMEPAD_SPEED = Vector2.new(1, 1) * (pi / 8)
	local FOV_WHEEL_SPEED = CONFIG.FovWheelSpeed
	local FOV_GAMEPAD_SPEED = CONFIG.FovGamepadSpeed
	local NAV_ADJ_SPEED = CONFIG.UpDownSpeed
	local NAV_SHIFT_MUL = CONFIG.ShiftSpeed
	local MOBILE_MUL = CONFIG.MobileSpeed

	local navSpeed = 1
	local heldControllerShift = false

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR1 then
			heldControllerShift = true
			local connection
			connection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					connection:Disconnect()
					heldControllerShift = false
				end
			end)
		end
	end)

	function Input.Vel(dt)
		navSpeed = clamp(navSpeed + dt * (keyboard.Up - keyboard.Down) * NAV_ADJ_SPEED, 0.01, 4)

		local kGamepad = Vector3.new(
			thumbstickCurve(gamepad.Thumbstick1.X),
			thumbstickCurve(gamepad.ButtonR2) - thumbstickCurve(gamepad.ButtonL2),
			thumbstickCurve(-gamepad.Thumbstick1.Y)
		) * NAV_GAMEPAD_SPEED

		local kKeyboard = Vector3.new(
			keyboard.D - keyboard.A + keyboard.K - keyboard.H,
			keyboard.E - keyboard.Q + keyboard.I - keyboard.Y,
			keyboard.S - keyboard.W + keyboard.J - keyboard.U
		) * NAV_KEYBOARD_SPEED

		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or heldControllerShift

		return (kGamepad + kKeyboard) * (navSpeed * (shift and NAV_SHIFT_MUL or (UserInputService.TouchEnabled and MOBILE_MUL or 1)))
	end

	function Input.Pan(dt)
		local kGamepad = Vector2.new(
			thumbstickCurve(gamepad.Thumbstick2.Y),
			thumbstickCurve(-gamepad.Thumbstick2.X)
		) * PAN_GAMEPAD_SPEED
		local kMouse = mouse.Delta * PAN_MOUSE_SPEED
		mouse.Delta = Vector2.new()
		return kGamepad + kMouse
	end

	function Input.Fov(dt)
		local kGamepad = (gamepad.ButtonX - gamepad.ButtonY) * FOV_GAMEPAD_SPEED
		local kMouse = mouse.MouseWheel * FOV_WHEEL_SPEED
		mouse.MouseWheel = 0
		return kGamepad + kMouse
	end

	do
		local function Keypress(action, state, input)
			keyboard[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function GpButton(action, state, input)
			gamepad[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function MousePan(action, state, input)
			local delta = input.Delta
			mouse.Delta = Vector2.new(-delta.y, -delta.x)
			return Enum.ContextActionResult.Sink
		end

		local function Thumb(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position
			return Enum.ContextActionResult.Sink
		end

		local function Trigger(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position.z
			return Enum.ContextActionResult.Sink
		end

		globalMouse = mouse
		globalKp = Keypress

		local function MouseWheel(action, state, input)
			mouse[input.UserInputType.Name] = -input.Position.z
			return Enum.ContextActionResult.Sink
		end

		function Input.StartCapture()
			ContextActionService:BindActionAtPriority("FreecamKeyboard", Keypress, false, INPUT_PRIORITY,
				Enum.KeyCode.W, Enum.KeyCode.U,
				Enum.KeyCode.A, Enum.KeyCode.H,
				Enum.KeyCode.S, Enum.KeyCode.J,
				Enum.KeyCode.D, Enum.KeyCode.K,
				Enum.KeyCode.E, Enum.KeyCode.I,
				Enum.KeyCode.Q, Enum.KeyCode.Y,
				Enum.KeyCode.Up, Enum.KeyCode.Down
			)
			ContextActionService:BindActionAtPriority("FreecamMousePan", MousePan, false, INPUT_PRIORITY, Enum.UserInputType.MouseMovement)
			ContextActionService:BindActionAtPriority("FreecamMouseWheel", MouseWheel, false, INPUT_PRIORITY, Enum.UserInputType.MouseWheel)
			ContextActionService:BindActionAtPriority("FreecamGamepadButton", GpButton, false, INPUT_PRIORITY, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY)
			ContextActionService:BindActionAtPriority("FreecamGamepadTrigger", Trigger, false, INPUT_PRIORITY, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)
			ContextActionService:BindActionAtPriority("FreecamGamepadThumbstick", Thumb, false, INPUT_PRIORITY, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2)
		end

		function Input.StopCapture()
			navSpeed = 1
			for k, v in pairs(gamepad) do
				gamepad[k] = v * 0
			end

			for k, v in pairs(keyboard) do
				keyboard[k] = v * 0
			end

			for k, v in pairs(mouse) do
				mouse[k] = v * 0
			end

			ContextActionService:UnbindAction("FreecamKeyboard")
			ContextActionService:UnbindAction("FreecamMousePan")
			ContextActionService:UnbindAction("FreecamMouseWheel")
			ContextActionService:UnbindAction("FreecamGamepadButton")
			ContextActionService:UnbindAction("FreecamGamepadTrigger")
			ContextActionService:UnbindAction("FreecamGamepadThumbstick")
		end
	end
end

local function GetFocusDistance(cameraFrame)
	local znear = 0.1
	local viewport = Camera.ViewportSize
	local projy = 2 * tan(cameraFov / 2)
	local projx = viewport.x / viewport.y * projy
	local fx = cameraFrame.rightVector
	local fy = cameraFrame.upVector
	local fz = cameraFrame.lookVector

	local minVect = Vector3.new()
	local minDist = 512

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local cx = (x - 0.5) * projx
			local cy = (y - 0.5) * projy
			local offset = fx * cx - fy * cy + fz
			local origin = cameraFrame.p + offset * znear
			local _, hit = Workspace:FindPartOnRay(Ray.new(origin, offset.unit * minDist))
			local dist = (hit - origin).magnitude
			if minDist > dist then
				minDist = dist
				minVect = offset.unit
			end
		end
	end

	return fz:Dot(minVect) * minDist
end

local COLLISION_RADIUS = 1
local COLLISION_SKIN = 0.05
local COLLISION_MAX_SLIDES = 2

local collisionParams = RaycastParams.new()
collisionParams.FilterType = Enum.RaycastFilterType.Exclude
collisionParams.IgnoreWater = true
collisionParams.RespectCanCollide = true

local function ResolveCollision(fromPos, moveVec)
	local pos = fromPos
	local remaining = moveVec
	for _ = 1, COLLISION_MAX_SLIDES do
		local dist = remaining.Magnitude
		if dist < 1e-4 then
			break
		end

		local result = Workspace:Spherecast(pos, COLLISION_RADIUS, remaining, collisionParams)
		if not result then
			pos = pos + remaining
			break
		end

		local travel = clamp(result.Distance - COLLISION_SKIN, 0, dist)
		pos = pos + (remaining / dist) * travel

		local leftoverDist = dist - result.Distance
		if leftoverDist <= 0 then
			break
		end

		local leftover = (remaining / dist) * leftoverDist
		local normal = result.Normal
		remaining = leftover - normal * leftover:Dot(normal)
	end

	return pos
end

local function StepFreecam(dt)
	local vel = velSpring:Update(dt, Input.Vel(dt))
	local pan = panSpring:Update(dt, Input.Pan(dt))
	local fov = fovSpring:Update(dt, Input.Fov(dt))

	local zoomFactor = sqrt(tan(rad(70 / 2)) / tan(rad(cameraFov / 2)))

	cameraFov = clamp(cameraFov + fov * FOV_GAIN * (dt / zoomFactor), 1, 120)
	cameraRot = cameraRot + pan * PAN_GAIN * (dt / zoomFactor)
	cameraRot = Vector2.new(clamp(cameraRot.x, -PITCH_LIMIT, PITCH_LIMIT), cameraRot.y % (2 * pi))

	local orientation = CFrame.fromOrientation(cameraRot.x, cameraRot.y, 0)
	local worldMove = orientation:VectorToWorldSpace(vel * NAV_GAIN * dt)
	cameraPos = ResolveCollision(cameraPos, worldMove)

	local cameraCFrame = CFrame.new(cameraPos) * orientation

	Camera.CFrame = cameraCFrame
	Camera.Focus = cameraCFrame * CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
	Camera.FieldOfView = cameraFov
end

local savedCameraType

local PlayerState = {}
do
	local mouseBehavior
	local mouseIconEnabled
	local cameraFocus
	local cameraCFrame
	local cameraFieldOfView
	local screenGuis = {}
	local coreGuis = {}

	for _, enum in pairs(Enum.CoreGuiType:GetEnumItems()) do
		if enum.Name ~= "All" then
			coreGuis[enum.Name] = true
		end
	end

	local setCores = {
		BadgesNotificationsActive = true,
		PointsNotificationsActive = true,
	}

	function PlayerState.Push()
		for name in pairs(coreGuis) do
			coreGuis[name] = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false)
			end)
		end

		for name in pairs(setCores) do
			setCores[name] = StarterGui:GetCore(name)
			pcall(function()
				StarterGui:SetCore(name, false)
			end)
		end

		local playergui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playergui then
			for _, gui in pairs(playergui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled and (not exceptions[gui]) and gui.Name ~= "FreecamButton" and gui.Name ~= "CratesOpening" and gui.Name ~= "Hud" then
					screenGuis[#screenGuis + 1] = gui
					gui.Enabled = false
				end
			end
		end

		cameraFieldOfView = Camera.FieldOfView
		Camera.FieldOfView = 70

		savedCameraType = Camera.CameraType
		Camera.CameraType = Enum.CameraType.Custom

		cameraCFrame = Camera.CFrame
		cameraFocus = Camera.Focus

		mouseIconEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseIconEnabled = false

		mouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	function PlayerState.Pop()
		for name, isEnabled in pairs(coreGuis) do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], isEnabled)
			end)
		end

		for name, isEnabled in pairs(setCores) do
			pcall(function()
				StarterGui:SetCore(name, isEnabled)
			end)
		end

		for _, gui in pairs(screenGuis) do
			if gui.Parent then
				gui.Enabled = true
			end
		end

		screenGuis = {}

		Camera.FieldOfView = cameraFieldOfView
		cameraFieldOfView = nil

		Camera.CameraType = savedCameraType
		savedCameraType = nil

		Camera.CFrame = cameraCFrame
		cameraCFrame = nil

		Camera.Focus = cameraFocus
		cameraFocus = nil

		UserInputService.MouseIconEnabled = mouseIconEnabled
		mouseIconEnabled = nil

		UserInputService.MouseBehavior = mouseBehavior
		mouseBehavior = nil
	end
end

local controls
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)

	if ok and playerModule then
		controls = playerModule:GetControls()
	end
end)

local function StartFreecam()
	if controls then
		pcall(function()
			controls:Disable()
		end)
	end

	local character = LocalPlayer.Character
	collisionParams.FilterDescendantsInstances = character and { character } or {}

	local cameraCFrame = Camera.CFrame
	cameraRot = Vector2.new(cameraCFrame:toEulerAnglesYXZ())

	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		cameraPos = rootPart.Position
	else
		cameraPos = cameraCFrame.p
	end

	cameraFov = Camera.FieldOfView

	velSpring:Reset(Vector3.new())
	panSpring:Reset(Vector2.new())
	fovSpring:Reset(0)

	PlayerState.Push()
	RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, StepFreecam)
	Input.StartCapture()
end

local function StopFreecam()
	Input.StopCapture()
	RunService:UnbindFromRenderStep("Freecam")
	PlayerState.Pop()

	if controls then
		pcall(function()
			controls:Enable()
		end)
	end
end

local enabled = false
local tsGui
local rightMouseDown = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if enabled and not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightMouseDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightMouseDown = false
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not enabled or gameProcessed or not rightMouseDown or input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	local delta = input.Delta
	if delta.Magnitude > 0 then
		globalMouse.Delta = globalMouse.Delta + Vector2.new(-delta.Y, -delta.X)
	end
end)

local function setActive(state)
	if state == enabled then
		return
	end

	enabled = state
	if state then
		StartFreecam()
		if tsGui then
			tsGui.Visible = true
		end
	else
		rightMouseDown = false
		StopFreecam()
		if tsGui then
			tsGui.Visible = false
		end
	end
end

if UserInputService.TouchEnabled then
	local thumbstick = require(ReplicatedStorage:WaitForChild("FreecamThumbstick"))
	local lookTouches = {}
	local lookLast = Vector2.new()

	tsGui = thumbstick:Create(script.Parent, CONFIG.ThumbstickVisibleForMobile, function(keycode, pressed)
		globalKp(nil, (pressed and Enum.UserInputState.Begin or Enum.UserInputState.End), { KeyCode = keycode })
	end, function()
		for _, key in pairs({ Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }) do
			globalKp(nil, Enum.UserInputState.End, { KeyCode = key })
		end
	end, function() end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not enabled or input.UserInputType ~= Enum.UserInputType.Touch or gameProcessed then
			return
		end

		table.insert(lookTouches, input)
		if #lookTouches == 1 then
			lookLast = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not enabled or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if #lookTouches == 1 and lookTouches[1] == input then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			local delta = pos - lookLast
			lookLast = pos
			globalMouse.Delta = globalMouse.Delta + Vector2.new(-delta.Y, -delta.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		for i, t in ipairs(lookTouches) do
			if t == input then
				table.remove(lookTouches, i)
				break
			end
		end

		if #lookTouches == 1 then
			lookLast = Vector2.new(lookTouches[1].Position.X, lookTouches[1].Position.Y)
		end
	end)
end

script:SetAttribute(FREECAM_ENABLED_ATTRIBUTE_NAME, false)
script:GetAttributeChangedSignal(FREECAM_ENABLED_ATTRIBUTE_NAME):Connect(function()
	setActive(script:GetAttribute(FREECAM_ENABLED_ATTRIBUTE_NAME) == true)
end)
