local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage.Modules
local Assets = ReplicatedStorage.Assets
local Sounds = Assets.Sounds.Scooter

local Mince = require(Modules.Mince)
local SpeedBoostService = require(ServerStorage.Modules.Services.SpeedBoostService)

local SPEED_ATTRIBUTE = "SwimSpeedMultiplier"
local SPEED_MULTIPLIER = 5
local MAX_ROLL_DEG = 35
local MAX_PITCH_DEG = 35
local TARGET_SPEED = 30
local PIVOT_RESPONSE_TIME = 0.3
local PIVOT_RETURN_TIME = 0.25
local PIVOT_SWAY_PITCH_DEG = 0.6
local PIVOT_SWAY_ROLL_DEG = 0.45
local PIVOT_SWAY_SPEED = 0.9
local PROP_TARGET_SPEED = 30
local SOUND_SPIN_THRESHOLD = 0.02
local MOTOR_MIN_PITCH = 0.2
local MOTOR_MAX_PITCH = 1.6
local SOUND_RESPONSE_TIME = 0.25
local MOTOR_CHANNEL_OFFSET = 0.08

local DPV_ACTIVE_ATTRIBUTE = "UsingDoubleDPV"

local NoticeEvent = Mince:GetEvent("NoticeEvent")

local DPVService = {
	Name = "DPVService",
	DoubleDPV = Mince.Component{Tag = "DoubleDPV"},
}

local NOT_SWIMMING_MESSAGE = "You must be swimming to use the Double DPV!"

local function getAttachments(tool)
	local character = tool.Parent
	if not (character and character:IsA("Model")) then
		return nil, nil
	end

	local toolAttachment = tool:FindFirstChild("NeckAttachment", true)
	if not toolAttachment then
		return nil, nil
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	local torsoAttachment = upperTorso and upperTorso:FindFirstChild("NeckAttachment")

	if not torsoAttachment then
		return nil, nil
	end

	return toolAttachment, torsoAttachment
end

local function createAttachmentWeld(toolAttachment, torsoAttachment)
	local toolPart = toolAttachment and toolAttachment.Parent
	local torsoPart = torsoAttachment and torsoAttachment.Parent

	if not (toolPart and torsoPart) then
		return nil
	end

	if not (toolPart:IsA("BasePart") and torsoPart:IsA("BasePart")) then
		return nil
	end

	local weld = Instance.new("Motor6D")
	weld.Name = "DoubleDPVWeld"
	weld.Part0 = toolPart
	weld.Part1 = torsoPart
	weld.C0 = toolAttachment.CFrame
	weld.C1 = torsoAttachment.CFrame
	weld.Parent = toolPart

	return weld
end

local function findPivotAttachment(mainPart)
	if not (mainPart and mainPart:IsA("BasePart")) then
		return nil
	end

	local pivotAttachment = mainPart:FindFirstChild("PivotAttachment", true)
	if pivotAttachment and pivotAttachment:IsA("Attachment") then
		return pivotAttachment
	end

	local pivot = mainPart:FindFirstChild("Pivot")
	if pivot and pivot:IsA("Attachment") then
		return pivot
	end

	if pivot and pivot:IsA("BasePart") then
		local childAttachment = pivot:FindFirstChildWhichIsA("Attachment", true)
		if childAttachment then
			return childAttachment
		end
	end

	return nil
end

local function buildMotorAdjacency(character)
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

	local adjacency = buildMotorAdjacency(character)
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

local function smoothAngle(current, target, responseTime, deltaTime)
	if responseTime <= 0 or not deltaTime then
		return target
	end
	local alpha = 1 - math.exp(-deltaTime / responseTime)
	return current + (target - current) * alpha
end

local function smoothAngleWrap(current, target, responseTime, deltaTime)
	if responseTime <= 0 or not deltaTime then
		return target
	end
	local alpha = 1 - math.exp(-deltaTime / responseTime)
	local delta = (target - current + 180) % 360 - 180
	return current + (delta * alpha)
end

