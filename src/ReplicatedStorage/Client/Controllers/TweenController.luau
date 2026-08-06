--!strict
-- @author Velumix
-- @version 0.0.1
--[=[
	@class TweenController
	@client
	Keyed TweenService wrapper with replacement, cancellation, grouping,
	sequences, reduced-motion handling, and automatic instance cleanup.
]=]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local Signal = require(ReplicatedStorage.Modules.Signal)

export type Goals = { [string]: any }

--[=[
	@interface TweenOptions
	.Group string? -- Lets several tweens be cancelled together.
	.Replace boolean? -- Replaces the same target/key tween. Defaults to true.
	.AutoPlay boolean? -- Plays immediately. Defaults to true.
	.RespectReducedMotion boolean? -- Uses a zero-duration tween when enabled. Defaults to true.
	@within TweenController
]=]
export type TweenOptions = {
	Group: string?,
	Replace: boolean?,
	AutoPlay: boolean?,
	RespectReducedMotion: boolean?,
}

--[=[
	@interface TweenStep
	.Target Instance
	.Key string
	.Info TweenInfo
	.Goals Goals
	.Options TweenOptions?
	.Delay number? -- Delay before this step begins.
	@within TweenController
]=]
export type TweenStep = {
	Target: Instance,
	Key: string,
	Info: TweenInfo,
	Goals: Goals,
	Options: TweenOptions?,
	Delay: number?,
}

export type TweenHandle = {
	Target: Instance,
	Key: string,
	Tween: Tween,
	Play: (self: TweenHandle) -> TweenHandle,
	Pause: (self: TweenHandle) -> TweenHandle,
	Cancel: (self: TweenHandle) -> (),
	Await: (self: TweenHandle) -> Enum.PlaybackState,
	IsActive: (self: TweenHandle) -> boolean,
	Destroy: (self: TweenHandle) -> (),
}

export type SequenceHandle = {
	Cancel: (self: SequenceHandle) -> (),
	Await: (self: SequenceHandle) -> boolean,
	IsActive: (self: SequenceHandle) -> boolean,
	Destroy: (self: SequenceHandle) -> (),
}

type Record = {
	Handle: TweenHandle,
	Group: string?,
	Connection: RBXScriptConnection,
}

local Controller = Knit.CreateController({ Name = "TweenController" })
--[=[
	@prop Completed Signal
	@within TweenController
	Fires with `(target, key, handle)` after a tween completes.
]=]
Controller.Completed = Signal.new()
--[=[
	@prop Cancelled Signal
	@within TweenController
	Fires with `(target, key, handle)` after a tween is cancelled or interrupted.
]=]
Controller.Cancelled = Signal.new()
Controller._records = setmetatable({}, { __mode = "k" }) :: { [Instance]: { [string]: Record } }
Controller._destroyConnections = setmetatable({}, { __mode = "k" }) :: { [Instance]: RBXScriptConnection }

local Handle = {}
Handle.__index = Handle

local Sequence = {}
Sequence.__index = Sequence

local function resolvedInfo(info: TweenInfo, respectReducedMotion: boolean?): TweenInfo
	if respectReducedMotion ~= false and GuiService.ReducedMotionEnabled then
		return TweenInfo.new(0, info.EasingStyle, info.EasingDirection, 0, false, 0)
	end
	return info
end

function Handle:Play(): TweenHandle
	if (self :: any)._controller then
		self.Tween:Play()
	end
	return self
end

function Handle:Pause(): TweenHandle
	if (self :: any)._controller then
		self.Tween:Pause()
	end
	return self
end

function Handle:Cancel()
	if (self :: any)._controller then
		self.Tween:Cancel()
	end
end

function Handle:Await(): Enum.PlaybackState
	local playbackState = (self :: any)._playbackState
	if playbackState then
		return playbackState
	end
	if not (self :: any)._controller then
		return Enum.PlaybackState.Cancelled
	end
	playbackState = self.Tween.Completed:Wait()
	local controller = (self :: any)._controller
	if controller then
		controller:_remove(self, playbackState)
	end
	return playbackState
end

function Handle:IsActive(): boolean
	local controller = (self :: any)._controller
	return controller ~= nil and controller:_isCurrent(self)
end

Handle.Destroy = Handle.Cancel

function Sequence:Cancel()
	local sequence = self :: any
	if not sequence._active then
		return
	end
	sequence._cancelled = true
	local current = sequence._current
	if current then
		current:Cancel()
	end
end

function Sequence:Await(): boolean
	local sequence = self :: any
	if sequence._active then
		sequence._finished.Event:Wait()
	end
	return not sequence._cancelled
end

function Sequence:IsActive(): boolean
	return (self :: any)._active == true
end

Sequence.Destroy = Sequence.Cancel

function Controller:_isCurrent(handle: TweenHandle): boolean
	local targetRecords = self._records[handle.Target]
	local record = targetRecords and targetRecords[handle.Key]
	return record ~= nil and record.Handle == handle
end

