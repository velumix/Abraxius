local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local ScooterSounds = Assets:WaitForChild("Sounds"):WaitForChild("Scooter")

local TARGET_SPEED = 30
local SOUND_SPIN_THRESHOLD = 0.02

local Mince = require(Modules.Mince)
local UI = require(Modules.UI)

local Scooter = Mince.Component {
	Tag = "SingleDPV",
}

function Scooter:LoadAnimations()
	local tool = self.Instance
	if not self.CharacterController then return end
	local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local Animations = tool:WaitForChild("Animations", 5)
	if not Animations then return end

	self:UnloadAnimations()

	local animationNames = {"Forward", "Left", "Right", "Idle"}
	for _, animName in pairs(animationNames) do
		local animObject = Animations:FindFirstChild(animName)
		if animObject and animObject:IsA("Animation") then
			local track = humanoid:LoadAnimation(animObject)
			if animName == "Idle" then
				track.Priority = Enum.AnimationPriority.Action
			else
				track.Priority = Enum.AnimationPriority.Action2
			end
			self.LoadedAnimations[animName] = track
		end
	end
end

function Scooter:UnloadAnimations()
	for name, track in pairs(self.LoadedAnimations) do
		if track.IsPlaying then
			track:Stop()
		end
		track:Destroy()
	end
	self.LoadedAnimations = {}
end

function Scooter:PlayAnimations()
	if not self.Swimming or not self.SwimmingController then
		self:StopAnimations()
		return
	end

	local character = Player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local movementSpeed = self.SwimmingController.MovementSpeed or 0
	local currentVelocity = self.SwimmingController.CurrentVelocity or Vector3.zero
	local isMoving = movementSpeed > 0.5

	self:UpdateMotorAndEmitter(movementSpeed)
	self:UpdateGripTilt(rootPart, currentVelocity, movementSpeed)
	self:UpdatePlayerTilt(rootPart, currentVelocity, movementSpeed)

	if isMoving then
		if self.LoadedAnimations.Idle and self.LoadedAnimations.Idle.IsPlaying then
			self.LoadedAnimations.Idle:Stop(0.2)
		end

		if self.LoadedAnimations.Forward and not self.LoadedAnimations.Forward.IsPlaying then
			self.LoadedAnimations.Forward:Play(0.2, 1, 1)
		end

		if self.LoadedAnimations.Forward and self.LoadedAnimations.Forward.IsPlaying then
			local speedRatio = movementSpeed / 13
			self.LoadedAnimations.Forward:AdjustSpeed(math.clamp(speedRatio, 0.5, 2.0))
		end

		local localMovement = rootPart.CFrame:VectorToObjectSpace(currentVelocity.Unit)

		if localMovement.X < -0.3 then
			if self.LoadedAnimations.Left and not self.LoadedAnimations.Left.IsPlaying then
				self.LoadedAnimations.Left:Play(0.2, 1, 1)
			end
		else
			if self.LoadedAnimations.Left and self.LoadedAnimations.Left.IsPlaying then
				self.LoadedAnimations.Left:Stop(0.2)
			end
		end

		if localMovement.X > 0.3 then
			if self.LoadedAnimations.Right and not self.LoadedAnimations.Right.IsPlaying then
				self.LoadedAnimations.Right:Play(0.2, 1, 1)
			end
		else
			if self.LoadedAnimations.Right and self.LoadedAnimations.Right.IsPlaying then
				self.LoadedAnimations.Right:Stop(0.2)
			end
		end
	else
		if self.LoadedAnimations.Forward and self.LoadedAnimations.Forward.IsPlaying then
			self.LoadedAnimations.Forward:Stop(0.2)
		end
		if self.LoadedAnimations.Left and self.LoadedAnimations.Left.IsPlaying then
			self.LoadedAnimations.Left:Stop(0.2)
		end
		if self.LoadedAnimations.Right and self.LoadedAnimations.Right.IsPlaying then
			self.LoadedAnimations.Right:Stop(0.2)
		end

		if self.LoadedAnimations.Idle and not self.LoadedAnimations.Idle.IsPlaying then
			self.LoadedAnimations.Idle:Play(0.2, 1, 1)
		end
	end
end

function Scooter:StopAnimations()
	for name, track in pairs(self.LoadedAnimations) do
		if track.IsPlaying then
			track:Stop()
		end
	end
end

function Scooter:UpdateGripTilt(rootPart, velocity, speed)
	if not self.EquippedTool or not self.OriginalGrip then return end
	local localMovement = rootPart.CFrame:VectorToObjectSpace(velocity.Unit)

	local tiltAmount = 90
	local targetRoll = math.clamp(localMovement.X * tiltAmount, -tiltAmount, tiltAmount)
	local targetPitch = math.clamp(-localMovement.Y * tiltAmount, -tiltAmount, tiltAmount)

	local speedMultiplier = math.clamp(speed / 10, 0, 1)
	targetRoll = targetRoll * speedMultiplier
	targetPitch = targetPitch * speedMultiplier

	local tiltCFrame = CFrame.Angles(math.rad(targetPitch), 0, math.rad(targetRoll))
	local targetGrip = self.OriginalGrip * tiltCFrame

	local alpha = 0.2
	self.EquippedTool.Grip = self.EquippedTool.Grip:Lerp(targetGrip, alpha)
