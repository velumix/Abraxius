
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Settings = require(script.Settings)

local PlayerModule, ControlModule

pcall(function()
	PlayerModule = require(Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	ControlModule = PlayerModule:GetControls()
end)

local WATER_DENSITY = 1000
local GRAVITY = workspace.Gravity
local ANIMATION_BLEND_TIME = 0.2
local GAMEPAD_DEADZONE = 0.2
local DEFAULT_INPUT_BLEND = 0.15
local DEFAULT_ROTATION_BLEND = 0.08

local SwimmingController = {
	Name = "SwimmingController",

	CharacterController = nil,
	VRController = nil,
	RootPart = nil,
	Humanoid = nil,
	Character = nil,

	LinearVelocity = nil,
	VectorForce = nil,
	AlignOrientation = nil,
	RootAttachment = nil,

	IsSwimming = false,
	Depth = 0,
	CurrentVelocity = Vector3.zero,
	MovementSpeed = 0,
	PressureMultiplier = 1,
	SpeedMultiplier = 1,

	PreviousInputVector = Vector3.zero,
	BuoyancyTarget = 0,

	MobileUpPressed = false,
	MobileDownPressed = false,
	MobileInputVector = Vector3.zero,

	LeftArmIK = nil,
	BCDInflatorAttachment = nil,
	BCDDeflatorAttachment = nil,
	PoleAttachment = nil,
	BubblesParticle = nil,
	CurrentIKWeight = 0,

	ToolControlsOrientation = false,
	IKRetryScheduled = false,
	IKRetryAttempts = 0,

	Connections = {},
	NeedsSwimRefresh = false,
}

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function lerpVector3(a, b, t)
	return a:Lerp(b, math.clamp(t, 0, 1))
end

local function buildMotorMap(character)
	local adjacency = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if part0 and part1 then
				adjacency[part0] = adjacency[part0] or {}
				adjacency[part1] = adjacency[part1] or {}
				table.insert(adjacency[part0], part1)
				table.insert(adjacency[part1], part0)
			end
		end
	end
	return adjacency
end

local function hasMotorLink(character, chainRoot, endEffector)
	if chainRoot == endEffector then
		return true
	end

	local adjacency = buildMotorMap(character)
	local visited = {}
	local queue = {chainRoot}
	visited[chainRoot] = true

	while #queue > 0 do
		local current = table.remove(queue, 1)
		if current == endEffector then
			return true
		end

		local neighbors = adjacency[current]
		if neighbors then
			for _, neighbor in ipairs(neighbors) do
				if not visited[neighbor] then
					visited[neighbor] = true
					table.insert(queue, neighbor)
				end
			end
		end
	end

	return false
end

local function waitForMotorLink(character, chainRoot, endEffector, timeout)
	local startTime = os.clock()
	while os.clock() - startTime < timeout do
		if hasMotorLink(character, chainRoot, endEffector) then
			return true
		end
		task.wait()
	end
	return false
end

local function clampVector3(vector, maxMagnitude)
	if vector.Magnitude > maxMagnitude then
		return vector.Unit * maxMagnitude
	end
	return vector
end

local function isDoubleDPVTool(tool)
	if not (tool and tool:IsA("Tool")) then
		return false
	end

	if tool.Name == "DoubleDPV" then
		return true
	end

	local attributeValue = tool:GetAttribute("DoubleDPV")
	return attributeValue == true
end

function SwimmingController:UpdateSpeedMultiplier()
	local multiplier = Player:GetAttribute("SwimSpeedMultiplier")
	if typeof(multiplier) ~= "number" then
		multiplier = 1
	end

	self.SpeedMultiplier = math.max(multiplier, 0)
end

local function getGamepadThumbstick()
	if not UserInputService.GamepadEnabled and not UserInputService.VREnabled then
		return Vector3.zero
	end

	local state = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, input in ipairs(state) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			if input.Position.Magnitude > GAMEPAD_DEADZONE then
				local y = input.Position.Y
				if UserInputService.VREnabled then
					y = -y
				end
				return Vector3.new(input.Position.X, 0, y)
			end
			break
		end
	end

	return Vector3.zero
end

local function getGamepadRightThumbstickY()
	if not UserInputService.GamepadEnabled and not UserInputService.VREnabled then
		return 0
	end

	local state = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, input in ipairs(state) do
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			if math.abs(input.Position.Y) > GAMEPAD_DEADZONE then
				return -input.Position.Y
			end
			break
		end
	end

	return 0
end

local function isGamepadButtonDown(keyCode)
	if not UserInputService.GamepadEnabled and not UserInputService.VREnabled then
		return false
	end

	local ok, result = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, keyCode)
	end)

	return ok and result or false
