local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Mince = require(ReplicatedStorage.Modules.Mince)

local VRService = {
	Name = "VRService",
	PlayerStates = {},
}

local function finiteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function finiteVector3(value)
	return typeof(value) == "Vector3" and finiteNumber(value.X) and finiteNumber(value.Y) and finiteNumber(value.Z)
end

local function finiteCFrame(value)
	if typeof(value) ~= "CFrame" then
		return nil
	end

	local components = {value:GetComponents()}
	for _, number in ipairs(components) do
		if not finiteNumber(number) then
			return nil
		end
	end

	return value
end

local function sanitizeVector3(value)
	if finiteVector3(value) then
		return value
	end
	return nil
end

local function sanitizeMove(move)
	if finiteVector3(move) then
		return move
	end

	if typeof(move) == "table" then
		return sanitizeVector3(move.move or move.Move or move.Direction)
	end

	return nil
end

function VRService:Setup()
	self.Remote = Mince:GetEvent("VRRig")
	self.PoseEvent = self.Remote and self.Remote:Extend("Pose")
	self.MoveEvent = self.Remote and self.Remote:Extend("Move")

	self.PoseChanged = Mince.Signal.new()
	self.MoveChanged = Mince.Signal.new()

	if self.PoseEvent then
		self.PoseEvent.Event:Connect(function(player, payload)
			self:OnPose(player, payload)
		end)
	end

	if self.MoveEvent then
		self.MoveEvent.Event:Connect(function(player, payload)
			self:OnMove(player, payload)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)
end

function VRService:GameStart()
	-- no-op, kept for Mince lifecycle symmetry
end

function VRService:OnPose(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	local head = finiteCFrame(payload.head or payload.Head)
	local left = finiteCFrame(payload.leftHand or payload.LeftHand)
	local right = finiteCFrame(payload.rightHand or payload.RightHand)
	local camera = finiteCFrame(payload.camera or payload.Camera)

	if not head then
		return
	end

	local state = self.PlayerStates[player] or {}
	state.HeadCFrame = head
	state.LeftHandCFrame = left
	state.RightHandCFrame = right
	state.CameraCFrame = camera
	state.LastUpdate = os.clock()
	state.IsVR = true

	self.PlayerStates[player] = state

	player:SetAttribute("VRActive", true)
	self.PoseChanged:Fire(player, state)
end

function VRService:OnMove(player, payload)
	local move = sanitizeMove(payload) or Vector3.zero

	local state = self.PlayerStates[player]
	if state then
		state.MoveVector = move
		state.LastMove = os.clock()
	end

	player:SetAttribute("VRMoveX", move.X)
	player:SetAttribute("VRMoveZ", move.Z)
	player:SetAttribute("VRMoveMag", move.Magnitude)

	self.MoveChanged:Fire(player, move)
end

function VRService:GetState(player)
	return self.PlayerStates[player]
end

function VRService:IsVR(player)
	local state = self.PlayerStates[player]
	return state and state.IsVR or false
end

function VRService:OnPlayerRemoving(player)
	self.PlayerStates[player] = nil
end

return VRService
