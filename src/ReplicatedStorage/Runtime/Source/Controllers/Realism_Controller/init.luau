local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local RealismPackets = require(Modules.RealismPackets)
local Util = require(script.Util)
local Config = require(script.Config)
local SoundConfig = require(ReplicatedStorage.Runtime.Config.Shared.Sounds)
local TaskScheduler = Mince.TaskScheduler

local XZ_VECTOR3 = Vector3.new(1, 0, 1)

local MAX_DISTANCE_FOR_ROTATION = 30
local CAMERA_FIRST_PERSON_THRESHOLD = 1
local PAN_DIVISOR = 5
local RATE_MULTIPLIER = 20 / 3
local ARM_TOOL_PITCH_MULTIPLIER = 1.3
local ARM_TOOL_YAW_MULTIPLIER_RIGHT = 1.3
local ARM_TOOL_YAW_MULTIPLIER_LEFT = 0.8
local RUNNING_SPEED_OFFSET = 4
local RUNNING_SPEED_DIVISOR = 12
local RUNNING_PITCH_DIVISOR = 24
local RUNNING_MIN_PLAYBACK_SPEED = 0.65
local RUNNING_MAX_PLAYBACK_SPEED = 1.15
local R6_HIP_HEIGHT = 2.8
local DEFAULT_HIP_HEIGHT_SCALE = 3
local SOUND_EMITTER_SIZE = 1
local SOUND_MAX_DISTANCE = 50
local SOUND_UPDATE_INTERVAL = 1 / 15
local MAX_DESCENDANT_PROCESS_TIME = 0.002
local MAX_DESCENDANTS_PER_STEP = 200
local NETWORK_SEND_INTERVAL = 1 / 20
local NETWORK_CHANGE_EPSILON = 0.002
local NETWORK_KEEPALIVE_INTERVAL = 0.5

local CharacterRealism = {
	Name = "Realism_Controller",
	Rotators = {},
	MaterialSounds = {},
	BindTag = "RealismHook",
	Player = Players.LocalPlayer,
}

function CharacterRealism:Connect(funcName, event)
	return event:Connect(function(...)
		self[funcName](self, ...)
	end)
end

