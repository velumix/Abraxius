local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local masterGroup = SoundService:FindFirstChild("Master")

local Assets = ReplicatedStorage.Assets
local Modules = ReplicatedStorage.Modules

local Encyclopedia = Assets.Encyclopedia
local Npcs = Encyclopedia.Npcs
local Mince = require(Modules.Mince)
local Scheduler = Mince.Scheduler.getDefault()

local LOOK_AT_DISTANCE = 10
local LOOK_AT_UPDATE_INTERVAL = 0.05
local MAX_NECK_PITCH = math.rad(45)
local MAX_NECK_YAW = math.rad(60)
local HEAD_LERP_SPEED = 4
local WAIST_LERP_SPEED = 3
local MAX_WAIST_PITCH = math.rad(20)
local MAX_WAIST_YAW = math.rad(35)
local TORSO_PITCH_RATIO = 0.35
local TORSO_YAW_RATIO = 0.5

local function lerpAngle(current, target, speed, dt)
	dt = dt or (1 / 60)
	if speed <= 0 then
		return target
	end
	local alpha = 1 - math.exp(-speed * dt)
	return current + (target - current) * alpha
end

local function getCurrentCamera()
	return Workspace.CurrentCamera
end

local function getCameraPosition()
	local camera = getCurrentCamera()
	if not camera then
		return nil
	end

	return camera.CFrame.Position
end

local function getLocalPlayerHeadPosition()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end

	local character = player.Character
	if not character then
		return nil
	end

	local head = character:FindFirstChild("Head")
	if head then
		return head.Position
	end

	return nil
end

local function getLookTargetPosition()
	local camera = getCurrentCamera()
	if camera and camera.CameraType == Enum.CameraType.Scriptable then
		return getCameraPosition(), true
	end

	local headPosition = getLocalPlayerHeadPosition()
	if headPosition then
		return headPosition, false
	end

	return getCameraPosition(), false
end