end
function SwimmingController:CalculateBuoyancy()
	if not self.RootPart then return 0 end

	local characterMass = self.RootPart.AssemblyMass
	local submergedRatio = math.clamp(-self.Depth / 10, 0, 1)

	local baseBuoyancy = WATER_DENSITY * characterMass * GRAVITY * submergedRatio * 0.001
	local weightForce = characterMass * GRAVITY

	local bcdInput = self:GetVerticalInput()

	self.BuoyancyTarget = math.clamp(self.BuoyancyTarget + bcdInput * 0.08, -2, 2)

	local bcdForce = self.BuoyancyTarget * characterMass * GRAVITY * 2.5

	return baseBuoyancy + bcdForce - weightForce
end

function SwimmingController:CalculateDrag(velocity)
	if velocity.Magnitude == 0 then
		return Vector3.zero
	end

	local speed = velocity.Magnitude
	local dragCoefficient = Settings.DragCoefficient or 0.15
	local dragMagnitude = 0.5 * WATER_DENSITY * speed * speed * dragCoefficient * 0.001

	return -velocity.Unit * dragMagnitude
end

function SwimmingController:GetCameraRelativeMovement()
	if not workspace.CurrentCamera then
		return Vector3.zero
	end

	local vrMove
	if self.VRController and self.VRController.IsActive and self.VRController.GetMoveVector then
		if self.VRController:IsActive() then
			vrMove = self.VRController:GetMoveVector()
		end
	end

	if vrMove and vrMove.Magnitude > 0.05 then
		return vrMove
	end

	local vrMoveX = Player:GetAttribute("VRMoveX")
	local vrMoveZ = Player:GetAttribute("VRMoveZ")
	local vrMoveMag = Player:GetAttribute("VRMoveMag")

	if typeof(vrMoveX) == "number" and typeof(vrMoveZ) == "number" then
		local move = Vector3.new(vrMoveX, 0, vrMoveZ)
		if (typeof(vrMoveMag) == "number" and vrMoveMag > 0.05) or move.Magnitude > 0.05 then
			return clampVector3(move, 1)
		end
	end

	local camera = workspace.CurrentCamera
	local cameraCFrame = camera.CFrame

	local inputX, inputZ = 0, 0

	if UserInputService:IsKeyDown(Enum.KeyCode.A) then inputX -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then inputX += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then inputZ += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then inputZ -= 1 end

	local usingMobileVector = UserInputService.TouchEnabled and self.MobileInputVector.Magnitude > 0.1
	local axisX, axisZ = inputX, inputZ

	if usingMobileVector then
		axisX = self.MobileInputVector.X
		axisZ = -self.MobileInputVector.Z
	else
		local gamepadVector = getGamepadThumbstick()
		if gamepadVector.Magnitude > 0.1 then
			axisX = gamepadVector.X
			axisZ = gamepadVector.Z
		end
	end

	local forward = cameraCFrame.LookVector
	local right = cameraCFrame.RightVector
	local moveVector = (right * axisX) + (forward * axisZ)

	if moveVector.Magnitude > 1 then
		moveVector = moveVector.Unit
	end

	return moveVector
end