function Controller:_remove(handle: TweenHandle, playbackState: Enum.PlaybackState)
	local targetRecords = self._records[handle.Target]
	local record = targetRecords and targetRecords[handle.Key]
	if not record or record.Handle ~= handle then
		return
	end
	record.Connection:Disconnect()
	targetRecords[handle.Key] = nil
	local mutableHandle = handle :: any
	mutableHandle._playbackState = playbackState
	mutableHandle._controller = nil
	if next(targetRecords) == nil then
		self._records[handle.Target] = nil
		local destroying = self._destroyConnections[handle.Target]
		if destroying then
			destroying:Disconnect()
			self._destroyConnections[handle.Target] = nil
		end
	end
	if playbackState == Enum.PlaybackState.Completed then
		self.Completed:Fire(handle.Target, handle.Key, handle)
	else
		self.Cancelled:Fire(handle.Target, handle.Key, handle)
	end
end

function Controller:_watchTarget(target: Instance)
	if self._destroyConnections[target] then
		return
	end
	self._destroyConnections[target] = target.Destroying:Connect(function()
		self:CancelAll(target)
	end)
end

--[=[
	Creates a keyed tween. Creating another tween with the same target and key
	cancels the old one unless `Replace` is false.

	@param target Instance
	@param key string
	@param info TweenInfo
	@param goals Goals
	@param options TweenOptions?
	@return TweenHandle
]=]
function Controller:Create(
	target: Instance,
	key: string,
	info: TweenInfo,
	goals: Goals,
	options: TweenOptions?
): TweenHandle
	assert(typeof(target) == "Instance", "tween target must be an Instance")
	assert(type(key) == "string" and key ~= "", "tween key is required")
	assert(next(goals) ~= nil, "tween goals cannot be empty")
	local targetRecords = self._records[target]
	if not targetRecords then
		targetRecords = {}
		self._records[target] = targetRecords
		self:_watchTarget(target)
	end
	local existing = targetRecords[key]
	if existing then
		if options and options.Replace == false then
			return existing.Handle
		end
		existing.Handle:Cancel()
		targetRecords = self._records[target]
		if not targetRecords then
			targetRecords = {}
			self._records[target] = targetRecords
			self:_watchTarget(target)
		end
	end
	local tween = TweenService:Create(target, resolvedInfo(info, options and options.RespectReducedMotion), goals)
	local handle = setmetatable({
		Target = target,
		Key = key,
		Tween = tween,
		_controller = self,
		_playbackState = nil,
	}, Handle) :: any
	local connection = tween.Completed:Connect(function(playbackState)
		self:_remove(handle, playbackState)
	end)
	targetRecords[key] = {
		Handle = handle,
		Group = options and options.Group,
		Connection = connection,
	}
	if not options or options.AutoPlay ~= false then
		handle:Play()
	end
	return handle
end

--[=[ Creates and immediately plays a keyed tween. ]=]
function Controller:Play(
	target: Instance,
	key: string,
	info: TweenInfo,
	goals: Goals,
	options: TweenOptions?
): TweenHandle
	local resolvedOptions = table.clone(options or {})
	resolvedOptions.AutoPlay = true
	return self:Create(target, key, info, goals, resolvedOptions)
end

--[=[ Cancels one keyed tween. ]=]
function Controller:Cancel(target: Instance, key: string): boolean
	local targetRecords = self._records[target]
	local record = targetRecords and targetRecords[key]
	if not record then
		return false
	end
	record.Handle:Cancel()
	return true
end

--[=[ Cancels every tween on an instance. ]=]
function Controller:CancelAll(target: Instance)
	local targetRecords = self._records[target]
	if not targetRecords then
		return
	end
	local handles = {}
	for _, record in targetRecords do
		table.insert(handles, record.Handle)
	end
	for _, handle in handles do
		handle:Cancel()
	end
end

--[=[ Cancels every active tween in a group. ]=]
function Controller:CancelGroup(group: string)
	local handles = {}
	for _, targetRecords in self._records do
		for _, record in targetRecords do
			if record.Group == group then
				table.insert(handles, record.Handle)
			end
		end
	end
	for _, handle in handles do
		handle:Cancel()
	end
end

--[=[
	Runs tween steps in order. Cancelling the sequence cancels its current tween.
	@param steps {TweenStep}
	@return SequenceHandle
]=]
function Controller:Sequence(steps: { TweenStep }): SequenceHandle
	local finished = Instance.new("BindableEvent")
	local sequence = setmetatable({
		_active = true,
		_cancelled = false,
		_current = nil,
		_finished = finished,
	}, Sequence) :: any
	task.spawn(function()
		for _, step in steps do
			if sequence._cancelled then
				break
			end
			if step.Delay and step.Delay > 0 then
				task.wait(step.Delay)
			end
			if sequence._cancelled or not step.Target.Parent then
				break
			end
			local handle = self:Play(step.Target, step.Key, step.Info, step.Goals, step.Options)
			sequence._current = handle
			local result = handle:Await()
			sequence._current = nil
			if result ~= Enum.PlaybackState.Completed then
				sequence._cancelled = true
				break
			end
		end
		sequence._active = false
		finished:Fire()
		task.defer(function()
			finished:Destroy()
		end)
	end)
	return sequence
end

--[=[ Pass-through to TweenService:SmoothDamp for non-Instance values. ]=]
function Controller:SmoothDamp(
	current: any,
	target: any,
	velocity: any,
	smoothTime: number,
	maxSpeed: number?,
	deltaTime: number?
): (any, any)
	return TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed, deltaTime)
end

function Controller:Destroy()
	local targets = {}
	for target in self._records do
		table.insert(targets, target)
	end
	for _, target in targets do
		self:CancelAll(target)
	end
	self.Completed:Destroy()
	self.Cancelled:Destroy()
end

return Controller
