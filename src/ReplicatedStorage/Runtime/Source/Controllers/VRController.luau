local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Mince = require(Modules:WaitForChild("Mince"))

local VRController = {
	Name = "VRController",

	Player = nil,
	Character = nil,
	Humanoid = nil,

	IsVREnabled = false,
	MoveInput = Vector3.zero,
	LastWorldMove = Vector3.zero,

	HeadCFrame = CFrame.new(),
	LeftHandCFrame = nil,
	RightHandCFrame = nil,

	Remote = nil,
	PoseRemote = nil,
	MoveRemote = nil,

	Connections = {},

	_poseAccumulator = 0,
	_poseInterval = 1 / 30,
}

local THUMBSTICK_DEADZONE = 0.18

local function planar(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function clampMagnitude(v, max)
	if v.Magnitude > max then
		return v.Unit * max
	end
	return v
end

function VRController:IsActive()
	return self.IsVREnabled and self.Humanoid ~= nil
end

function VRController:GetMoveVector()
	return self.LastWorldMove
end

function VRController:GetPose()
	return {
		head = self.HeadCFrame,
		leftHand = self.LeftHandCFrame,
		rightHand = self.RightHandCFrame,
	}
end

function VRController:Setup()
	self.Player = Players.LocalPlayer

	self.Remote = Mince:GetEvent("VRRig")
	self.PoseRemote = self.Remote and self.Remote:Extend("Pose")
	self.MoveRemote = self.Remote and self.Remote:Extend("Move")
end

function VRController:GameStart()
	self.IsVREnabled = VRService.VREnabled or UserInputService.VREnabled
	if self.Player then
		self.Player:SetAttribute("VRActive", self.IsVREnabled)
	end

	self:ConnectCharacter()
	self:ConnectInput()
	self:ConnectHeartbeat()
end

function VRController:ConnectCharacter()
	local function onCharacterAdded(character)
		self.Character = character
		self.Humanoid = character:WaitForChild("Humanoid", 5)
	end

	local function onCharacterRemoving()
		self.Character = nil
		self.Humanoid = nil
	end

	if self.Player.Character then
		onCharacterAdded(self.Player.Character)
	end

	self.Connections.CharacterAdded = self.Player.CharacterAdded:Connect(onCharacterAdded)
	self.Connections.CharacterRemoving = self.Player.CharacterRemoving:Connect(onCharacterRemoving)
end

function VRController:ConnectInput()
	self.Connections.InputChanged = UserInputService.InputChanged:Connect(function(input)
		if not self:IsActive() then
			return
		end

		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local raw = input.Position
			if raw.Magnitude > THUMBSTICK_DEADZONE then
				self.MoveInput = Vector3.new(raw.X, 0, raw.Y)
			else
				self.MoveInput = Vector3.zero
			end
		end
	end)

	self.Connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			self.MoveInput = Vector3.zero
		end
	end)

	self.Connections.CFrameChanged = VRService.UserCFrameChanged:Connect(function()
		self:QueuePose()
	end)
end

function VRController:ConnectHeartbeat()
	self.Connections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not self:IsActive() then
			return
		end

		self:ApplyMovement(dt)
		self:StepPose(dt)
	end)
end

function VRController:ComputeWorldMove()
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end

	local forward = planar(camera.CFrame.LookVector)
	local right = planar(camera.CFrame.RightVector)

	local move = self.MoveInput
	if move.Magnitude < THUMBSTICK_DEADZONE then
		return Vector3.zero
	end

	local world = right * move.X + forward * move.Z
	if world.Magnitude < 1e-3 then
		return Vector3.zero
	end

	return clampMagnitude(world, 1)
end

function VRController:ApplyMovement()
	local humanoid = self.Humanoid
	if not humanoid then
		return
	end

	local worldMove = self:ComputeWorldMove()
	self.LastWorldMove = worldMove

	if worldMove.Magnitude > 0 then
		humanoid:Move(worldMove, true)
	end

	if self.MoveRemote then
		self.MoveRemote:Fire(worldMove, os.clock())
	end
end

function VRController:QueuePose()
	self._poseAccumulator = self._poseInterval
end

function VRController:StepPose(dt)
	self._poseAccumulator -= dt
	if self._poseAccumulator > 0 then
		return
	end

	self._poseAccumulator = 0
	self:SendPose()
end

function VRController:SendPose()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local origin = camera.CFrame
	local head = origin * VRService:GetUserCFrame(Enum.UserCFrame.Head)
	local left = origin * VRService:GetUserCFrame(Enum.UserCFrame.LeftHand)
	local right = origin * VRService:GetUserCFrame(Enum.UserCFrame.RightHand)

	self.HeadCFrame = head
	self.LeftHandCFrame = left
	self.RightHandCFrame = right

	if self.PoseRemote then
		self.PoseRemote:Fire({
			head = head,
			leftHand = left,
			rightHand = right,
			camera = origin,
			timestamp = os.clock(),
		})
	end
end

return VRController
