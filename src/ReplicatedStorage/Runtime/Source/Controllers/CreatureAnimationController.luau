local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packets = require(ReplicatedStorage.Modules.CreatureAnimationPackets)

local CREATURE_TAG = "ServerCreatures"
local LOAD_TIMEOUT = 10
local DRIFT_CHECK_INTERVAL = 10
local MAX_DRIFT = 0.15
local SYNCHRONIZED_LOOPED_ATTRIBUTE = "SynchronizedAnimationLooped"

local CreatureAnimationController = {
	Name = "CreatureAnimationController",
	Active = {},
}

local function getAnimation(creature)
	local animation = creature:FindFirstChild("Animation", true)
	return if animation and animation:IsA("Animation") then animation else nil
end

local function getAnimator(creature)
	local humanoid = creature:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		local animator = humanoid:FindFirstChildWhichIsA("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	local controller = creature:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = creature
	end

	local animator = controller:FindFirstChildWhichIsA("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return animator
end

local function getExpectedPosition(track, startedAt, speed)
	local elapsed = math.max(Workspace:GetServerTimeNow() - startedAt, 0) * speed
	if track.Looped and track.Length > 0 then
		return elapsed % track.Length
	end
	return math.min(elapsed, track.Length)
end

local function getCircularDrift(current, expected, length)
	local difference = math.abs(current - expected)
	if length > 0 then
		difference = math.min(difference, length - difference)
	end
	return difference
end

function CreatureAnimationController:_cleanup(creature)
	local active = self.Active[creature]
	if not active then
		return
	end

	self.Active[creature] = nil
	if active.DestroyingConnection then
		active.DestroyingConnection:Disconnect()
	end
	for _, connection in active.MarkerConnections do
		connection:Disconnect()
	end
	active.Track:Stop(0)
	active.Track:Destroy()
end

function CreatureAnimationController:_connectCreatureEvents(creature, track, active)
	if not creature:GetAttribute("Events") or creature.Name ~= "HarlequinSmiler" then
		return
	end

	for _, markerName in { "SandSpitA", "SandSpitB" } do
		local emitter = creature:FindFirstChild(markerName, true)
		if emitter and emitter:IsA("ParticleEmitter") then
			table.insert(
				active.MarkerConnections,
				track:GetMarkerReachedSignal(markerName):Connect(function()
					emitter:Emit(10)
				end)
			)
		end
	end
end

function CreatureAnimationController:_start(entry)
	local creature = entry.creature
	if not creature or not creature:IsA("Model") or not CollectionService:HasTag(creature, CREATURE_TAG) then
		return
	end

	local existing = self.Active[creature]
	if existing and existing.StartedAt == entry.startedAt and existing.Speed == entry.speed then
		return
	end
	self:_cleanup(creature)

	local animation = getAnimation(creature)
	if not animation then
		return
	end

	local ok, track = pcall(function()
		return getAnimator(creature):LoadAnimation(animation)
	end)
	if not ok then
		warn("Failed to load synchronized creature animation for " .. creature.Name .. ": " .. tostring(track))
		return
	end

	local synchronizedLooped = creature:GetAttribute(SYNCHRONIZED_LOOPED_ATTRIBUTE)
	if typeof(synchronizedLooped) == "boolean" then
		track.Looped = synchronizedLooped
	end

	local active = {
		Track = track,
		StartedAt = entry.startedAt,
		Speed = entry.speed,
		MarkerConnections = {},
		DestroyingConnection = nil,
	}
	self.Active[creature] = active
	active.DestroyingConnection = creature.Destroying:Connect(function()
		self:_cleanup(creature)
	end)

	track:Play(0)
	track:AdjustSpeed(entry.speed)
	self:_connectCreatureEvents(creature, track, active)

	task.spawn(function()
		local deadline = os.clock() + LOAD_TIMEOUT
		while self.Active[creature] == active and track.Length <= 0 and os.clock() < deadline do
			RunService.Heartbeat:Wait()
		end
		if self.Active[creature] ~= active or track.Length <= 0 then
			return
		end

		track.TimePosition = getExpectedPosition(track, entry.startedAt, entry.speed)

		while self.Active[creature] == active do
			task.wait(DRIFT_CHECK_INTERVAL)
			if self.Active[creature] ~= active or track.Length <= 0 then
				break
			end

			local expected = getExpectedPosition(track, entry.startedAt, entry.speed)
			if getCircularDrift(track.TimePosition, expected, track.Length) > MAX_DRIFT then
				track.TimePosition = expected
			end
		end
	end)
end

function CreatureAnimationController:Setup()
	Packets.Sync.listen(function(entries)
		for _, entry in entries do
			self:_start(entry)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(CREATURE_TAG):Connect(function(creature)
		self:_cleanup(creature)
	end)
end

function CreatureAnimationController:GameStart()
	Packets.Ready.send()
end

return CreatureAnimationController
