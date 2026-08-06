local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Mince = require(Modules.Mince)
local DPVUtil = require(Modules.DPVUtil)
local Player = Mince.Player
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:FindFirstChild("Sounds")

local TARGET_SPEED = 30
local PROP_TARGET_SPEED = 30
local SOUND_SPIN_THRESHOLD = 0.02
local MOTOR_MIN_PITCH = 0.2
local MOTOR_MAX_PITCH = 1.6
local SOUND_RESPONSE_TIME = 0.25
local DEFAULT_IDLE_ANIM_ID = "rbxassetid://89021846421149"
local DEFAULT_FORWARD_ANIM_ID = "rbxassetid://74333949970603"

local DoubleDPV = Mince.Component {
	Tag = "DoubleDPV",
	CreationParents = {workspace},
}

local function findMotorSoundTemplate()
	if not Sounds then
		return nil
	end
	local scooterFolder = Sounds:FindFirstChild("Scooter")
	if scooterFolder then
		local sound = scooterFolder:FindFirstChild("MotorLoop", true)
		if sound and sound:IsA("Sound") then
			return sound
		end
	end
	local anySound = Sounds:FindFirstChildWhichIsA("Sound", true)
	return anySound
end

local function setupAnimation(animations, name, animationId)
	local animObject = animations:FindFirstChild(name)
	if not animObject then
		animObject = Instance.new("Animation")
		animObject.Name = name
		animObject.Parent = animations
	end

	if animObject:IsA("Animation") and animationId then
		animObject.AnimationId = animationId
	end

	return animObject
end

function DoubleDPV:LoadAnimations()
	local tool = self.Instance
	local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animations = tool:FindFirstChild("Animations")
	if not animations then
		animations = Instance.new("Folder")
		animations.Name = "Animations"
		animations.Parent = tool
	end

	setupAnimation(animations, "Idle", DEFAULT_IDLE_ANIM_ID)
	setupAnimation(animations, "Forward", DEFAULT_FORWARD_ANIM_ID)

	self:UnloadAnimations()

	self.LoadedAnimations = DPVUtil.loadAnimationTracks(humanoid, animations, {
		"Forward",
		"Left",
		"Right",
		"Idle",
	})
end

function DoubleDPV:UnloadAnimations()
	self.LoadedAnimations = DPVUtil.destroyAnimationTracks(self.LoadedAnimations)
end

function DoubleDPV:StopAnimations()
	DPVUtil.stopAnimationTracks(self.LoadedAnimations)
end

function DoubleDPV:PlayAnimations()
	local isSwimming = Player:GetAttribute("Swimming") == true
	if not isSwimming or not self.SwimmingController then
		self:StopAnimations()
		return
	end

	local character = Player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

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

function DoubleDPV:AttachMotorSound(parentPart)
	self:DestroyMotorSound()

	local template = findMotorSoundTemplate()
	if not template or not parentPart then
		return
	end

	local sound = template:Clone()
	sound.Name = "DPVMotorLoop"
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = MOTOR_MIN_PITCH
	sound.Parent = parentPart

	self.MotorSound = sound
	self.MotorSoundState = {
		Volume = 0,
		Pitch = MOTOR_MIN_PITCH,
	}
end

function DoubleDPV:DestroyMotorSound()
	if self.MotorSound then
		self.MotorSound:Stop()
		self.MotorSound:Destroy()
	end
	self.MotorSound = nil
	self.MotorSoundState = nil
end

function DoubleDPV:UpdateMotorSound(speedRatio, deltaTime)
	if not deltaTime then
		return
	end

	self.MotorSoundState = DPVUtil.updateMotorSound(self.MotorSound, self.MotorSoundState, speedRatio, deltaTime, {
		threshold = SOUND_SPIN_THRESHOLD,
		minPitch = MOTOR_MIN_PITCH,
		maxPitch = MOTOR_MAX_PITCH,
		responseTime = SOUND_RESPONSE_TIME,
	})
end

function DoubleDPV:InitMotors()
	self.Motors = {
		LeftMotor = self.Instance:FindFirstChild("LeftMotor", true),
		RightMotor = self.Instance:FindFirstChild("RightMotor", true),
	}

	self.MotorState = {}
	for name, attachment in pairs(self.Motors) do
		if attachment and attachment:IsA("Attachment") then
			self.MotorState[name] = {
				Attachment = attachment,
				BaseCFrame = attachment.CFrame,
				Speed = 0,
			}
		end
	end

	local parentPart = self.Instance:FindFirstChild("Handle")
	if not parentPart then
		parentPart = self.Instance:FindFirstChildWhichIsA("BasePart", true)
	end
	if parentPart then
		self:AttachMotorSound(parentPart)
	end
end

