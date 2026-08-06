--!strict
-- @author Velumix
-- @version 0.0.1
--[=[
	@class CameraController
	@client
	Owns temporary camera, cursor, mouse-lock, and humanoid camera-offset state.
	States are layered by priority and released through handles, so one feature
	cannot leave input or camera properties stuck after it ends.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)

--[=[
	@interface CameraFrame
	.CFrame CFrame? -- Scriptable camera position for this frame.
	.Focus CFrame? -- Scriptable camera focus for this frame.
	.FieldOfView number? -- Optional per-frame field of view.
	@within CameraController
]=]
export type CameraFrame = {
	CFrame: CFrame?,
	Focus: CFrame?,
	FieldOfView: number?,
}

export type CameraOffsetResolver = (camera: Camera, deltaTime: number) -> Vector3
export type CameraUpdate = (camera: Camera, deltaTime: number) -> CameraFrame?

--[=[
	@interface CameraState
	.Priority number -- Higher states win. Defaults to 0.
	.Owner Instance? -- Destroying the owner releases the state.
	.CameraType Enum.CameraType? -- Overrides the Roblox camera type.
	.CameraSubject Instance? -- Overrides the camera subject.
	.FieldOfView number? -- Target vertical field of view.
	.FieldOfViewSpeed number? -- Exponential blend speed. Omit for an immediate change.
	.MouseBehavior Enum.MouseBehavior? -- Applied after the default camera each frame.
	.MouseIconEnabled boolean? -- Applied after the default camera each frame.
	.CameraOffset Vector3 | CameraOffsetResolver? -- Humanoid camera offset.
	.CameraOffsetSubject Humanoid? -- Humanoid that receives CameraOffset.
	.CameraOffsetAdditive boolean? -- Adds the offset to its captured baseline.
	.CameraOffsetSpeed number? -- Exponential offset blend speed. Omit for immediate.
	.Update CameraUpdate? -- Runs only for the highest active state that defines it.
	.OnEnter (() -> ())? -- Called when this becomes the top state.
	.OnExit (() -> ())? -- Called when this stops being the top state.
	@within CameraController
]=]
export type CameraState = {
	Priority: number?,
	Owner: Instance?,
	CameraType: Enum.CameraType?,
	CameraSubject: Instance?,
	FieldOfView: number?,
	FieldOfViewSpeed: number?,
	MouseBehavior: Enum.MouseBehavior?,
	MouseIconEnabled: boolean?,
	CameraOffset: (Vector3 | CameraOffsetResolver)?,
	CameraOffsetSubject: Humanoid?,
	CameraOffsetAdditive: boolean?,
	CameraOffsetSpeed: number?,
	Update: CameraUpdate?,
	OnEnter: (() -> ())?,
	OnExit: (() -> ())?,
}

export type CameraHandle = {
	Id: string,
	Release: (self: CameraHandle) -> (),
	Update: (self: CameraHandle, state: CameraState) -> (),
	IsActive: (self: CameraHandle) -> boolean,
	Destroy: (self: CameraHandle) -> (),
}

type StateRecord = {
	Id: string,
	Order: number,
	State: CameraState,
	Handle: CameraHandle,
	OwnerConnection: RBXScriptConnection?,
}

type Baseline = {
	Camera: Camera,
	CameraType: Enum.CameraType,
	CameraSubject: Instance?,
	FieldOfView: number,
	MouseBehavior: Enum.MouseBehavior,
	MouseIconEnabled: boolean,
}

local RENDER_NAME = "KnitCameraController"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 10

local Controller = Knit.CreateController({ Name = "CameraController" })
--[=[
	@prop StateChanged Signal
	@within CameraController
	Fires with `(activeStateId, previousStateId)` when the top state changes.
]=]
Controller.StateChanged = Signal.new()
Controller._trove = Trove.new()
Controller._states = {} :: { [string]: StateRecord }
Controller._ordered = {} :: { StateRecord }
Controller._order = 0
Controller._baseline = nil :: Baseline?
Controller._top = nil :: StateRecord?
Controller._offsetBaselines = {} :: { [Humanoid]: Vector3 }
Controller._offsetSubject = nil :: Humanoid?

local Handle = {}
Handle.__index = Handle

local function safeCall(callback: (() -> ())?)
	if callback then
		local ok, err = xpcall(callback, debug.traceback)
		if not ok then
			warn(`[CameraController] State callback failed: {tostring(err)}`)
		end
	end
end

local function blendAlpha(speed: number?, deltaTime: number): number
	return if speed and speed > 0 then 1 - math.exp(-speed * deltaTime) else 1
end

local function copyState(state: CameraState): CameraState
	return table.clone(state)
end

function Handle:Release()
	local controller = (self :: any)._controller
	if controller then
		controller:_release(self, self.Id)
	end
end

function Handle:Update(state: CameraState)
	local controller = (self :: any)._controller
	if controller then
		controller:_update(self, self.Id, state)
	end
end

function Handle:IsActive(): boolean
	local controller = (self :: any)._controller
	return controller ~= nil and controller:_has(self, self.Id)
end

Handle.Destroy = Handle.Release

function Controller:_captureBaseline()
	if self._baseline then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	self._baseline = {
		Camera = camera,
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		FieldOfView = camera.FieldOfView,
		MouseBehavior = UserInputService.MouseBehavior,
		MouseIconEnabled = UserInputService.MouseIconEnabled,
	}
end

function Controller:_restoreOffset()
	local humanoid = self._offsetSubject
	if humanoid then
		local baseline = self._offsetBaselines[humanoid]
		if baseline and humanoid.Parent then
			humanoid.CameraOffset = baseline
		end
	end
	self._offsetSubject = nil
end

function Controller:_restoreBaseline()
	self:_restoreOffset()
	local baseline = self._baseline
	if not baseline then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = baseline.CameraType
		if baseline.CameraSubject and baseline.CameraSubject.Parent then
			camera.CameraSubject = baseline.CameraSubject
		end
		camera.FieldOfView = baseline.FieldOfView
	end
	UserInputService.MouseBehavior = baseline.MouseBehavior
	UserInputService.MouseIconEnabled = baseline.MouseIconEnabled
	self._baseline = nil
end

function Controller:_resort()
	table.clear(self._ordered)
	for _, record in self._states do
		table.insert(self._ordered, record)
	end
	table.sort(self._ordered, function(left, right)
		local leftPriority = left.State.Priority or 0
		local rightPriority = right.State.Priority or 0
		return if leftPriority == rightPriority then left.Order > right.Order else leftPriority > rightPriority
	end)
	local previous = self._top
	local nextTop = self._ordered[1]
	if previous ~= nextTop then
		safeCall(previous and previous.State.OnExit)
		self._top = nextTop
		safeCall(nextTop and nextTop.State.OnEnter)
		self.StateChanged:Fire(nextTop and nextTop.Id or nil, previous and previous.Id or nil)
	end
	if #self._ordered == 0 then
		self:_restoreBaseline()
	else
		self:_captureBaseline()
	end
end

function Controller:_has(token: any, id: string): boolean
	local record = self._states[id]
	return record ~= nil and record.Handle == token
end

function Controller:_release(token: any, id: string)
	local record = self._states[id]
	if not record or record.Handle ~= token then
		return
	end
	self._states[id] = nil
	if record.OwnerConnection then
		record.OwnerConnection:Disconnect()
	end
	(record.Handle :: any)._controller = nil
	self:_resort()
end

function Controller:_update(token: any, id: string, state: CameraState)
	local record = self._states[id]
	if not record or record.Handle ~= token then
		return
	end
	if record.OwnerConnection then
		record.OwnerConnection:Disconnect()
		record.OwnerConnection = nil
	end
	record.State = copyState(state)
	local owner = state.Owner
	if owner then
		record.OwnerConnection = owner.Destroying:Connect(function()
			token:Release()
		end)
	end
	self:_resort()
end

--[=[
	Pushes or replaces a named camera state. Destroy the returned handle to
	release it. A stale handle cannot release a newer state with the same ID.

	@param id string
	@param state CameraState
	@return CameraHandle
]=]
function Controller:Push(id: string, state: CameraState): CameraHandle
	assert(type(id) == "string" and id ~= "", "camera state ID is required")
	local existing = self._states[id]
	if existing then
		existing.Handle:Release()
	end
	self:_captureBaseline()
	self._order += 1
	local handle = setmetatable({
		Id = id,
		_controller = self,
	}, Handle) :: any
	local record: StateRecord = {
		Id = id,
		Order = self._order,
		State = copyState(state),
		Handle = handle,
		OwnerConnection = nil,
	}
	self._states[id] = record
	if state.Owner then
		record.OwnerConnection = state.Owner.Destroying:Connect(function()
			handle:Release()
		end)
	end
	self:_resort()
	return handle
end

--[=[ Returns the highest-priority state ID, or nil when idle. ]=]
function Controller:GetActiveState(): string?
	return self._top and self._top.Id or nil
end

--[=[ Releases a state by ID. Prefer destroying its handle when possible. ]=]
function Controller:Pop(id: string): boolean
	local record = self._states[id]
	if not record then
		return false
	end
	record.Handle:Release()
	return true
end

local function stateValue<T>(ordered: { StateRecord }, read: (CameraState) -> T?): T?
	for _, record in ordered do
		local value = read(record.State)
		if value ~= nil then
			return value
		end
	end
	return nil
end

function Controller:_render(deltaTime: number)
	if #self._ordered == 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not self._baseline then
		self:_captureBaseline()
	end
	local baseline = self._baseline
	if baseline and baseline.Camera ~= camera then
		baseline.Camera = camera
		baseline.CameraType = camera.CameraType
		baseline.CameraSubject = camera.CameraSubject
		baseline.FieldOfView = camera.FieldOfView
	end

	local cameraType = stateValue(self._ordered, function(state)
		return state.CameraType
	end)
	local subject = stateValue(self._ordered, function(state)
		return state.CameraSubject
	end)
	local fieldOfView = stateValue(self._ordered, function(state)
		return state.FieldOfView
	end)
	local fieldOfViewSpeed = stateValue(self._ordered, function(state)
		return state.FieldOfViewSpeed
	end)
	local mouseBehavior = stateValue(self._ordered, function(state)
		return state.MouseBehavior
	end)
	local mouseIconEnabled = stateValue(self._ordered, function(state)
		return state.MouseIconEnabled
	end)
	local update = stateValue(self._ordered, function(state)
		return state.Update
	end)

	if baseline then
		camera.CameraType = cameraType or baseline.CameraType
		local resolvedSubject = subject or baseline.CameraSubject
		if resolvedSubject and resolvedSubject.Parent then
			camera.CameraSubject = resolvedSubject
		end
		local resolvedFieldOfView = fieldOfView or baseline.FieldOfView
		camera.FieldOfView += (resolvedFieldOfView - camera.FieldOfView) * blendAlpha(fieldOfViewSpeed, deltaTime)
		UserInputService.MouseBehavior = mouseBehavior or baseline.MouseBehavior
		UserInputService.MouseIconEnabled = if mouseIconEnabled ~= nil
			then mouseIconEnabled
			else baseline.MouseIconEnabled
	else
		if cameraType then
			camera.CameraType = cameraType
		end
		if subject and subject.Parent then
			camera.CameraSubject = subject
		end
		if fieldOfView then
			camera.FieldOfView += (fieldOfView - camera.FieldOfView) * blendAlpha(fieldOfViewSpeed, deltaTime)
		end
		if mouseBehavior then
			UserInputService.MouseBehavior = mouseBehavior
		end
		if mouseIconEnabled ~= nil then
			UserInputService.MouseIconEnabled = mouseIconEnabled
		end
	end

	local offsetState = nil :: CameraState?
	for _, record in self._ordered do
		if record.State.CameraOffset ~= nil and record.State.CameraOffsetSubject ~= nil then
			offsetState = record.State
			break
		end
	end
	local offsetHumanoid = offsetState and offsetState.CameraOffsetSubject
	if self._offsetSubject and self._offsetSubject ~= offsetHumanoid then
		self:_restoreOffset()
	end
	if offsetState and offsetHumanoid and offsetHumanoid.Parent then
		local offsetBaseline = self._offsetBaselines[offsetHumanoid]
		if not offsetBaseline then
			offsetBaseline = offsetHumanoid.CameraOffset
			self._offsetBaselines[offsetHumanoid] = offsetBaseline
		end
		self._offsetSubject = offsetHumanoid
		local rawOffset = offsetState.CameraOffset
		local offset = if type(rawOffset) == "function" then rawOffset(camera, deltaTime) else rawOffset :: Vector3
		local target = if offsetState.CameraOffsetAdditive == false then offset else offsetBaseline + offset
		offsetHumanoid.CameraOffset =
			offsetHumanoid.CameraOffset:Lerp(target, blendAlpha(offsetState.CameraOffsetSpeed, deltaTime))
	elseif self._offsetSubject then
		self:_restoreOffset()
	end

	if update then
		local ok, frame = xpcall(update, debug.traceback, camera, deltaTime)
		if not ok then
			warn(`[CameraController] Update failed: {tostring(frame)}`)
		elseif frame then
			if frame.CFrame then
				camera.CFrame = frame.CFrame
			end
			if frame.Focus then
				camera.Focus = frame.Focus
			end
			if frame.FieldOfView then
				camera.FieldOfView = frame.FieldOfView
			end
		end
	end
end

function Controller:KnitStart()
	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, function(deltaTime)
		self:_render(math.min(deltaTime, 0.1))
	end)
	self._trove:Add(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
	self._trove:Connect(Players.LocalPlayer.CharacterAdded, function()
		for humanoid in self._offsetBaselines do
			if not humanoid.Parent then
				self._offsetBaselines[humanoid] = nil
			end
		end
	end)
end

function Controller:Destroy()
	local handles = {}
	for _, record in self._states do
		table.insert(handles, record.Handle)
	end
	for _, handle in handles do
		handle:Release()
	end
	self:_restoreBaseline()
	self._trove:Destroy()
	self.StateChanged:Destroy()
end

return Controller