local function getPromptBasePart(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local proxy = model:FindFirstChild("Proxy")
	if proxy then
		if proxy:IsA("BasePart") then
			return proxy
		elseif proxy:IsA("Attachment") then
			local parent = proxy.Parent
			if parent and parent:IsA("BasePart") then
				return parent
			end
		end
	end

	local primaryPart = model.PrimaryPart
	if primaryPart and primaryPart:IsA("BasePart") then
		return primaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local Npc = Mince.Component({
	Tag = "Npc",
})

local InteractIndicator = Mince:Get("InteractIndicator")
local UserInterface = Mince:Get("UserInterface")

function Npc:_setupCommonState()
	self.Root = self.Npc:FindFirstChild("HumanoidRootPart") or self.Npc.PrimaryPart
	self.NpcData = Npcs:FindFirstChild(self.Npc.Name) and require(Npcs[self.Npc.Name]) or nil

	if self.NpcData then
		self.NpcData.Model = self.Npc
	end

	self.Humanoid = self.Npc:FindFirstChildOfClass("Humanoid")
	self.AutoRotateBackup = nil
	self.RootRotationLocked = false
	self.RootBaseOrientation = nil
	self.LastKnownRootOrientation = self.Root and self.Root.CFrame.Rotation or nil
end

function Npc:_shouldSkipConversationPrompt()
	return self.Npc:GetAttribute("DisableNpcPrompt") == true or CollectionService:HasTag(self.Npc, "ShopNpc")
end

function Npc:Construct()
	self.Npc = self.Instance :: Model

	if not self.Instance:IsA("Model") then
		return warn("Npc component must be attached to a model", self.Instance)
	end

	self.Connections = {}
	self:_setupCommonState()

	if self:_shouldSkipConversationPrompt() then
		self:SetupHeadTracking()
		return
	end

	self.PromptPart = getPromptBasePart(self.Npc)
	if not self.PromptPart then
		return warn("Npc requires a BasePart to attach prompts", self.Npc)
	end

	self.InteractIndicator = InteractIndicator.new(self.PromptPart)
	self.Prompt = self.InteractIndicator.ProximityPrompt
	self.Prompt.ObjectText = "Talk"
	self.Prompt.RequiresLineOfSight = true
	self.Prompt.Enabled = true
	self.PromptStyle = self.Prompt:GetAttribute("Type")
	self:_updatePromptAvailability()

	local canConverseConnection = self.Npc:GetAttributeChangedSignal("CanConverse"):Connect(function()
		self:_updatePromptAvailability()
	end)
	table.insert(self.Connections, canConverseConnection)

	if not self.NpcData then
		return warn("Npc data not found for", self.Npc.Name)
	end

	self.NpcSounds = {}

	local npcSoundFolder = Instance.new("Folder")
	npcSoundFolder.Name = self.Npc.Name
	npcSoundFolder.Parent = SoundService

	for I, Subject in self.NpcData.Interaction["Talk"] do
		if type(Subject) == "table" then
			for Index, Interaction in Subject do
				if type(Interaction) == "table" and Interaction[3] then
					local SoundID = Interaction[3]
					self.NpcSounds[Index] = Instance.new("Sound")
					self.NpcSounds[Index].Parent = npcSoundFolder
					self.NpcSounds[Index].SoundId = "rbxassetid://" .. tostring(SoundID)
					self.NpcSounds[Index].Volume = 1
					self.NpcSounds[Index].Playing = false
					self.NpcSounds[Index].Name = tostring(I) .. tostring(I)

					if masterGroup then
						local sfxGroup = masterGroup:FindFirstChild("SFX")
						if sfxGroup and sfxGroup:IsA("SoundGroup") then
							self.NpcSounds[Index].SoundGroup = sfxGroup
						end
					end
				end
			end
		end
	end

	self.Prompt.Triggered:Connect(function(player)
		if Players.LocalPlayer ~= player then
			return
		end
		UserInterface:NpcInteraction(self.Npc, self.Prompt, 1)
	end)

	self:SetupHeadTracking()
end

function Npc:SetupHeadTracking()
	local head = self.Npc:FindFirstChild("Head")
	if not head then
		return
	end

	local neck = head:FindFirstChild("Neck")
	if not neck or not neck:IsA("Motor6D") then
		return
	end

	self.Neck = neck

	local upperTorso = self.Npc:FindFirstChild("UpperTorso")
	local waistJoint = upperTorso and upperTorso:FindFirstChild("Waist")
	if waistJoint and waistJoint:IsA("Motor6D") then
		self.Waist = waistJoint
		self.OriginalWaistC0 = waistJoint.C0
	else
		self.Waist = nil
		self.OriginalWaistC0 = nil
	end

	self.OriginalNeckC0 = neck.C0
	self.CurrentPitch = 0
	self.CurrentYaw = 0
	self.TargetPitch = 0
	self.TargetYaw = 0
	self.CurrentWaistPitch = 0
	self.CurrentWaistYaw = 0
	self.TargetWaistPitch = 0
	self.TargetWaistYaw = 0
	self.LastLookUpdate = 0
	self.TrackingConnection = nil
	self.IsTracking = false

	self.RangeCheckTask = Scheduler:every(0.2, function()
		self:CheckTrackingRange()
	end, Mince.TaskScheduler.Priority.NORMAL, `NpcRange_{self.Npc.Name}`, true)
end

function Npc:SetRootLock(isLocked)
	local currentOrientation = self.Root and self.Root.CFrame and self.Root.CFrame.Rotation or nil

	if isLocked then
		if self.RootRotationLocked then
			return
		end
		self.RootRotationLocked = true
		self.RootBaseOrientation = self.LastKnownRootOrientation or currentOrientation
		if self.RootBaseOrientation and self.Root then
			self.Root.CFrame = CFrame.new(self.Root.Position) * self.RootBaseOrientation
		end
		if self.Humanoid then
			self.AutoRotateBackup = self.Humanoid.AutoRotate
			self.Humanoid.AutoRotate = false
		end
	else
		if currentOrientation then
			self.LastKnownRootOrientation = currentOrientation
		end
		if not self.RootRotationLocked then
			return
		end
		self.RootRotationLocked = false
		self.RootBaseOrientation = nil
		if self.Humanoid and self.AutoRotateBackup ~= nil then
			self.Humanoid.AutoRotate = self.AutoRotateBackup
		end
		self.AutoRotateBackup = nil
	end
end

function Npc:CheckTrackingRange()
	local head = self.Npc:FindFirstChild("Head")
	if not head then
		return
	end

	local targetPosition, isScriptableCamera = getLookTargetPosition()
	self:SetRootLock(isScriptableCamera and targetPosition ~= nil)
	if not targetPosition then
		self:StopTracking()
		return
	end

	local distance = (targetPosition - head.Position).Magnitude

	if distance <= LOOK_AT_DISTANCE then
		if not self.IsTracking then
			self:StartTracking()
		end
	else
		if self.IsTracking then
			self:StopTracking()
		end
	end
end

function Npc:StartTracking()
	if self.IsTracking then
		return
	end
	self.IsTracking = true
	if self.TrackingConnection then
		return
	end

	self.TrackingConnection = RunService.Heartbeat:Connect(function(delta)
		self:UpdateHeadTracking(delta)
	end)
end

function Npc:StopTracking()
	if not self.IsTracking then
		return
	end
	self.IsTracking = false

	self.TargetPitch = 0
	self.TargetYaw = 0
	self.TargetWaistPitch = 0
	self.TargetWaistYaw = 0
	self:SetRootLock(false)
end

function Npc:UpdateHeadTracking(delta)
	local head = self.Npc:FindFirstChild("Head")
	if not head then
		return
	end

	local neck = self.Neck
	if not neck or neck.Parent ~= head then
		neck = head:FindFirstChild("Neck")
		if not neck or not neck:IsA("Motor6D") then
			return
		end
		self.Neck = neck
		self.OriginalNeckC0 = self.OriginalNeckC0 or neck.C0
	end

	local waist = self.Waist
	if waist and not waist.Parent then
		waist = nil
		self.Waist = nil
		self.OriginalWaistC0 = nil
	end

	if not waist then
		local upperTorso = self.Npc:FindFirstChild("UpperTorso")
		local waistJoint = upperTorso and upperTorso:FindFirstChild("Waist")
		if waistJoint and waistJoint:IsA("Motor6D") then
			waist = waistJoint
			self.Waist = waistJoint
			self.OriginalWaistC0 = self.OriginalWaistC0 or waistJoint.C0
		end
	end

	local now = os.clock()

	if self.IsTracking and (now - self.LastLookUpdate) >= LOOK_AT_UPDATE_INTERVAL then
		self.LastLookUpdate = now

		local targetPosition, isScriptableCamera = getLookTargetPosition()
		self:SetRootLock(isScriptableCamera and targetPosition ~= nil)

		if self.RootRotationLocked and self.RootBaseOrientation then
			self.Root.CFrame = CFrame.new(self.Root.Position) * self.RootBaseOrientation
		end

		if not targetPosition then
			self.TargetPitch = 0
			self.TargetYaw = 0
			self.TargetWaistPitch = 0
			self.TargetWaistYaw = 0
		else
			local neckWorldCFrame = (self.Root.CFrame * self.OriginalNeckC0)
			local toTarget = (targetPosition - neckWorldCFrame.Position).Unit
			local objectSpaceTarget = neckWorldCFrame:VectorToObjectSpace(toTarget)

			local rawYaw = math.atan2(-objectSpaceTarget.X, -objectSpaceTarget.Z)
			local rawPitch = math.asin(objectSpaceTarget.Y)

			local waistTargetPitch = 0
			local waistTargetYaw = 0
			if waist and self.OriginalWaistC0 then
				waistTargetPitch = math.clamp(rawPitch * TORSO_PITCH_RATIO, -MAX_WAIST_PITCH, MAX_WAIST_PITCH)
				waistTargetYaw = math.clamp(rawYaw * TORSO_YAW_RATIO, -MAX_WAIST_YAW, MAX_WAIST_YAW)
			end

			local neckTargetPitch = math.clamp(rawPitch - waistTargetPitch, -MAX_NECK_PITCH, MAX_NECK_PITCH)
			local neckTargetYaw = math.clamp(rawYaw - waistTargetYaw, -MAX_NECK_YAW, MAX_NECK_YAW)

			self.TargetPitch = neckTargetPitch
			self.TargetYaw = neckTargetYaw
			self.TargetWaistPitch = waist and waistTargetPitch or 0
			self.TargetWaistYaw = waist and waistTargetYaw or 0
		end
	end

	self.CurrentPitch = lerpAngle(self.CurrentPitch, self.TargetPitch, HEAD_LERP_SPEED, delta)
	self.CurrentYaw = lerpAngle(self.CurrentYaw, self.TargetYaw, HEAD_LERP_SPEED, delta)

	if waist and self.OriginalWaistC0 then
		self.CurrentWaistPitch = lerpAngle(self.CurrentWaistPitch, self.TargetWaistPitch, WAIST_LERP_SPEED, delta)
		self.CurrentWaistYaw = lerpAngle(self.CurrentWaistYaw, self.TargetWaistYaw, WAIST_LERP_SPEED, delta)
	else
		self.CurrentWaistPitch = 0
		self.CurrentWaistYaw = 0
		self.TargetWaistPitch = 0
		self.TargetWaistYaw = 0
	end

	local threshold = 0.01
	local atRest = math.abs(self.CurrentPitch) < threshold and math.abs(self.CurrentYaw) < threshold
	if waist and self.OriginalWaistC0 then
		atRest = atRest and math.abs(self.CurrentWaistPitch) < threshold and math.abs(self.CurrentWaistYaw) < threshold
	end

	if atRest and not self.IsTracking then
		if self.TrackingConnection then
			self.TrackingConnection:Disconnect()
			self.TrackingConnection = nil
		end
		neck.C0 = self.OriginalNeckC0
		if waist and self.OriginalWaistC0 then
			waist.C0 = self.OriginalWaistC0
		end
		return
	end

	local neckPitch = math.clamp(self.CurrentPitch, -MAX_NECK_PITCH, MAX_NECK_PITCH)
	local neckYaw = math.clamp(self.CurrentYaw, -MAX_NECK_YAW, MAX_NECK_YAW)
	neck.C0 = self.OriginalNeckC0 * CFrame.Angles(neckPitch, neckYaw, 0)

	if waist and self.OriginalWaistC0 then
		local waistPitch = math.clamp(self.CurrentWaistPitch, -MAX_WAIST_PITCH, MAX_WAIST_PITCH)
		local waistYaw = math.clamp(self.CurrentWaistYaw, -MAX_WAIST_YAW, MAX_WAIST_YAW)
		waist.C0 = self.OriginalWaistC0 * CFrame.Angles(waistPitch, waistYaw, 0)
	end
end

function Npc:Destruct()
	if self.InteractIndicator and self.InteractIndicator.Stop then
		self.InteractIndicator:Stop(true)
	end
	self.InteractIndicator = nil
	self.PromptPart = nil
	if self.RangeCheckTask then
		Scheduler:cancel(self.RangeCheckTask)
		self.RangeCheckTask = nil
	end

	if self.TrackingConnection then
		self.TrackingConnection:Disconnect()
		self.TrackingConnection = nil
	end

	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}

	local head = self.Npc:FindFirstChild("Head")
	if head then
		local neck = head:FindFirstChild("Neck")
		if neck and self.OriginalNeckC0 then
			neck.C0 = self.OriginalNeckC0
		end
	end

	if self.Waist and self.OriginalWaistC0 then
		self.Waist.C0 = self.OriginalWaistC0
	end

	self:SetRootLock(false)
	self.Neck = nil
	self.Waist = nil
	self.RootBaseOrientation = nil
	self.AutoRotateBackup = nil
	self.LastKnownRootOrientation = nil
end

function Npc:_updatePromptAvailability()
	if not self.Prompt or not self.Npc then
		return
	end

	self.Prompt.Enabled = true
end

return Npc