function DoubleDPV:ResetMotors()
	for _, motor in pairs(self.MotorState or {}) do
		motor.Speed = 0
		if motor.Attachment and motor.BaseCFrame then
			motor.Attachment.CFrame = motor.BaseCFrame
		end
	end
end

function DoubleDPV:UpdateMotors(deltaTime, speed)
	if not self.MotorState then
		return
	end

	local targetRotationSpeed = math.clamp(speed / TARGET_SPEED, 0, 1) * PROP_TARGET_SPEED
	local speedRatio = PROP_TARGET_SPEED > 0 and math.clamp(targetRotationSpeed / PROP_TARGET_SPEED, 0, 1) or 0

	self:UpdateMotorSound(speedRatio, deltaTime)

	for _, motor in pairs(self.MotorState) do
		local attachment = motor.Attachment
		if attachment and attachment.Parent then
			motor.Speed = motor.Speed + (targetRotationSpeed - motor.Speed) * 0.2
			local rotationAngle = math.rad(motor.Speed * deltaTime * 60)
			if math.abs(rotationAngle) > 1e-4 then
				attachment.CFrame = attachment.CFrame * CFrame.Angles(rotationAngle, 0, 0)
			end
		end
	end
end

function DoubleDPV:StartAnimationUpdate()
	self:StopAnimationUpdate()

	self.AnimationConnection = RunService.Heartbeat:Connect(function()
		self:PlayAnimations()
	end)
end

function DoubleDPV:StopAnimationUpdate()
	if self.AnimationConnection then
		self.AnimationConnection:Disconnect()
		self.AnimationConnection = nil
	end
end

function DoubleDPV:OnSwimmingChanged()
	local isSwimming = Player:GetAttribute("Swimming") == true
	self.Swimming = isSwimming

	if self.EquippedTool then
		if isSwimming then
			self:StartHeadingUpdates()
			self:StartAnimationUpdate()
		else
			self:StopHeadingUpdates()
			self:StopAnimationUpdate()
			self:StopAnimations()
			local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end
	end
end

function DoubleDPV:StartHeadingUpdates()
	if self.HeadingConnection or not self.EquippedTool then
		return
	end

	self.HeadingConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if Player:GetAttribute("Swimming") ~= true then
			local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
			return
		end

		local character = Player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local rootPart = humanoid.RootPart or character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		local velocity = rootPart.AssemblyLinearVelocity
		local speed = velocity.Magnitude

		self:UpdateMotors(deltaTime, speed)


	end)
end

function DoubleDPV:StopHeadingUpdates()
	if self.HeadingConnection then
		self.HeadingConnection:Disconnect()
		self.HeadingConnection = nil
	end
end

function DoubleDPV:OnEquipped()
	local tool = self.Instance

	if Player:GetAttribute("Swimming") ~= true then
		local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
		return
	end

	self.EquippedTool = tool
	self:InitMotors()
	self:LoadAnimations()

	if self.Register then
		self.Register:Fire(tool)
	end

	self:StartHeadingUpdates()
	self:StartAnimationUpdate()
end

function DoubleDPV:OnUnequipped()
	local tool = self.Instance

	self:StopHeadingUpdates()
	self:StopAnimationUpdate()
	self:StopAnimations()
	self:UnloadAnimations()

	if self.Unregister then
		self.Unregister:Fire(tool)
	end

	self:DestroyMotorSound()
	self:ResetMotors()

	self.EquippedTool = nil
end

function DoubleDPV:Construct()
	self.DPVEvent = Mince:GetEvent("DoubleDPV")
	self.Register = self.DPVEvent and self.DPVEvent:Extend("Register")
	self.Unregister = self.DPVEvent and self.DPVEvent:Extend("Unregister")

	self.SwimmingController = Mince:Get("SwimmingController")

	self.Connections = {}
	self.Swimming = false
	self.HeadingConnection = nil
	self.AnimationConnection = nil
	self.EquippedTool = nil
	self.Motors = nil
	self.MotorState = nil
	self.MotorSound = nil
	self.MotorSoundState = nil
	self.LoadedAnimations = {}

	self:OnSwimmingChanged()

	self.Connections.SwimmingChanged = Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		self:OnSwimmingChanged()
	end)

	self.Connections.Equipped = self.Instance.Equipped:Connect(function()
		self:OnEquipped()
	end)

	self.Connections.Unequipped = self.Instance.Unequipped:Connect(function()
		self:OnUnequipped()
	end)
end

function DoubleDPV:Destruct()
	self:StopHeadingUpdates()
	self:StopAnimationUpdate()
	self:StopAnimations()
	self:UnloadAnimations()

	for _, conn in pairs(self.Connections) do
		conn:Disconnect()
	end
	self.Connections = {}

end

return DoubleDPV