function SwimmingController:UpdateMovement(deltaTime)
	if not self.RootPart or not self.LinearVelocity then
		return
	end

	local inputVector = self:GetCameraRelativeMovement()
	local targetSpeed = Settings.SwimmingSpeed * self.PressureMultiplier * self.SpeedMultiplier

	local bcdInput = self:GetVerticalInput()

	if bcdInput ~= 0 then
		self.BuoyancyTarget = math.clamp(self.BuoyancyTarget + bcdInput * 0.02, -1, 1)
	else
		self.BuoyancyTarget = self.BuoyancyTarget * 0.95
		if math.abs(self.BuoyancyTarget) < 0.01 then
			self.BuoyancyTarget = 0
		end
	end

	local bcdVerticalVelocity = self.BuoyancyTarget * 2
	local cameraBasedMovement = inputVector * targetSpeed

	local targetVelocity = cameraBasedMovement + Vector3.new(0, bcdVerticalVelocity, 0)

	local currentVelocity = self.RootPart.AssemblyLinearVelocity
	local acceleration = (inputVector.Magnitude > 0.1 or math.abs(bcdInput) > 0) and Settings.Acceleration or Settings.Deceleration
	local newVelocity = lerpVector3(currentVelocity, targetVelocity, acceleration * deltaTime)

	newVelocity = clampVector3(newVelocity, Settings.MaxVelocity)

	self.LinearVelocity.VectorVelocity = newVelocity

	self.CurrentVelocity = newVelocity
	self.MovementSpeed = newVelocity.Magnitude

	self:UpdateIK(deltaTime, bcdInput)
end

function SwimmingController:GetVerticalInput()
	local rightStickY = getGamepadRightThumbstickY()
	if math.abs(rightStickY) > 0 then
		return rightStickY
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or self.MobileUpPressed
		or isGamepadButtonDown(Enum.KeyCode.ButtonA)
		or isGamepadButtonDown(Enum.KeyCode.ButtonY)
	then
		return 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or self.MobileDownPressed
		or isGamepadButtonDown(Enum.KeyCode.ButtonB)
		or isGamepadButtonDown(Enum.KeyCode.ButtonX)
	then
		return -1
	end

	return 0
end

function SwimmingController:UpdatePhysicsForces()
	if not self.VectorForce then
		return
	end

	local totalForce = Vector3.zero

	local buoyancy = self:CalculateBuoyancy()
	totalForce = totalForce + Vector3.new(0, buoyancy, 0)

	local drag = self:CalculateDrag(self.CurrentVelocity)
	totalForce = totalForce + drag

	self.VectorForce.Force = totalForce
end

function SwimmingController:UpdateAnimations()
	if not self.CharacterController or not self.CharacterController.LoadedAnimation then
		return
	end

	local animations = self.CharacterController.LoadedAnimation
	local isMoving = self.MovementSpeed > 0.5

	for name, animation in animations do
		if name ~= "SwimmingIdle" then
			animation.Priority = Enum.AnimationPriority.Action
		else
			animation.Priority = Enum.AnimationPriority.Idle
		end
	end

	if not self.IsSwimming then
		self:StopAllSwimmingAnimations()
		return
	end

	if isMoving then
		if animations.Swimming then
			if not animations.Swimming.IsPlaying then
				if animations.SwimmingIdle and animations.SwimmingIdle.IsPlaying then
					animations.SwimmingIdle:Stop(ANIMATION_BLEND_TIME)
				end
				animations.Swimming:Play(ANIMATION_BLEND_TIME)
			end

			local baseSpeedRatio = self.MovementSpeed / Settings.SwimmingSpeed
			local verticalVelocity = self.CurrentVelocity.Y
			local verticalSpeedBoost = 1
			if verticalVelocity > 0.5 then
				verticalSpeedBoost = 1 + (verticalVelocity / 13)
			end

			local finalSpeedRatio = baseSpeedRatio * verticalSpeedBoost
			animations.Swimming:AdjustSpeed(math.clamp(finalSpeedRatio, 0.5, 3.0))
		end
	else
		if animations.SwimmingIdle then
			if not animations.SwimmingIdle.IsPlaying then
				if animations.Swimming and animations.Swimming.IsPlaying then
					animations.Swimming:Stop(ANIMATION_BLEND_TIME)
				end
				animations.SwimmingIdle:Play(ANIMATION_BLEND_TIME)
			end
		end
	end

	if isMoving and self.RootPart then
		local localMovement = self.RootPart.CFrame:VectorToObjectSpace(self.CurrentVelocity.Unit)

		self:HandleDirectionalAnimation(animations.SwimmingLeft, localMovement.X < -0.3)
		self:HandleDirectionalAnimation(animations.SwimmingRight, localMovement.X > 0.3)
		self:HandleDirectionalAnimation(animations.SwimUp, localMovement.Y > 0.3)
		self:HandleDirectionalAnimation(animations.SwimDown, localMovement.Y < -0.3)
	else
		self:HandleDirectionalAnimation(animations.SwimmingLeft, false)
		self:HandleDirectionalAnimation(animations.SwimmingRight, false)
		self:HandleDirectionalAnimation(animations.SwimUp, false)
		self:HandleDirectionalAnimation(animations.SwimDown, false)
	end
