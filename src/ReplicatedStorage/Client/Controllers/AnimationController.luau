--!strict
-- @author Velumix
-- @version 0.0.1
--[=[
	@class AnimationController
	@client
	Loads and plays animations through Animator for humanoids and animated models.
]=]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Config.AnimationConfig)
local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)

type Definition = AnimationConfig.Definition
type PlayOptions = {
	FadeTime: number?,
	Weight: number?,
	Speed: number?,
	Restart: boolean?,
}
type LoadOptions = {
	Key: string?,
	Group: string?,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
}
type TrackRecord = {
	Animation: Animation,
	Track: AnimationTrack,
	Group: string?,
	Definition: Definition?,
}

local LOCAL_PLAYER = Players.LocalPlayer

local Controller = Knit.CreateController({ Name = "AnimationController" })
Controller.Played = Signal.new()
Controller.Stopped = Signal.new()
Controller._trove = Trove.new()
Controller._definitions = {} :: { [string]: Definition }
Controller._records = {} :: { [Animator]: { [string]: TrackRecord } }
Controller._animatorTroves = {} :: { [Animator]: any }
Controller._character = nil :: Model?

local function normalizeId(id: string): string
	if string.match(id, "^rbxassetid://%d+$") then
		return id
	end
	local number = string.match(id, "%d+")
	return if number then `rbxassetid://{number}` else id
end

local function findAnimationHost(subject: Instance): (Humanoid | AnimationController)?
	if subject:IsA("Humanoid") or subject:IsA("AnimationController") then
		return subject
	end
	if subject:IsA("Model") then
		return subject:FindFirstChildOfClass("Humanoid") or subject:FindFirstChildOfClass("AnimationController")
	end
	local model = subject:FindFirstAncestorOfClass("Model")
	return if model
		then model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
		else nil
end

function Controller:Register(name: string, definition: Definition)
	assert(type(name) == "string" and name ~= "", "animation name is required")
	assert(type(definition.Id) == "string" and definition.Id ~= "", `animation {name} needs an ID`)
	self._definitions[name] = table.freeze(table.clone(definition))
end

function Controller:GetAnimator(subject: Instance?, create: boolean?): Animator?
	local resolved = subject or self._character
	if not resolved then
		return nil
	end
	if resolved:IsA("Animator") then
		return resolved
	end
	local host = findAnimationHost(resolved)
	if not host and create and resolved:IsA("Model") then
		local animationHost = Instance.new("AnimationController")
		animationHost.Name = "AnimationController"
		animationHost.Parent = resolved
		host = animationHost
	end
	if not host then
		return nil
	end
	local animator = host:FindFirstChildOfClass("Animator")
	if not animator and create then
		animator = Instance.new("Animator")
		animator.Parent = host
	end
	return animator
end

function Controller:_watchAnimator(animator: Animator)
	if self._animatorTroves[animator] then
		return
	end
	local trove = Trove.new()
	self._animatorTroves[animator] = trove
	trove:Connect(animator.AncestryChanged, function(_, parent)
		if not parent then
			self:Release(animator)
		end
	end)
end

function Controller:_load(
	animator: Animator,
	key: string,
	animation: Animation,
	options: LoadOptions?,
	definition: Definition?
): AnimationTrack
	local records = self._records[animator]
	if not records then
		records = {}
		self._records[animator] = records
		self:_watchAnimator(animator)
	end
	local existing = records[key]
	if existing then
		return existing.Track
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = (options and options.Priority) or (definition and definition.Priority) or track.Priority
	local looped = if options and options.Looped ~= nil
		then options.Looped
		elseif definition then definition.Looped
		else nil
	if looped ~= nil then
		track.Looped = looped
	end
	local record = {
		Animation = animation,
		Track = track,
		Group = (options and options.Group) or (definition and definition.Group),
		Definition = definition,
	}
	records[key] = record
	local trove = self._animatorTroves[animator]
	trove:Add(track.Stopped:Connect(function()
		self.Stopped:Fire(animator, key, track)
	end))
	return track