end

function Scooter:UpdatePlayerTilt(rootPart, velocity, speed)
	if not self.SwimmingController or not self.SwimmingController.AlignOrientation then return end
	local localMovement = rootPart.CFrame:VectorToObjectSpace(velocity.Unit)

	local tiltAmount = 45
	local targetRoll = math.clamp(-localMovement.X * tiltAmount, -tiltAmount, tiltAmount)

	local speedMultiplier = math.clamp(speed / 10, 0, 1)
	targetRoll = targetRoll * speedMultiplier

	local targetCFrame = rootPart.CFrame * CFrame.Angles(0, 0, math.rad(targetRoll))

	local alpha = 0.2
	self.SwimmingController.AlignOrientation.CFrame = self.SwimmingController.AlignOrientation.CFrame:Lerp(targetCFrame, alpha)
end

function Scooter:UpdateMotorAndEmitter(currentSpeed)
	local speedRatio = math.clamp(currentSpeed / TARGET_SPEED, 0, 1)
	local targetRotationSpeed = speedRatio * TARGET_SPEED

	if self.Emitter then
		self.Emitter.Rate = targetRotationSpeed
	end

	self:UpdateRotationTarget(targetRotationSpeed)
	self:UpdateMotorSound(speedRatio)
end

function Scooter:UpdateRotationTarget(targetRotationSpeed)
	if not self.ScooterEvent or not self.UpdateSpeed then
		return
	end

	if self.CurrentMotorTween then
		self.CurrentMotorTween:Cancel()
		self.CurrentMotorTween = nil
	end

	if not self.RotationSpeedValue then
		self.RotationSpeedValue = Instance.new("NumberValue")
		self.RotationSpeedValue.Value = self.RotationSpeed
		self.RotationSpeedValue.Changed:Connect(function(value)
			self.RotationSpeed = value
			self.UpdateSpeed:Fire(value)
		end)
	end

	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self.CurrentMotorTween = TweenService:Create(self.RotationSpeedValue, tweenInfo, {
		Value = targetRotationSpeed
	})
	self.CurrentMotorTween:Play()
end

function Scooter:AttachMotorSound()
	local tool = self.Instance
	self:DestroyMotorSound()

	if not ScooterSounds then
		return
	end

	local template = ScooterSounds:FindFirstChildWhichIsA("Sound", true)
	if not template then
		return
	end

	local parentPart = tool:FindFirstChild("Handle")
	if not parentPart then
		parentPart = tool:FindFirstChildWhichIsA("BasePart", true)
	end

	if not parentPart then
		warn("Scooter tool missing a base part for motor sound")
		return
	end

	local sound = template:Clone()
	sound.Name = "MotorLoop"
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = 0.1
	sound.Parent = parentPart
	self.MotorSound = sound
end

function Scooter:DestroyMotorSound()
	if self.MotorSound then
		self.MotorSound:Stop()
		self.MotorSound:Destroy()
		self.MotorSound = nil
	end
end

function Scooter:UpdateMotorSound(speedRatio)
	if not self.MotorSound then
		return
	end

	if speedRatio <= SOUND_SPIN_THRESHOLD then
		self.MotorSound.Volume = 0
		if self.MotorSound.IsPlaying then
			self.MotorSound:Stop()
		end
		return
	end

	if not self.MotorSound.IsPlaying then
		self.MotorSound:Play()
	end

	self.MotorSound.Volume = math.clamp(speedRatio, 0, 1)
	self.MotorSound.PlaybackSpeed = math.clamp(speedRatio, 0.2, 1.6)
end

function Scooter:OnSwimmingChanged()
	self.Swimming = Player:GetAttribute("Swimming") or false

	if self.EquippedTool then
		if self.Swimming then
			self:EnableScooterBoost()
			self:EnableOrientation()
			self:StartAnimationUpdate()
		else
			self:DisableScooterBoost()
			self:StopAnimationUpdate()
			self:StopAnimations()

			local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
				UI.Notify("You must be swimming to use the scooter!", "Info", 3)
			end
		end

	end
end

function Scooter:OnEquipped()
	local tool = self.Instance
	if not self.Swimming then
		local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
			UI.Notify("You must be swimming to use the scooter!", "Info", 3)
		end
		return
	end

	self.EquippedTool = tool
	self:LoadAnimations()

	self.OriginalGrip = tool.Grip

	self.Emitter = tool:FindFirstChild("Emitter", true)
	self.RotationAttachment = tool:FindFirstChild("Rotation", true)

	if self.RotationAttachment then
		self.RotationSpeed = 0
		if self.Register then
			self.Register:Fire(tool)
		end
	end

	if self.Emitter then
		self.Emitter.Rate = 0
	end

	self:AttachMotorSound()

	if self.Swimming then
		self:EnableScooterBoost()
		self:EnableOrientation()
		self:StartAnimationUpdate()
	end
end