local function setIK(ikControl, humanoid, chainRootName, endEffectorName, target)
	if not (ikControl and humanoid and target) then
		return
	end

	local character = humanoid.Parent

	if not (character and character:IsA("Model")) then
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		ikControl.Enabled = false
		return
	end

	local chainRoot = character:FindFirstChild(chainRootName)
	local endEffector = character:FindFirstChild(endEffectorName)

	if not chainRoot then
		chainRoot = character:WaitForChild(chainRootName, 1)
	end

	if not endEffector then
		endEffector = character:WaitForChild(endEffectorName, 1)
	end

	if not (chainRoot and endEffector) then
		ikControl.Enabled = false
		return
	end

	if not (chainRoot:IsA("BasePart") and endEffector:IsA("BasePart")) then
		ikControl.Enabled = false
		return
	end

	if not waitForMotorLink(character, chainRoot, endEffector, 2) then
		ikControl.Enabled = false
		return
	end

	ikControl.Type = Enum.IKControlType.Position
	ikControl.ChainRoot = chainRoot
	ikControl.EndEffector = endEffector
	ikControl.Target = target
	ikControl.Weight = 1
	ikControl.Enabled = true
	ikControl.Parent = humanoid

end

function DPVService.DoubleDPV:ResetSpeedBoost()
	if self.Player then
		SpeedBoostService:Clear(self.Player, self.Instance)
		self.Player:SetAttribute(DPV_ACTIVE_ATTRIBUTE, false)
	end
end

function DPVService.DoubleDPV:AttachMotorSound()
	self:DestroyMotorSound()

	if not Sounds then
		return
	end

	local template = Sounds:FindFirstChild("MotorLoop", true)
	if not template then
		template = Sounds:FindFirstChildWhichIsA("Sound", true)
	end

	if not template then
		warn("Double DPV missing motor sound template")
		return
	end

	local parentPart = self.Instance:FindFirstChild("Handle")
	if not parentPart then
		parentPart = self.Instance:FindFirstChildWhichIsA("BasePart", true)
	end

	if not parentPart then
		warn("Double DPV missing base part for motor sound")
		return
	end

	local sound = template:Clone()
	sound.Name = "DPVMotorLoop"
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = 0.1
	self.MotorSounds = {}

	local function attachChannel(channelName, motorAttachment, offset)
		local channelParent = motorAttachment and motorAttachment.Parent
		if not (channelParent and channelParent:IsA("BasePart")) then
			channelParent = parentPart
		end

		if not channelParent then
			return
		end

		local channelSound = sound:Clone()
		channelSound.Name = "DPVMotorLoop" .. channelName
		channelSound.Looped = true
		channelSound.Volume = 0
		channelSound.PlaybackSpeed = 0.1
		channelSound.Parent = channelParent

		self.MotorSounds[channelName] = {
			Sound = channelSound,
			Offset = offset or 0,
			State = {
				Volume = 0,
				Pitch = MOTOR_MIN_PITCH,
			},
		}
	end

	attachChannel("Left", self.Motors.LeftMotor, 0)
	attachChannel("Right", self.Motors.RightMotor, MOTOR_CHANNEL_OFFSET)
	if not next(self.MotorSounds) then
		attachChannel("Center", nil, 0)
	end

	sound:Destroy()
end

function DPVService.DoubleDPV:DestroyMotorSound()
	if self.MotorSounds then
		for _, data in pairs(self.MotorSounds) do
			local channelSound = data.Sound
			if channelSound then
				channelSound:Stop()
				channelSound:Destroy()
			end
		end
	end
	self.MotorSounds = nil
end

function DPVService.DoubleDPV:UpdateMotorSound(speedRatio, deltaTime)
	if not (self.MotorSounds and deltaTime) then
		return
	end

	local targetVolume = speedRatio <= SOUND_SPIN_THRESHOLD and 0 or math.clamp(speedRatio, 0, 1)
	local targetPitch = math.clamp(speedRatio, MOTOR_MIN_PITCH, MOTOR_MAX_PITCH)

	local alpha = 1 - math.exp(-deltaTime / SOUND_RESPONSE_TIME)
	for _, data in pairs(self.MotorSounds) do
		local channelSound = data.Sound
		if channelSound then
			data.State = data.State or {
				Volume = channelSound.Volume,
				Pitch = channelSound.PlaybackSpeed,
			}

			local state = data.State
			state.Volume += (targetVolume - state.Volume) * alpha
			state.Pitch += (targetPitch - state.Pitch) * alpha

			if state.Volume <= 0.01 and targetVolume == 0 then
				channelSound.Volume = 0
				if channelSound.IsPlaying then
					channelSound:Stop()
				end
			else
				if not channelSound.IsPlaying then
					if data.Offset and data.Offset > 0 then
						channelSound.TimePosition = math.max(data.Offset, 0)
					end
					channelSound:Play()
				end

				channelSound.Volume = math.clamp(state.Volume, 0, 1)
				channelSound.PlaybackSpeed = math.clamp(state.Pitch, MOTOR_MIN_PITCH, MOTOR_MAX_PITCH)
			end
		end
	end