end

function SwimmingController:HandleDirectionalAnimation(animation, shouldPlay)
	if not animation then return end

	if shouldPlay then
		if not animation.IsPlaying then
			animation:Play(0.2)
		end
	else
		if animation.IsPlaying then
			animation:Stop(0.2)
		end
	end
end

function SwimmingController:StopAllSwimmingAnimations()
	if not self.CharacterController or not self.CharacterController.LoadedAnimation then
		return
	end

	local animations = self.CharacterController.LoadedAnimation
	local swimAnimations = {"Swimming", "SwimmingIdle", "SwimmingLeft", "SwimmingRight", "SwimUp", "SwimDown"}

	for _, animName in swimAnimations do
		local animation = animations[animName]
		if animation and animation.IsPlaying then
			animation:Stop(ANIMATION_BLEND_TIME)
		end
	end
end

function SwimmingController:CreatePhysicsConstraints()
	if not self.RootPart then
		warn("SwimmingController: No RootPart found")
		return
	end

	self:CleanupConstraints()

	local rootAttachment = self.RootPart:FindFirstChild("SwimmingAttachment")
	if not rootAttachment then
		rootAttachment = Instance.new("Attachment")
		rootAttachment.Name = "SwimmingAttachment"
		rootAttachment.Position = Vector3.zero
		rootAttachment.Parent = self.RootPart
	end

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Attachment0 = rootAttachment
	linearVelocity.Enabled = false
	linearVelocity.Parent = self.RootPart

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Force = Vector3.zero
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Attachment0 = rootAttachment
	vectorForce.Enabled = false
	vectorForce.Parent = self.RootPart

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = Settings.MaxTorque
	alignOrientation.MaxAngularVelocity = Settings.MaxAngularVelocity
	alignOrientation.Responsiveness = Settings.Responsiveness
	alignOrientation.Attachment0 = rootAttachment
	alignOrientation.Enabled = false
	alignOrientation.Parent = self.RootPart

	self.LinearVelocity = linearVelocity
	self.VectorForce = vectorForce
	self.AlignOrientation = alignOrientation
	self.RootAttachment = rootAttachment
end

function SwimmingController:CleanupConstraints()
	if self.LinearVelocity then self.LinearVelocity:Destroy() end
	if self.VectorForce then self.VectorForce:Destroy() end
	if self.AlignOrientation then self.AlignOrientation:Destroy() end
	if self.RootAttachment then self.RootAttachment:Destroy() end

	self.LinearVelocity = nil
	self.VectorForce = nil
	self.AlignOrientation = nil
	self.RootAttachment = nil
end

