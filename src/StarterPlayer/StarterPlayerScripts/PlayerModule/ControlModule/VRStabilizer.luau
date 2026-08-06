--!strict

local VRService = game:GetService("VRService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CONFIG = {
	PHYSICS_CHECK_INTERVAL = 0.05,
	VELOCITY_DAMPING = 0.92,
	MAX_ACCUMULATED_VELOCITY = 100,
	HEADSET_SYNC_INTERVAL = 0.1,
	IDLE_THRESHOLD = 0.5,
	APPLY_GRAVITY_COMPENSATION = true,
	PREVENT_PLATFORM_STAND = true,
	RESTORE_HUMANOID_STATE = true,
}

local VRStabilizer = {}
VRStabilizer.__index = VRStabilizer

function VRStabilizer.new()
	local self = setmetatable({}, VRStabilizer)

	self.localPlayer = Players.LocalPlayer
	self.lastPhysicsCheck = 0
	self.lastHeadsetSync = 0
	self.lastInputTime = tick()
	self.isMoving = false
	self.humanoidStateConn = nil
	self.heartbeatConn = nil
	self.spawnTime = 0

	return self
end

function VRStabilizer:Enable()
	if not VRService.VREnabled then
		return
	end

	self.spawnTime = tick()
	self.lastInputTime = tick()

	self.heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		self:OnHeartbeat(dt)
	end)

	local humanoid = self:GetHumanoid()
	if humanoid then
		self.humanoidStateConn = humanoid.StateChanged:Connect(function(oldState, newState)
			self:OnHumanoidStateChanged(oldState, newState)
		end)
	end
end

function VRStabilizer:Disable()
	if self.heartbeatConn then
		self.heartbeatConn:Disconnect()
		self.heartbeatConn = nil
	end

	if self.humanoidStateConn then
		self.humanoidStateConn:Disconnect()
		self.humanoidStateConn = nil
	end
end

function VRStabilizer:GetHumanoid()
	local character = self.localPlayer.Character
	if not character then
		return nil
	end

	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Humanoid") then
			return child
		end
	end

	return nil
end

function VRStabilizer:GetRootPart()
	local humanoid = self:GetHumanoid()
	if humanoid then
		return humanoid.RootPart
	end
	return nil
end

function VRStabilizer:OnHumanoidStateChanged(oldState, newState)
	if not CONFIG.PREVENT_PLATFORM_STAND then
		return
	end

	local humanoid = self:GetHumanoid()
	if not humanoid then
		return
	end

	if newState == Enum.HumanoidStateType.PlatformStand then
		task.wait(0.01)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	elseif newState == Enum.HumanoidStateType.Disabled then
		task.wait(0.01)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

function VRStabilizer:UpdateMovementState(moveVector)
	local inputMagnitude = moveVector.Magnitude
	local currentTime = tick()

	if inputMagnitude > 0.01 then
		self.lastInputTime = currentTime
		self.isMoving = true
	else
		self.isMoving = false
	end
end

function VRStabilizer:StabilizePhysics()
	local rootPart = self:GetRootPart()
	if not rootPart then
		return
	end

	local currentTime = tick()
	if currentTime - self.lastPhysicsCheck < CONFIG.PHYSICS_CHECK_INTERVAL then
		return
	end

	self.lastPhysicsCheck = currentTime

	local velocity = rootPart.AssemblyLinearVelocity
	local speed = velocity.Magnitude

	if speed > CONFIG.MAX_ACCUMULATED_VELOCITY then
		rootPart.AssemblyLinearVelocity = velocity * (CONFIG.MAX_ACCUMULATED_VELOCITY / speed)
		return
	end

	local timeSinceInput = currentTime - self.lastInputTime
	if timeSinceInput > CONFIG.IDLE_THRESHOLD and speed > 0.2 then
		rootPart.AssemblyLinearVelocity = velocity * CONFIG.VELOCITY_DAMPING
	end
end

function VRStabilizer:SyncToHeadset()
	if not VRService:GetUserCFrameEnabled(Enum.UserCFrame.Head) then
		return
	end

	local rootPart = self:GetRootPart()
	if not rootPart then
		return
	end

	local currentTime = tick()
	local timeSinceSpawn = currentTime - self.spawnTime

	if timeSinceSpawn < 5 then
		return
	end

	local timeSinceInput = currentTime - self.lastInputTime

	if timeSinceInput < CONFIG.IDLE_THRESHOLD then
		return
	end

	if currentTime - self.lastHeadsetSync < CONFIG.HEADSET_SYNC_INTERVAL then
		return
	end

	self.lastHeadsetSync = currentTime

	local headsetCFrame = VRService:GetUserCFrame(Enum.UserCFrame.Head)
	local headsetPos = headsetCFrame.Position

	if headsetPos.Magnitude == 0 or not (headsetPos == headsetPos) then
		return
	end

	local currentPos = rootPart.Position
	local targetPos = Vector3.new(headsetPos.X, currentPos.Y, headsetPos.Z)

	rootPart.CFrame = CFrame.new(targetPos) * rootPart.CFrame.Rotation
end

function VRStabilizer:OnHeartbeat(dt)
	local humanoid = self:GetHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if humanoid.Sit then
		humanoid.Sit = false
	end

	self:StabilizePhysics()
end

function VRStabilizer:SetMovementInput(moveVector)
	self:UpdateMovementState(moveVector)
end

return VRStabilizer