function Scooter:OnUnequipped()
	local tool = self.Instance
	self:DisableScooterBoost()
	self:StopAnimationUpdate()
	self:StopAnimations()
	self:UnloadAnimations()

	if self.CurrentMotorTween then
		self.CurrentMotorTween:Cancel()
		self.CurrentMotorTween = nil
	end

	if self.RotationSpeedValue then
		self.RotationSpeedValue:Destroy()
		self.RotationSpeedValue = nil
	end

	if self.Unregister then
		self.Unregister:Fire()
	end

	self.RotationSpeed = 0

	if self.Emitter then
		self.Emitter.Rate = 0
	end
	self:DestroyMotorSound()

	if self.OriginalGrip and self.EquippedTool then
		self.EquippedTool.Grip = self.OriginalGrip
	end

	self.OriginalGrip = nil
	self.RotationAttachment = nil
	self.Emitter = nil
	self.EquippedTool = nil
end

function Scooter:EnableScooterBoost()
	if not self.SwimmingSettings then return end
	if self.OriginalSwimmingSpeed == nil or self.SwimmingSettings.SwimmingSpeed / self.OriginalSwimmingSpeed == self.ScooterSpeedMultiplier then
		self.OriginalSwimmingSpeed = self.SwimmingSettings.SwimmingSpeed / self.ScooterSpeedMultiplier
	end
	self.SwimmingSettings.SwimmingSpeed = self.OriginalSwimmingSpeed * self.ScooterSpeedMultiplier
end

function Scooter:DisableScooterBoost()
	if not self.SwimmingSettings then return end
	self.SwimmingSettings.SwimmingSpeed = self.OriginalSwimmingSpeed
end

function Scooter:EnableOrientation()
	if not self.SwimmingController or not self.SwimmingController.AlignOrientation then return end
	local rootPart = self.SwimmingController.RootPart
	if rootPart and self.SwimmingController.AlignOrientation then
		self.SwimmingController.AlignOrientation.CFrame = rootPart.CFrame
		self.SwimmingController.AlignOrientation.Enabled = true
	end
end

function Scooter:StartAnimationUpdate()
	self:StopAnimationUpdate()

	self.Connections.AnimationUpdate = RunService.Heartbeat:Connect(function(dt)
		self:PlayAnimations()
	end)
end

function Scooter:StopAnimationUpdate()
	if self.Connections.AnimationUpdate then
		self.Connections.AnimationUpdate:Disconnect()
		self.Connections.AnimationUpdate = nil
	end
end

function Scooter:OnCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		self.Connections.Died = humanoid.Died:Connect(function()
			self:DisableScooterBoost()
			self:StopAnimationUpdate()
			self:StopAnimations()
		end)
	end
end

function Scooter:Construct()
	self.CharacterController = Mince:Get("CharacterController")
	self.SwimmingController = Mince:Get("SwimmingController")

	self.ScooterEvent = Mince:GetEvent("Scooter")
	self.Register = self.ScooterEvent and self.ScooterEvent:Extend("Register")
	self.Unregister = self.ScooterEvent and self.ScooterEvent:Extend("Unregister")
	self.UpdateSpeed = self.ScooterEvent and self.ScooterEvent:Extend("UpdateSpeed")

	self.LoadedAnimations = {}
	self.Connections = {}
	self.Swimming = false
	self.OriginalSwimmingSpeed = 6
	self.ScooterSpeedMultiplier = 2.5
	self.RotationSpeed = 0
	self.TargetRotationSpeed = 0

	if not self.CharacterController then
		warn("Scooter: CharacterController not found")
	end

	if not self.SwimmingController then
		warn("Scooter: SwimmingController not found")
	end

	local SwimmingControllerScript = script.Parent.Parent.Controllers.SwimmingController
	if SwimmingControllerScript and SwimmingControllerScript:FindFirstChild("Settings") then
		self.SwimmingSettings = require(SwimmingControllerScript.Settings)
	else
		warn("Scooter: SwimmingController Settings not found")
	end

	self.Swimming = Player:GetAttribute("Swimming") or false
	self.Connections.SwimmingChanged = Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		self:OnSwimmingChanged()
	end)

	self.Connections.Equipped = self.Instance.Equipped:Connect(function()
		self:OnEquipped()
	end)

	self.Connections.Unequipped = self.Instance.Unequipped:Connect(function()
		self:OnUnequipped()
	end)

	self.Connections.CharacterAdded = Player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(character)
	end)

	if Player.Character then
		self:OnCharacterAdded(Player.Character)
	end
end

function Scooter:Destruct()
	self:DisableScooterBoost()

	for _, connection in pairs(self.Connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.Connections = {}
	self:UnloadAnimations()

	if self.CurrentMotorTween then
		self.CurrentMotorTween:Cancel()
		self.CurrentMotorTween = nil
	end

	if self.RotationSpeedValue then
		self.RotationSpeedValue:Destroy()
		self.RotationSpeedValue = nil
	end

	self.RotationAttachment = nil
	self.Emitter = nil
	self.RotationSpeed = 0
	self.EquippedTool = nil
	self:DestroyMotorSound()
end

return Scooter