function SwimmingController:CreateIKControls()
	if not self.Character or not self.RootPart or not self.Humanoid then
		return
	end

	if self.Humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	self:CleanupIKControls()

	local leftHand = self.Character:FindFirstChild("LeftHand")
	local leftUpperArm = self.Character:FindFirstChild("LeftUpperArm")
	local upperTorso = self.Character:FindFirstChild("UpperTorso")

	if not leftHand then
		warn("SwimmingController: LeftHand not found for IK")
		return
	end

	if not leftUpperArm then
		warn("SwimmingController: LeftUpperArm not found for IK")
		return
	end

	if not upperTorso then
		warn("SwimmingController: UpperTorso not found for IK")
		return
	end

	if not waitForMotorLink(self.Character, leftUpperArm, leftHand, 1) then
		if not self.IKRetryScheduled and self.IKRetryAttempts < 10 then
			self.IKRetryAttempts += 1
			self.IKRetryScheduled = true
			local character = self.Character
			task.delay(1, function()
				self.IKRetryScheduled = false
				if self.Character == character and self.RootPart and self.Humanoid then
					self:CreateIKControls()
				end
			end)
		end
		return
	end

	local bcdInflatorAttachment = Instance.new("Attachment")
	bcdInflatorAttachment.Name = "BCDInflatorAttachment"
	bcdInflatorAttachment.Position = Vector3.new(0.25, 0.3, -0.75)
	bcdInflatorAttachment.Parent = upperTorso

	local bcdDeflatorAttachment = Instance.new("Attachment")
	bcdDeflatorAttachment.Name = "BCDDeflatorAttachment"
	bcdDeflatorAttachment.Position = Vector3.new(-0.75, -1.1, 0.5)
	bcdDeflatorAttachment.Parent = upperTorso

	local bubblesParticle = script:FindFirstChild("Bubbles")
	if bubblesParticle then
		local bubblesClone = bubblesParticle:Clone()
		bubblesClone.Parent = bcdDeflatorAttachment
		bubblesClone.Enabled = false
		self.BubblesParticle = bubblesClone
	end

	local poleAttachment = Instance.new("Attachment")
	poleAttachment.Name = "ArmPoleAttachment"
	poleAttachment.Position = Vector3.new(-2, 0, 0)
	poleAttachment.Parent = upperTorso

	local leftArmIK = Instance.new("IKControl")
	leftArmIK.Type = Enum.IKControlType.Position
	leftArmIK.EndEffector = leftHand
	leftArmIK.ChainRoot = leftUpperArm
	leftArmIK.Target = bcdInflatorAttachment
	leftArmIK.Pole = poleAttachment
	leftArmIK.Weight = 0
	leftArmIK.Parent = self.Humanoid

	self.LeftArmIK = leftArmIK
	self.BCDInflatorAttachment = bcdInflatorAttachment
	self.BCDDeflatorAttachment = bcdDeflatorAttachment
	self.PoleAttachment = poleAttachment
	self.IKRetryScheduled = false
	self.IKRetryAttempts = 0
end

function SwimmingController:CleanupIKControls()
	if self.LeftArmIK then
		self.LeftArmIK:Destroy()
		self.LeftArmIK = nil
	end
	if self.BCDInflatorAttachment then
		self.BCDInflatorAttachment:Destroy()
		self.BCDInflatorAttachment = nil
	end
	if self.BCDDeflatorAttachment then
		self.BCDDeflatorAttachment:Destroy()
		self.BCDDeflatorAttachment = nil
	end
	if self.PoleAttachment then
		self.PoleAttachment:Destroy()
		self.PoleAttachment = nil
	end
	if self.BubblesParticle then
		self.BubblesParticle = nil
	end
	self.CurrentIKWeight = 0
	self.IKRetryScheduled = false
end

function SwimmingController:UpdateIK(deltaTime, bcdInput)
	if not self.LeftArmIK then
		return
	end

	local targetWeight = (math.abs(bcdInput) > 0) and 1 or 0
	local lerpSpeed = 5
	self.CurrentIKWeight = lerp(self.CurrentIKWeight, targetWeight, lerpSpeed * deltaTime)

	if bcdInput > 0 then
		self.LeftArmIK.Target = self.BCDInflatorAttachment
		if self.BubblesParticle then
			self.BubblesParticle.Enabled = false
		end
	elseif bcdInput < 0 then
		self.LeftArmIK.Target = self.BCDDeflatorAttachment
		if self.BubblesParticle then
			self.BubblesParticle.Enabled = true
		end
	else
		if self.BubblesParticle then
			self.BubblesParticle.Enabled = false
		end
	end

	self.LeftArmIK.Weight = self.CurrentIKWeight
end

function SwimmingController:EnableSwimming()
	if self.IsSwimming then return end

	self.IsSwimming = true

	if self.LinearVelocity then
		self.LinearVelocity.Enabled = true
	end
	if self.VectorForce then
		self.VectorForce.Enabled = true
	end
	if self.AlignOrientation then
		local hasEquippedTool = self.Character and self.Character:FindFirstChildOfClass("Tool")
		if not hasEquippedTool then
			self.AlignOrientation.Enabled = true
		end
	end

	self:StartPhysicsUpdates()
	self:CreateMobileSwimmingUI()
	self:StartMobileInputMonitoring()
end