function CharacterRealism:_ProcessDescendantsAsync(root, handler)
	if not (root and handler) then
		return
	end

	local queue = root:GetDescendants()
	local function step()
		local startTime = os.clock()
		local processed = 0
		while processed < MAX_DESCENDANTS_PER_STEP and #queue > 0 do
			local desc = queue[#queue]
			queue[#queue] = nil
			handler(desc)
			processed += 1
			if os.clock() - startTime >= MAX_DESCENDANT_PROCESS_TIME then
				break
			end
		end

		if #queue > 0 then
			task.defer(step)
		end
	end

	step()
end

function CharacterRealism:AddMotor(rotator, motor)
	local function register(part1)
		if not part1 then
			return
		end

		if part1.Name == "Head" then
			part1.CanCollide = false
		end

		local name = part1.Name
		local data = rotator.Motors[name]

		if not data then
			data = {
				Motors = {},
			}
			rotator.Motors[name] = data
		end

		for _, existing in ipairs(data.Motors) do
			if existing == motor then
				return
			end
		end

		table.insert(data.Motors, motor)

		-- Prefer AnimationConstraints over legacy Motor6Ds.
		if not data.Motor or (data.Motor:IsA("Motor6D") and motor:IsA("AnimationConstraint")) then
			data.Motor = motor
		end
	end

	if motor:IsA("Motor6D") then
		Util:PromiseValue(motor, "Active", function()
			register(motor.Part1)
		end)
	elseif motor:IsA("AnimationConstraint") then
		Util:PromiseValue(motor, "Active", function()
			local attachment = motor.Attachment1
			register(attachment and attachment.Parent)
		end)
	end
end

function CharacterRealism:IsInFirstPerson()
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType.Name == "Scriptable" then
		return false
	end

	local focus = camera.Focus.Position
	local origin = camera.CFrame.Position
	return (focus - origin).Magnitude <= CAMERA_FIRST_PERSON_THRESHOLD
end

function CharacterRealism:ComputeLookAngle(lookVector, useDir)
	local inFirstPerson = self:IsInFirstPerson()
	local pitch, yaw, dir = 0, 0, 1

	if not lookVector then
		local camera = workspace.CurrentCamera
		lookVector = camera.CFrame.LookVector
	end

	if lookVector then
		local character = self.Player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if rootPart and rootPart:IsA("BasePart") then
			local cf = rootPart.CFrame
			pitch = -cf.RightVector:Dot(lookVector)

			if not inFirstPerson then
				dir = math.clamp(cf.LookVector:Dot(lookVector) * 10, -1, 1)
			end
		end

		yaw = lookVector.Y
	end

	if useDir then
		dir = useDir
	end

	pitch *= dir
	yaw *= dir

	return pitch, yaw
end

function CharacterRealism:StepValue(state, delta)
	local current = state.Current or 0
	local goal = state.Goal

	local pan = PAN_DIVISOR / (delta * 60)
	local rate = math.min(1, (delta * RATE_MULTIPLIER))

	local step = math.min(rate, math.abs(goal - current) / pan)
	state.Current = Util:StepTowards(current, goal, step)

	return state.Current
end

function CharacterRealism:SendLookPose(pitch, yaw, force)
	local now = os.clock()
	local lastPitch = self.LastNetworkPitch
	local lastYaw = self.LastNetworkYaw
	local changed = lastPitch == nil
		or math.abs(pitch - lastPitch) >= NETWORK_CHANGE_EPSILON
		or math.abs(yaw - lastYaw) >= NETWORK_CHANGE_EPSILON
	local keepalive = not self.LastNetworkSend or now - self.LastNetworkSend >= NETWORK_KEEPALIVE_INTERVAL

	if not force and (self.NetworkAccumulator or 0) < NETWORK_SEND_INTERVAL then
		return
	end
	if not force and not changed and not keepalive then
		return
	end

	self.NetworkAccumulator = 0
	self.LastNetworkPitch = pitch
	self.LastNetworkYaw = yaw
	self.LastNetworkSend = now
	RealismPackets.LookInput.send({
		pitch = pitch,
		yaw = yaw,
	})
end

function CharacterRealism:OnNetworkLook(data)
	if typeof(data) ~= "table" then
		return
	end

	local player = data.player
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player == self.Player then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not self:ShouldUpdateRotator(character, player) then
		return
	end

	local rotator = self.Rotators[character] or self:MountLookAngle(humanoid)
	if rotator then
		rotator.Pitch.Goal = math.clamp(data.pitch, -1, 1)
		rotator.Yaw.Goal = math.clamp(data.yaw, -1, 1)
	end
end

function CharacterRealism:UpdateLookAngles(delta)
	if self.HeadMovementEnabled == false then
		return
	end
	if UserInputService.VREnabled then
		return
	end

	self.Rotators = self.Rotators or {}

	local pitch, yaw = self:ComputeLookAngle()
	self.NetworkAccumulator = (self.NetworkAccumulator or 0) + delta
	self:SendLookPose(pitch, yaw, false)

	local character = self.Player.Character
	local rotator = character and self.Rotators[character]
	if rotator then
		rotator.Pitch.Goal = pitch
		rotator.Yaw.Goal = yaw
	end

	self:UpdateRotators(delta)
end

function CharacterRealism:ResetHeadOrientation()
	for _, rotator in pairs(self.Rotators) do
		if rotator and rotator.Motors then
			local data = rotator.Motors["Head"]
			if data then
				data.TargetRotations = nil
				data.LastPitch = nil
				data.LastYaw = nil
			end
			if rotator.Pitch then
				rotator.Pitch.Goal = 0
				rotator.Pitch.Current = 0
				rotator.Pitch.Value = 0
			end
			if rotator.Yaw then
				rotator.Yaw.Goal = 0
				rotator.Yaw.Current = 0
				rotator.Yaw.Value = 0
			end
		end
	end

	self:SendLookPose(0, 0, true)
end

function CharacterRealism:ShouldUpdateRotator(character, owner)
	if not character.Parent then
		return false
	end

	if owner == self.Player then
		return true
	end

	local camera = workspace.CurrentCamera
	local camPos = camera.CFrame.Position
	local dist = owner and owner:DistanceFromCharacter(camPos) or math.huge

	return dist <= MAX_DISTANCE_FOR_ROTATION
end

function CharacterRealism:CleanupRotator(character)
	local rotator = self.Rotators[character]
	if rotator and rotator.Listener then
		rotator.Listener:Disconnect()
	end
	self.Rotators[character] = nil
end

function CharacterRealism:UpdateRotators(delta)
	self.Rotators = self.Rotators or {}

	local charactersToCleanup = {}
	local stepDelta = math.min(delta or 0, 1 / 30)
	local scheduler = self.MotorScheduler
	if not scheduler and TaskScheduler then
		scheduler = TaskScheduler.new({
			maxTasksPerFrame = 10,
			enableRateLimit = false,
		})
		self.MotorScheduler = scheduler
	end

	for character, rotator in pairs(self.Rotators) do
		local owner = Players:GetPlayerFromCharacter(character)

		if not self:ShouldUpdateRotator(character, owner) then
			table.insert(charactersToCleanup, character)
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = humanoid and humanoid.RootPart
		if not rootPart then
			continue
		end

		self:StepValue(rotator.Pitch, stepDelta)
		self:StepValue(rotator.Yaw, stepDelta)

		if not rotator.Motors then
			rotator.Motors = {}
		end
		if not rotator.Motors["Head"] then
			local head = character:FindFirstChild("Head")
			if head then
				local neck
				for _, child in ipairs(head:GetChildren()) do
					if child:IsA("AnimationConstraint") and child.Enabled then
						neck = child
						break
					elseif child:IsA("Motor6D") and child.Enabled and not neck then
						neck = child
					end
				end
				if not neck then
					neck = head:FindFirstChild("Neck")
						or head:FindFirstChildOfClass("AnimationConstraint")
						or head:FindFirstChildOfClass("Motor6D")
				end
				if neck then
					self:AddMotor(rotator, neck)
				end
			end
		end

		if rotator.Motors then
			local function updateMotor()
				self:UpdateMotors(character, rotator)
			end
			if owner == self.Player or not scheduler then
				updateMotor()
			else
				scheduler:enqueue(updateMotor, TaskScheduler.Priority.NORMAL, "MotorUpdate_" .. character.Name)
			end
		end
	end

	if scheduler and scheduler:getQueueSize() > 0 then
		scheduler:process()
	end

	for _, character in ipairs(charactersToCleanup) do
		self:CleanupRotator(character)
	end
end

function CharacterRealism:CalculateArmFactors(name, character, rootPart, factors)
	local isArm = name:sub(-4) == " Arm" or name:sub(-8) == "UpperArm"
	if not isArm then
		return factors.Pitch, factors.Yaw
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or CollectionService:HasTag(tool, "NoArmRotation") then
		return factors.Pitch, factors.Yaw
	end

	if name:sub(1, 5) == "Right" and rootPart:GetRootPart() ~= rootPart then
		return ARM_TOOL_PITCH_MULTIPLIER, ARM_TOOL_YAW_MULTIPLIER_RIGHT
	else
		return factors.Pitch, ARM_TOOL_YAW_MULTIPLIER_LEFT
	end
end

function CharacterRealism:ApplyAnimationConstraintTransforms()
	for _, rotator in pairs(self.Rotators) do
		if not rotator.Motors then
			continue
		end
		for _, data in pairs(rotator.Motors) do
			if not data.TargetRotations then
				continue
			end
			for _, motor in ipairs(data.Motors) do
				if not motor.Enabled then
					continue
				end
				local rotation = data.TargetRotations[motor]
				if rotation then
					motor.Transform = motor.Transform * rotation
				end
			end
		end
	end
end

function CharacterRealism:UpdateMotors(character, rotator)
	local pitchState = rotator.Pitch
	local yawState = rotator.Yaw
	local motors = rotator.Motors
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart

	if not rootPart then
		return
	end

	for name, factors in pairs(self.RotationFactors) do
		local data = motors[name]
		if not data or not data.Motors then
			continue
		end

		local pitch = pitchState.Current or 0
		local yaw = yawState.Current or 0

		if self.HeadMovementEnabled == false and name == "Head" then
			pitch = 0
			yaw = 0
			pitchState.Current = 0
			yawState.Current = 0
			pitchState.Goal = 0
			yawState.Goal = 0
		end

		if rotator.SnapFirstPerson and name == "Head" and self:IsInFirstPerson() then
			pitch = pitchState.Goal
			yaw = yawState.Goal
		end

		local fPitch, fYaw = self:CalculateArmFactors(name, character, rootPart, factors)
		fPitch = pitch * (fPitch or factors.Pitch)
		fYaw = yaw * (fYaw or factors.Yaw)

		if fPitch ~= data.LastPitch or fYaw ~= data.LastYaw then
			data.LastPitch = fPitch
			data.LastYaw = fYaw

			data.TargetRotations = {}

			local rotation = CFrame.Angles(0, fPitch, 0) * CFrame.Angles(fYaw, 0, 0)

			for _, motor in ipairs(data.Motors) do
				data.TargetRotations[motor] = rotation
			end
		end
	end
end

function CharacterRealism:MountLookAngle(humanoid)
	local character = humanoid.Parent
	local rotator = character and self.Rotators[character]

	if not rotator then
		rotator = {
			Motors = {},
			Pitch = {
				Goal = 0,
				Current = 0,
			},

			Yaw = {
				Goal = 0,
				Current = 0,
			},
		}

		local player = Players:GetPlayerFromCharacter(character)

		if player == self.Player then
			rotator.SnapFirstPerson = true
		end

		self.Rotators = self.Rotators or {}
		self.Rotators[character] = rotator

		local function onDescendantAdded(desc)
			task.defer(function()
				if desc:IsA("Motor6D") or desc:IsA("AnimationConstraint") then
					self:AddMotor(rotator, desc)
				end
			end)
		end

		self:_ProcessDescendantsAsync(character, onDescendantAdded)

		rotator.Listener = character.DescendantAdded:Connect(onDescendantAdded)
	end
	return rotator
end

function CharacterRealism:RemoveMaterialSound(humanoid)
	local entry = self.MaterialSounds[humanoid]
	if not entry then
		return
	end

	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	self.MaterialSounds[humanoid] = nil
end

function CharacterRealism:UpdateMaterialSoundId(entry)
	local material = entry.Humanoid.FloorMaterial.Name
	local sounds = SoundConfig.Ids.Footsteps
	local soundId = sounds[material]
	if not soundId then
		soundId = sounds[self.MaterialMap[material]] or sounds.Concrete
	end
	entry.Sound.SoundId = soundId
end

function CharacterRealism:ShouldMuteMaterialSound(entry)
	local humanoid = entry.Humanoid
	local owner = entry.Owner
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		return true
	end
	if owner and owner:GetAttribute("Swimming") == true then
		return true
	end
	if not owner or not owner:GetAttribute("ShowGearInObservatory") then
		return false
	end

	for _, child in entry.Character:GetChildren() do
		if CollectionService:HasTag(child, "Tail") then
			return true
		end
	end
	return false
end

function CharacterRealism:UpdateMaterialSounds(delta)
	self.SoundAccumulator = (self.SoundAccumulator or 0) + delta
	if self.SoundAccumulator < SOUND_UPDATE_INTERVAL then
		return
	end
	self.SoundAccumulator %= SOUND_UPDATE_INTERVAL

	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position
	local stale = {}

	for humanoid, entry in self.MaterialSounds do
		local rootPart = entry.RootPart
		local running = entry.Sound
		if not humanoid.Parent or not rootPart.Parent or not running.Parent then
			table.insert(stale, humanoid)
			continue
		end

		local distance = if cameraPosition then (rootPart.Position - cameraPosition).Magnitude else math.huge
		local isLocal = entry.Owner == self.Player
		local stateName = humanoid:GetState().Name
		if
			not stateName:find("Running")
			or (not isLocal and distance > SOUND_MAX_DISTANCE)
			or self:ShouldMuteMaterialSound(entry)
		then
			running.Volume = 0
			running.Pitch = entry.BasePitch
			continue
		end

		local hipHeight = if humanoid.RigType.Name == "R6" then R6_HIP_HEIGHT else humanoid.HipHeight
		local scale = math.max(hipHeight / DEFAULT_HIP_HEIGHT_SCALE, 0.01)
		local speed = (rootPart.AssemblyLinearVelocity * XZ_VECTOR3).Magnitude
		running.Volume = math.clamp(((speed - RUNNING_SPEED_OFFSET) / RUNNING_SPEED_DIVISOR) * scale, 0, 1)
		local playbackRatio = if speed > 0.01 then speed / (scale * RUNNING_PITCH_DIVISOR) else 1
		running.Pitch = entry.BasePitch
			* math.clamp(playbackRatio, RUNNING_MIN_PLAYBACK_SPEED, RUNNING_MAX_PLAYBACK_SPEED)
	end

	for _, humanoid in stale do
		self:RemoveMaterialSound(humanoid)
	end
end

function CharacterRealism:MountMaterialSounds(humanoid)
	if self.MaterialSounds[humanoid] then
		return
	end

	local character = humanoid.Parent
	local rootPart = character and character:WaitForChild("HumanoidRootPart", 10)

	if not (rootPart and rootPart:IsA("BasePart")) then
		return
	end

	Util:PromiseChild(rootPart, "Running", function(running)
		if not running:IsA("Sound") or self.MaterialSounds[humanoid] then
			return
		end

		local oldPitch = running:FindFirstChild("OldPitch")
		local entry = {
			Humanoid = humanoid,
			Character = character,
			RootPart = rootPart,
			Sound = running,
			Owner = Players:GetPlayerFromCharacter(character),
			BasePitch = if oldPitch and oldPitch:IsA("NumberValue") then oldPitch.Value else running.Pitch,
			Connections = {},
		}
		self.MaterialSounds[humanoid] = entry

		running.EmitterSize = SOUND_EMITTER_SIZE
		running.MaxDistance = SOUND_MAX_DISTANCE

		self:UpdateMaterialSoundId(entry)
		table.insert(
			entry.Connections,
			humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
				self:UpdateMaterialSoundId(entry)
			end)
		)
		table.insert(
			entry.Connections,
			humanoid.AncestryChanged:Connect(function(_, parent)
				if not parent then
					self:RemoveMaterialSound(humanoid)
				end
			end)
		)
	end)
end

function CharacterRealism:OnHumanoidAdded(humanoid)
	if not humanoid:IsA("Humanoid") then
		return
	end

	local character = humanoid.Parent
	local owner = character and Players:GetPlayerFromCharacter(character)

	if owner == self.Player and UserInputService.VREnabled then
		self:CleanupRotator(character)
		return
	end

	if not self.SkipLookAngle then
		self:MountLookAngle(humanoid)
	end

	if not self.SkipMaterialSounds then
		self:MountMaterialSounds(humanoid)
	end
end

function CharacterRealism:Setup() end

function CharacterRealism:GameStart()
	assert(not _G.DefineRealismClient, "Realism can only be started once on the client!")
	_G.DefineRealismClient = true

	self.Rotators = self.Rotators or {}

	for key, value in pairs(Config) do
		self[key] = value
	end

	RealismPackets.LookBroadcast.listen(function(data)
		self:OnNetworkLook(data)
	end)

	local player = self.Player

	local function applyHeadSetting()
		local value = player:GetAttribute("HeadMovementEnabled")
		if value ~= nil then
			self.HeadMovementEnabled = value == true
			if self.HeadMovementEnabled == false then
				self:ResetHeadOrientation()
			end
		end
	end

	applyHeadSetting()
	player:GetAttributeChangedSignal("HeadMovementEnabled"):Connect(applyHeadSetting)

	local function setupCharacter(character)
		if character then
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				self:OnHumanoidAdded(humanoid)
			end
		end
	end

	if player.Character then
		setupCharacter(player.Character)
	end

	player.CharacterAdded:Connect(setupCharacter)

	for _, humanoid in CollectionService:GetTagged(self.BindTag) do
		self:OnHumanoidAdded(humanoid)
	end

	self:Connect("UpdateLookAngles", RunService.PreRender)
	self:Connect("ApplyAnimationConstraintTransforms", RunService.PreSimulation)
	self:Connect("UpdateMaterialSounds", RunService.Heartbeat)
	self:Connect("OnHumanoidAdded", CollectionService:GetInstanceAddedSignal(self.BindTag))
end

return CharacterRealism