end

function Controller:Load(
	subject: Instance?,
	animationOrName: Animation | string,
	options: LoadOptions?
): AnimationTrack?
	local animator = self:GetAnimator(subject, false)
	if not animator then
		return nil
	end
	if typeof(animationOrName) == "Instance" and animationOrName:IsA("Animation") then
		local key = (options and options.Key) or `{animationOrName.Name}@{animationOrName.AnimationId}`
		return self:_load(animator, key, animationOrName, options, nil)
	end
	if type(animationOrName) ~= "string" then
		return nil
	end
	local definition = self._definitions[animationOrName]
	if not definition then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.Name = animationOrName
	animation.AnimationId = normalizeId(definition.Id)
	return self:_load(animator, animationOrName, animation, options, definition)
end

function Controller:LoadFolder(
	subject: Instance?,
	folder: Instance,
	options: LoadOptions?
): { [string]: AnimationTrack }
	local tracks = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Animation") then
			local childOptions = table.clone(options or {})
			childOptions.Key = if options and options.Key then `{options.Key}.{child.Name}` else nil
			local track = self:Load(subject, child, childOptions)
			if track then
				tracks[child.Name] = track
			end
		end
	end
	return tracks
end

function Controller:PlayTrack(track: AnimationTrack, options: PlayOptions?)
	local restart = not options or options.Restart ~= false
	if track.IsPlaying and restart then
		track:Stop(0)
	elseif track.IsPlaying then
		return track
	end
	local fadeTime = (options and options.FadeTime) or AnimationConfig.DefaultFadeTime
	track:Play(fadeTime, (options and options.Weight) or 1, (options and options.Speed) or 1)
	self.Played:Fire(track)
	return track
end

function Controller:Play(
	subject: Instance?,
	animationOrName: Animation | string,
	options: PlayOptions?
): AnimationTrack?
	local track = self:Load(subject, animationOrName)
	return if track then self:PlayTrack(track, options) else nil
end

function Controller:StopTrack(track: AnimationTrack, fadeTime: number?)
	if track.IsPlaying then
		track:Stop(fadeTime or AnimationConfig.DefaultFadeTime)
	end
end

function Controller:StopGroup(subject: Instance?, group: string, fadeTime: number?)
	local animator = self:GetAnimator(subject, false)
	local records = animator and self._records[animator]
	if not records then
		return
	end
	for _, record in records do
		if record.Group == group then
			self:StopTrack(record.Track, fadeTime)
		end
	end
end

function Controller:Release(subject: Instance?)
	local animator = self:GetAnimator(subject, false)
	if not animator then
		return
	end
	local records = self._records[animator]
	if records then
		for _, record in records do
			record.Track:Stop(0)
			record.Track:Destroy()
		end
		self._records[animator] = nil
	end
	local trove = self._animatorTroves[animator]
	if trove then
		self._animatorTroves[animator] = nil
		trove:Destroy()
	end
end

function Controller:KnitInit()
	for name, definition in AnimationConfig.Definitions do
		self:Register(name, definition)
	end
end

function Controller:KnitStart()
	local preload = {}
	for name, definition in self._definitions do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = normalizeId(definition.Id)
		table.insert(preload, animation)
	end
	if #preload > 0 then
		task.spawn(function()
			local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, preload)
			if not ok then
				warn(`[AnimationController] Preload failed: {tostring(err)}`)
			end
			for _, animation in preload do
				animation:Destroy()
			end
		end)
	end
	self._trove:Connect(LOCAL_PLAYER.CharacterAdded, function(character)
		self._character = character
	end)
	self._character = LOCAL_PLAYER.Character
end

function Controller:Destroy()
	local animators = {}
	for animator in self._records do
		table.insert(animators, animator)
	end
	for _, animator in animators do
		self:Release(animator)
	end
	self._trove:Destroy()
	self.Played:Destroy()
	self.Stopped:Destroy()
end

return Controller