function SwimmingController:DisableSwimming()
	if not self.IsSwimming then return end

	self.IsSwimming = false

	if self.LinearVelocity then
		self.LinearVelocity.Enabled = false
		self.LinearVelocity.VectorVelocity = Vector3.zero
	end
	if self.VectorForce then
		self.VectorForce.Enabled = false
		self.VectorForce.Force = Vector3.zero
	end
	if self.AlignOrientation then
		self.AlignOrientation.Enabled = false
		if self.RootPart then
			self.AlignOrientation.CFrame = self.RootPart.CFrame
		end
	end

	self:StopAllSwimmingAnimations()
	self:StopPhysicsUpdates()
	self:DestroyMobileSwimmingUI()
	self:StopMobileInputMonitoring()

	self.CurrentVelocity = Vector3.zero
	self.MovementSpeed = 0
	self.BuoyancyTarget = 0
	self.MobileUpPressed = false
	self.MobileDownPressed = false
	self.MobileInputVector = Vector3.zero
end

function SwimmingController:StartPhysicsUpdates()
	self:StopPhysicsUpdates()

	self.Connections.PhysicsUpdate = RunService.Heartbeat:Connect(function(deltaTime)
		self:UpdatePhysics(deltaTime)
	end)
end

function SwimmingController:StopPhysicsUpdates()
	if self.Connections.PhysicsUpdate then
		self.Connections.PhysicsUpdate:Disconnect()
		self.Connections.PhysicsUpdate = nil
	end
end

function SwimmingController:UpdatePhysics(deltaTime)
	if not self.IsSwimming or not self.RootPart then
		return
	end

	local seaLevel = Settings.SeaLevel or 14.7
	self.Depth = self.RootPart.Position.Y - seaLevel

	local depth = math.abs(self.Depth)
	self.PressureMultiplier = math.max(0.3, 1 - (depth / 200) * 0.7)

	self:UpdateMovement(deltaTime)
	self:UpdatePhysicsForces()
	self:UpdateAnimations()
	self:UpdateOrientation()
end

function SwimmingController:UpdateOrientation()
	if not self.AlignOrientation or not self.RootPart then
		return
	end

	if self.ToolControlsOrientation then
		return
	end

	local inputVector = self:GetCameraRelativeMovement()
	local inputBlend = DEFAULT_INPUT_BLEND
	local rotationBlend = DEFAULT_ROTATION_BLEND

	local smoothedInput = self.PreviousInputVector:Lerp(inputVector, inputBlend)
	self.PreviousInputVector = smoothedInput

	if smoothedInput.Magnitude > 0.05 then
		local camera = workspace.CurrentCamera
		if not camera then return end

		local targetLookDirection = smoothedInput.Unit

		local rootPosition = self.RootPart.Position
		local targetCFrame = CFrame.lookAt(rootPosition, rootPosition + targetLookDirection)

		local currentCFrame = self.AlignOrientation.CFrame
		local smoothedCFrame = currentCFrame:Lerp(targetCFrame, rotationBlend)

		self.AlignOrientation.CFrame = smoothedCFrame
	else
		local currentCFrame = self.AlignOrientation.CFrame
		local uprightCFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + currentCFrame.LookVector)
		local smoothedCFrame = currentCFrame:Lerp(uprightCFrame, rotationBlend * 0.6)

		self.AlignOrientation.CFrame = smoothedCFrame
	end
end

function SwimmingController:ConnectEvents()
	self.Connections.SpeedMultiplierChanged = Player:GetAttributeChangedSignal("SwimSpeedMultiplier"):Connect(function()
		self:UpdateSpeedMultiplier()
	end)

	self.Connections.StateChanged = Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		local isSwimming = Player:GetAttribute("Swimming")
		if isSwimming then
			self:EnableSwimming()
		else
			self:DisableSwimming()
		end
	end)

	if self.CharacterController then
		self.Connections.CharacterAdded = self.CharacterController.Signals.Added.Event:Connect(function()
			self:OnCharacterAdded()
		end)

		self.Connections.CharacterRemoved = self.CharacterController.Signals.Removed.Event:Connect(function()
			self:OnCharacterRemoved()
		end)
	end
end



function SwimmingController:OnCharacterAdded()
	local character = Player.Character
	if not character then return end

	self.Character = character
	self.RootPart = character:WaitForChild("HumanoidRootPart", 5)
	self.Humanoid = character:WaitForChild("Humanoid", 5)

	if self.RootPart and self.Humanoid then
		self.IKRetryAttempts = 0
		self:CreatePhysicsConstraints()
		self:CreateIKControls()
		self:SetupToolMonitoring()

		local isSwimming = Player:GetAttribute("Swimming")
		if isSwimming then
			self:EnableSwimming()
		end
	end