end

function DPVService.DoubleDPV:Construct()
	local attributeMultiplier = self.Instance:GetAttribute("ToolSwimSpeedMultiplier")
	if typeof(attributeMultiplier) == "number" then
		self.SpeedMultiplier = math.max(attributeMultiplier, 0)
	else
		self.SpeedMultiplier = SPEED_MULTIPLIER
	end
	local configModule = self.Instance:FindFirstChild("Config")
	if configModule and configModule:IsA("ModuleScript") then
		local success, config = pcall(require, configModule)
		if success and type(config) == "table" and config.Speed then
			self.SpeedMultiplier = config.Speed
		end
	end

	self.Instance.RequiresHandle = false
	local mainPart = self.Instance:FindFirstChild("Main")
	if not mainPart then
		warn("Double DPV missing Main part", self.Instance)
	end
	self.Pivot = findPivotAttachment(mainPart)

	if self.Pivot then
		self.PivotBaseCFrame = self.Pivot.CFrame * CFrame.Angles(math.rad(-10), 0, 0)
	else
		warn("Double DPV missing Pivot attachment", self.Instance)
	end

	self.LeftHand = self.Instance:FindFirstChild("LeftHand", true) :: Attachment
	self.RightHand = self.Instance:FindFirstChild("RightHand", true) :: Attachment

	self.Motors = {
		LeftMotor = self.Instance:FindFirstChild("LeftMotor", true) :: Attachment,
		RightMotor = self.Instance:FindFirstChild("RightMotor", true) :: Attachment,
	}

	self.MotorState = {}

	for name, attachment in self.Motors do
		if attachment and attachment:IsA("Attachment") then
			self.MotorState[name] = {
				Attachment = attachment,
				BaseCFrame = attachment.CFrame,
				Speed = 0,
			}
		end
	end

	self.MotorSounds = nil
	self.Player = nil
	self.Connections = {}
	self.RemoteConnections = {}
	self.PivotConnection = nil
	self.PivotPitch = 0
	self.PivotRoll = 0
	self.PivotYaw = 0
	self.PivotTime = 0
	self.BodyWeld = nil
	self.IK = {
		LeftHand = Instance.new("IKControl"),
		RightHand = Instance.new("IKControl"),
	}

	for name, ik in pairs(self.IK) do
		ik.Name = string.format("DoubleDPV%sIK", name)
		ik.Enabled = false
		ik.Parent = nil
		ik.ChainRoot = nil
		ik.EndEffector = nil
		ik.Target = nil
	end

	local function disconnectRemotes()
		for _, connection in ipairs(self.RemoteConnections) do
			connection:Disconnect()
		end
		table.clear(self.RemoteConnections)
	end

	local function connectRemotes()
		local DoubleDPVEvent = Mince:GetEvent("DoubleDPV")
		local DPVRegisterEvent = DoubleDPVEvent and DoubleDPVEvent:Extend("Register")
		local DPVUnregisterEvent = DoubleDPVEvent and DoubleDPVEvent:Extend("Unregister")

		if not DoubleDPVEvent then
			return
		end

		if DPVRegisterEvent then
			table.insert(self.RemoteConnections, DPVRegisterEvent.Event:Connect(function(player, tool)
				if tool ~= self.Instance then
					return
				end
			end))
		end

		if DPVUnregisterEvent then
			table.insert(self.RemoteConnections, DPVUnregisterEvent.Event:Connect(function(player, tool)
				if tool ~= self.Instance then
					return
				end
			end))
		end
	end

	disconnectRemotes()
	connectRemotes()

	self._disconnectRemotes = disconnectRemotes

	local Humanoid

	local function updateMotors(deltaTime, speed)
		if not next(self.MotorState) then
			return
		end

		local targetRotationSpeed = math.clamp(speed / TARGET_SPEED, 0, 1) * PROP_TARGET_SPEED
		local speedRatio = PROP_TARGET_SPEED > 0 and math.clamp(targetRotationSpeed / PROP_TARGET_SPEED, 0, 1) or 0

		self:UpdateMotorSound(speedRatio, deltaTime)

		for name, motor in self.MotorState do
			local attachment = motor.Attachment
			if not (attachment and attachment.Parent) then
				self.MotorState[name] = nil
			else
				motor.Speed = motor.Speed + (targetRotationSpeed - motor.Speed) * 0.2
				local rotationAngle = math.rad(motor.Speed * deltaTime * 60)
				if math.abs(rotationAngle) > 1e-4 then
					attachment.CFrame = attachment.CFrame * CFrame.Angles(rotationAngle, 0, 0)
				end
			end
		end
	end

	local function updatePivot(deltaTime)
		if not Humanoid then
			return
		end

		local character = Humanoid.Parent
		if not (character and character:IsA("Model")) then
			return
		end

		local rootPart = Humanoid.RootPart or character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		local velocity = rootPart.AssemblyLinearVelocity
		local speed = velocity.Magnitude

		updateMotors(deltaTime, speed)


		if self.Pivot and self.PivotBaseCFrame and speed > 0.01 then
			local rootCFrame = rootPart.CFrame
			local localVelocity = rootCFrame:VectorToObjectSpace(velocity)

			local horizontalSpeed = math.sqrt((localVelocity.X * localVelocity.X) + (localVelocity.Z * localVelocity.Z))
			local pitchAngle = math.deg(math.atan2(localVelocity.Y, math.max(horizontalSpeed, 1e-4)))
			local targetPitch = math.clamp(pitchAngle, -MAX_PITCH_DEG, MAX_PITCH_DEG)

			local targetYaw = self.PivotYaw or 0
			if horizontalSpeed > 1e-3 then
				targetYaw = -math.deg(math.atan2(localVelocity.X, -localVelocity.Z))
			end

			local targetRoll = math.clamp(-localVelocity.X / speed * MAX_ROLL_DEG, -MAX_ROLL_DEG, MAX_ROLL_DEG)
			local speedMultiplier = math.clamp(speed / 12, 0, 1)
			speedMultiplier = speedMultiplier * speedMultiplier
			targetRoll = targetRoll * speedMultiplier
			targetPitch = targetPitch * speedMultiplier

			self.PivotTime = (self.PivotTime or 0) + deltaTime
			local swayPhase = self.PivotTime * (PIVOT_SWAY_SPEED + (speedMultiplier * 0.75))
			local swayPitch = math.sin(swayPhase) * PIVOT_SWAY_PITCH_DEG * speedMultiplier
			local swayRoll = math.cos(swayPhase * 1.15) * PIVOT_SWAY_ROLL_DEG * speedMultiplier
			targetPitch = math.clamp(targetPitch + swayPitch, -MAX_PITCH_DEG, MAX_PITCH_DEG)
			targetRoll = math.clamp(targetRoll + swayRoll, -MAX_ROLL_DEG, MAX_ROLL_DEG)

			self.PivotPitch = smoothAngle(self.PivotPitch or 0, targetPitch, PIVOT_RESPONSE_TIME, deltaTime)
			self.PivotRoll = smoothAngle(self.PivotRoll or 0, targetRoll, PIVOT_RESPONSE_TIME, deltaTime)
			self.PivotYaw = smoothAngleWrap(self.PivotYaw or 0, targetYaw, PIVOT_RESPONSE_TIME, deltaTime)

			local headingCFrame = CFrame.Angles(math.rad(self.PivotPitch), math.rad(self.PivotYaw), 0)
			local tiltCFrame = headingCFrame * CFrame.Angles(0, 0, math.rad(self.PivotRoll))
			local targetCFrame = self.PivotBaseCFrame * tiltCFrame

			self.Pivot.CFrame = targetCFrame
		elseif self.Pivot and self.PivotBaseCFrame then
			self.PivotPitch = smoothAngle(self.PivotPitch or 0, 0, PIVOT_RETURN_TIME, deltaTime)
			self.PivotRoll = smoothAngle(self.PivotRoll or 0, 0, PIVOT_RETURN_TIME, deltaTime)
			self.PivotYaw = smoothAngleWrap(self.PivotYaw or 0, 0, PIVOT_RETURN_TIME, deltaTime)
			local headingCFrame = CFrame.Angles(math.rad(self.PivotPitch), math.rad(self.PivotYaw), 0)
			local tiltCFrame = headingCFrame * CFrame.Angles(0, 0, math.rad(self.PivotRoll))
			self.Pivot.CFrame = self.PivotBaseCFrame * tiltCFrame
		end
	end

	local function resetMotors()
		for name, motor in pairs(self.MotorState) do
			motor.Speed = 0
			if motor.Attachment and motor.BaseCFrame then
				motor.Attachment.CFrame = motor.BaseCFrame
			else
				self.MotorState[name] = nil
			end
		end
	end

	local function cleanupPivot()
		if self.PivotConnection then
			self.PivotConnection:Disconnect()
			self.PivotConnection = nil
		end

		if self.Pivot and self.PivotBaseCFrame then
			self.Pivot.CFrame = self.PivotBaseCFrame
		end

		self.PivotPitch = 0
		self.PivotRoll = 0
		self.PivotYaw = 0
		self.PivotTime = 0

		resetMotors()
	end

	local function applySpeedBoost()
		self.Player = Players:GetPlayerFromCharacter(self.Instance.Parent)
		if not self.Player then
			return
		end

		local toolMultiplier = self.Instance:GetAttribute("ToolSwimSpeedMultiplier")

		SpeedBoostService:Apply(self.Player, self.Instance, toolMultiplier)
		self.Player:SetAttribute(DPV_ACTIVE_ATTRIBUTE, true)
	end

	local function onEquipped()
		local character = self.Instance.Parent
		Humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local toolAttachment, torsoAttachment = getAttachments(self.Instance)
		if not (toolAttachment and torsoAttachment) then
			warn("Double DPV missing NeckAttachment on tool or torso")
			return
		end

		if not Humanoid then
			warn("Double DPV equipped without humanoid")
			return
		end

		local player = character and Players:GetPlayerFromCharacter(character)
		if not (player and (player:GetAttribute("Swimming") or false)) then
			if player and NoticeEvent then
				NoticeEvent:Fire(player, NOT_SWIMMING_MESSAGE, Color3.new(1, 1, 1), 3)
			end
			Humanoid:UnequipTools()
			return
		end

		setIK(self.IK.LeftHand, Humanoid, "LeftUpperArm", "LeftHand", self.LeftHand)
		setIK(self.IK.RightHand, Humanoid, "RightUpperArm", "RightHand", self.RightHand)

		self:AttachMotorSound()

		if not self.PivotConnection then
			self.PivotConnection = RunService.Heartbeat:Connect(updatePivot)
		end

		if self.BodyWeld then
			self.BodyWeld:Destroy()
			self.BodyWeld = nil
		end

		self.BodyWeld = createAttachmentWeld(toolAttachment, torsoAttachment)
		if not self.BodyWeld then
			warn("Double DPV missing valid attachments for weld")
		end

		applySpeedBoost()
	end

	local function onUnequipped()
		for _, ik in self.IK do
			ik.Enabled = false
		end

		Humanoid = nil

		self:DestroyMotorSound()
		self:ResetSpeedBoost()

		if self.BodyWeld then
			self.BodyWeld:Destroy()
			self.BodyWeld = nil
		end

		cleanupPivot()
	end

	self.Connections = {
		self.Instance.Equipped:Connect(onEquipped),
		self.Instance.Unequipped:Connect(onUnequipped),
	}

	self.Instance.Destroying:Connect(function()
		cleanupPivot()
		self:ResetSpeedBoost()
		disconnectRemotes()

		if self.BodyWeld then
			self.BodyWeld:Destroy()
			self.BodyWeld = nil
		end
	end)
end

function DPVService.DoubleDPV:Removing()
	if self.Connections then
		for _, conn in pairs(self.Connections) do
			conn:Disconnect()
		end
		self.Connections = {}
	end

	if self.IK then
		for _, ik in self.IK do
			ik.Enabled = false
		end
	end

	if self.PivotConnection then
		self.PivotConnection:Disconnect()
		self.PivotConnection = nil
	end

	if self.Pivot and self.PivotBaseCFrame then
		self.Pivot.CFrame = self.PivotBaseCFrame
	end

	if self.MotorState then
		for _, motor in self.MotorState do
			if motor.Attachment and motor.BaseCFrame then
				motor.Attachment.CFrame = motor.BaseCFrame
			end
			motor.Speed = 0
		end
	end

	self:DestroyMotorSound()
	self:ResetSpeedBoost()
	if self._disconnectRemotes then
		self._disconnectRemotes()
		self._disconnectRemotes = nil
	end

	if self.BodyWeld then
		self.BodyWeld:Destroy()
		self.BodyWeld = nil
	end
end

return DPVService