end

function SwimmingController:OnCharacterRemoved()
	self:DisableSwimming()
	self:CleanupConstraints()
	self:CleanupIKControls()
	self:CleanupToolMonitoring()

	self.Character = nil
	self.RootPart = nil
	self.Humanoid = nil
	self.IKRetryScheduled = false
	self.IKRetryAttempts = 0
end

function SwimmingController:SetupToolMonitoring()
	if not self.Character then return end

	self:CleanupToolMonitoring()

	self.Connections.ToolAdded = self.Character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			self:OnToolEquipped(child)
		end
	end)

	self.Connections.ToolRemoved = self.Character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			self:OnToolUnequipped(child)
		end
	end)

	for _, child in pairs(self.Character:GetChildren()) do
		if child:IsA("Tool") then
			self:OnToolEquipped(child)
		end
	end
end

function SwimmingController:CleanupToolMonitoring()
	if self.Connections.ToolAdded then
		self.Connections.ToolAdded:Disconnect()
		self.Connections.ToolAdded = nil
	end

	if self.Connections.ToolRemoved then
		self.Connections.ToolRemoved:Disconnect()
		self.Connections.ToolRemoved = nil
	end
end

function SwimmingController:OnToolEquipped(tool)
	if self.AlignOrientation then
		self.AlignOrientation.Enabled = false
	end
end

function SwimmingController:OnToolUnequipped(tool)
	if self.AlignOrientation and self.IsSwimming then
		if self.RootPart then
			self.AlignOrientation.CFrame = self.RootPart.CFrame
		end
		self.AlignOrientation.Enabled = true
	end
end

function SwimmingController:Initialize()
	self:UpdateSpeedMultiplier()
	self.CharacterController = Mince:Get("CharacterController")
	self.VRController = Mince:Get("VRController")

	if not self.CharacterController then
		warn("SwimmingController: CharacterController not found")
		return
	end

	if self.CharacterController.Character then
		self:OnCharacterAdded()
	end

	self:ConnectEvents()
end

function SwimmingController:Cleanup()
	self:StopPhysicsUpdates()

	for _, connection in pairs(self.Connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.Connections = {}
	self._cachedTouchThumbstick = nil

	self:CleanupConstraints()
	self:StopAllSwimmingAnimations()
end

function SwimmingController:CreateMobileSwimmingUI()
	if not UserInputService.TouchEnabled then return end

	local PlayerGui = Player:WaitForChild("PlayerGui")
	local TouchGui = PlayerGui:FindFirstChild("TouchGui")
	if not TouchGui then return end

	local TouchControlFrame = TouchGui:FindFirstChild("TouchControlFrame")
	if not TouchControlFrame then return end

	local swimUpButton = Instance.new("TextButton")
	swimUpButton.Name = "SwimUpButton"
	swimUpButton.Size = UDim2.new(0, 70, 0, 70)
	swimUpButton.Position = UDim2.new(1, -90, 0, 10)
	swimUpButton.BackgroundColor3 = Color3.new(0.1, 0.5, 0.9)
	swimUpButton.BackgroundTransparency = 0.2
	swimUpButton.BorderSizePixel = 0
	swimUpButton.Text = "🔼"
	swimUpButton.TextColor3 = Color3.new(1, 1, 1)
	swimUpButton.TextSize = 28
	swimUpButton.Font = Enum.Font.SourceSansBold
	swimUpButton.Parent = TouchControlFrame

	local upCorner = Instance.new("UICorner")
	upCorner.CornerRadius = UDim.new(0, 8)
	upCorner.Parent = swimUpButton

	local swimDownButton = Instance.new("TextButton")
	swimDownButton.Name = "SwimDownButton"
	swimDownButton.Size = UDim2.new(0, 70, 0, 70)
	swimDownButton.Position = UDim2.new(1, -90, 0, 90)
	swimDownButton.BackgroundColor3 = Color3.new(0.1, 0.5, 0.9)
	swimDownButton.BackgroundTransparency = 0.2
	swimDownButton.BorderSizePixel = 0
	swimDownButton.Text = "🔽"
	swimDownButton.TextColor3 = Color3.new(1, 1, 1)
	swimDownButton.TextSize = 28
	swimDownButton.Font = Enum.Font.SourceSansBold
	swimDownButton.Parent = TouchControlFrame

	local downCorner = Instance.new("UICorner")
	downCorner.CornerRadius = UDim.new(0, 8)
	downCorner.Parent = swimDownButton

	self.Connections.SwimUpPressed = swimUpButton.MouseButton1Down:Connect(function()
		self.MobileUpPressed = true
	end)

	self.Connections.SwimUpReleased = swimUpButton.MouseButton1Up:Connect(function()
		self.MobileUpPressed = false
	end)

	self.Connections.SwimDownPressed = swimDownButton.MouseButton1Down:Connect(function()
		self.MobileDownPressed = true
	end)

	self.Connections.SwimDownReleased = swimDownButton.MouseButton1Up:Connect(function()
		self.MobileDownPressed = false
	end)

	self.SwimUpButton = swimUpButton
	self.SwimDownButton = swimDownButton
end

function SwimmingController:DestroyMobileSwimmingUI()
	if self.SwimUpButton then
		self.SwimUpButton:Destroy()
		self.SwimUpButton = nil
	end

	if self.SwimDownButton then
		self.SwimDownButton:Destroy()
		self.SwimDownButton = nil
	end

	if self.Connections.SwimUpPressed then
		self.Connections.SwimUpPressed:Disconnect()
		self.Connections.SwimUpPressed = nil
	end

	if self.Connections.SwimUpReleased then
		self.Connections.SwimUpReleased:Disconnect()
		self.Connections.SwimUpReleased = nil
	end

	if self.Connections.SwimDownPressed then
		self.Connections.SwimDownPressed:Disconnect()
		self.Connections.SwimDownPressed = nil
	end

	if self.Connections.SwimDownReleased then
		self.Connections.SwimDownReleased:Disconnect()
		self.Connections.SwimDownReleased = nil
	end
end

function SwimmingController:StartMobileInputMonitoring()
	if not UserInputService.TouchEnabled then return end

	self.Connections.MobileInputUpdate = RunService.Heartbeat:Connect(function()
		local mobileInput = Vector3.zero
		local foundInput = false

		if ControlModule and ControlModule.activeController and ControlModule.activeController.moveVector then
			local moveVector = ControlModule.activeController.moveVector
			if moveVector.Magnitude > 0.05 then
				mobileInput = Vector3.new(moveVector.X, 0, moveVector.Z)
				foundInput = true
			end
		end

		if not foundInput then
			if not self._cachedTouchThumbstick then
				local PlayerGui = Player:FindFirstChild("PlayerGui")
				local TouchGui = PlayerGui and PlayerGui:FindFirstChild("TouchGui")
				local TouchControlFrame = TouchGui and TouchGui:FindFirstChild("TouchControlFrame")
				if TouchControlFrame then
					for _, child in pairs(TouchControlFrame:GetChildren()) do
						if child.Name:find("Thumbstick") and child:FindFirstChild("moveVector") then
							self._cachedTouchThumbstick = child
							break
						end
					end
				end
			end

			if self._cachedTouchThumbstick then
				if self._cachedTouchThumbstick.Parent then
					local moveVector = self._cachedTouchThumbstick.moveVector.Value
					if moveVector.Magnitude > 0.05 then
						mobileInput = Vector3.new(moveVector.X, 0, moveVector.Z)
						foundInput = true
					end
				else
					self._cachedTouchThumbstick = nil
				end
			end
		end

		if not foundInput and self.Humanoid then
			local moveVector = self.Humanoid.MoveDirection
			if moveVector.Magnitude > 0.05 then
				mobileInput = Vector3.new(moveVector.X, 0, moveVector.Z)
			end
		end

		self.MobileInputVector = mobileInput
	end)
end

function SwimmingController:StopMobileInputMonitoring()
	if self.Connections.MobileInputUpdate then
		self.Connections.MobileInputUpdate:Disconnect()
		self.Connections.MobileInputUpdate = nil
	end
	self.MobileInputVector = Vector3.zero
end

task.delay(1, function()
	SwimmingController:Initialize()
end)

return SwimmingController