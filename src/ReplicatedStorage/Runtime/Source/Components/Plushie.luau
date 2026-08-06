local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Player = Players.LocalPlayer

local PlushieTool = Mince.Component {Tag = "Plushie", CreationParents = {workspace}}

local ANIMATION_NAMES = {
	Holdout = {"PlushHoldout", "Holdout"},
	Start = {"PlushStart", "Start"},
	Loop = {"PlushLoop", "Loop"},
	End = {"PlushEnd", "End"},
}

local LOOP_OVERLAP = 0.1
local HOLDOUT_OVERLAP = 0.1

function PlushieTool:LoadAnimations()
	local tool = self.Instance
	local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animationsFolder = tool:FindFirstChild("Animations")
	if not animationsFolder then
		return
	end

	self:UnloadAnimations()

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local loadTarget = animator or humanoid

	for key, nameList in pairs(ANIMATION_NAMES) do
		for _, name in ipairs(nameList) do
			local animation = animationsFolder:FindFirstChild(name)
			if animation and animation:IsA("Animation") then
				local track = loadTarget:LoadAnimation(animation)
				self.LoadedAnimations[key] = track
				break
			end
		end
	end

	local loopTrack = self.LoadedAnimations.Loop
	if loopTrack then
		loopTrack.Looped = true
	end
end

function PlushieTool:UnloadAnimations()
	for _, track in pairs(self.LoadedAnimations) do
		if track and track.IsPlaying then
			track:Stop()
		end
		if track then
			track:Destroy()
		end
	end
	self.LoadedAnimations = {}
end

function PlushieTool:PlayHoldout()
	local holdout = self.LoadedAnimations.Holdout
	if holdout and not holdout.IsPlaying then
		holdout:Play(0, 1, 1)
	end
end

function PlushieTool:StopHoldout()
	local holdout = self.LoadedAnimations.Holdout
	if holdout and holdout.IsPlaying then
		holdout:Stop(0)
	end
end

function PlushieTool:StopAllAnimations()
	for _, track in pairs(self.LoadedAnimations) do
		if track and track.IsPlaying then
			track:Stop(0)
		end
	end
end

function PlushieTool:FinishActivation()
	self.State = "Idle"
	self:PlayHoldout()
end

function PlushieTool:BeginLoop()
	self.State = "Looping"
	local loopTrack = self.LoadedAnimations.Loop
	if loopTrack then
		loopTrack:Play(0, 1, 1)
	else
		self:FinishActivation()
	end
end

function PlushieTool:BeginEnd()
	if self.State == "Ending" then
		return
	end
	self.State = "Ending"

	local endTrack = self.LoadedAnimations.End
	if endTrack then
		if self.Connections.Ended then
			self.Connections.Ended:Disconnect()
		end
		self.Connections.Ended = endTrack.Ended:Connect(function()
			if self.Connections.Ended then
				self.Connections.Ended:Disconnect()
				self.Connections.Ended = nil
			end
			self:FinishActivation()
		end)
		endTrack:Play(0, 1, 1)
		self:QueueHoldout()
		local startTrack = self.LoadedAnimations.Start
		if startTrack and startTrack.IsPlaying then
			startTrack:Stop(0)
		end

		local loopTrack = self.LoadedAnimations.Loop
		if loopTrack and loopTrack.IsPlaying then
			loopTrack:Stop(0)
		end
	else
		self:FinishActivation()
	end
end

function PlushieTool:QueueLoop()
	local startTrack = self.LoadedAnimations.Start
	if not startTrack then
		self:BeginLoop()
		return
	end

	local duration = startTrack.Length or 0
	local delayTime = math.max(0, duration - LOOP_OVERLAP)
	if self.Connections.LoopDelay then
		task.cancel(self.Connections.LoopDelay)
		self.Connections.LoopDelay = nil
	end

	self.Connections.LoopDelay = task.delay(delayTime, function()
		self.Connections.LoopDelay = nil
		if self.State == "Starting" then
			self:BeginLoop()
		end
	end)
end

function PlushieTool:QueueHoldout()
	local endTrack = self.LoadedAnimations.End
	if not endTrack then
		self:FinishActivation()
		return
	end

	local duration = endTrack.Length or 0
	local delayTime = math.max(0, duration - HOLDOUT_OVERLAP)
	if self.Connections.HoldoutDelay then
		task.cancel(self.Connections.HoldoutDelay)
		self.Connections.HoldoutDelay = nil
	end

	self.Connections.HoldoutDelay = task.delay(delayTime, function()
		self.Connections.HoldoutDelay = nil
		if self.State == "Ending" then
			self:PlayHoldout()
		end
	end)
end

function PlushieTool:OnActivated()
	if self.State == "Idle" then
		self.State = "Starting"
		self:StopHoldout()

		local startTrack = self.LoadedAnimations.Start
		if startTrack then
			if self.Connections.Started then
				self.Connections.Started:Disconnect()
			end
			self.Connections.Started = startTrack.Ended:Connect(function()
				if self.Connections.Started then
					self.Connections.Started:Disconnect()
					self.Connections.Started = nil
				end
			end)
			startTrack:Play(0, 1, 1)
			self:QueueLoop()
		else
			self:BeginLoop()
		end
		return
	end

	if self.State == "Starting" or self.State == "Looping" then
		if self.Connections.LoopDelay then
			task.cancel(self.Connections.LoopDelay)
			self.Connections.LoopDelay = nil
		end
		self:BeginEnd()
	end
end

function PlushieTool:OnDeactivated()
	-- Intentionally no-op; activation toggles play/stop now.
end

function PlushieTool:OnEquipped()
	self.State = "Idle"
	self:LoadAnimations()
	self:PlayHoldout()
end

function PlushieTool:OnUnequipped()
	self:StopAllAnimations()
	self:UnloadAnimations()
	self.State = "Idle"
	if self.Connections.Started then
		self.Connections.Started:Disconnect()
		self.Connections.Started = nil
	end
	if self.Connections.LoopDelay then
		task.cancel(self.Connections.LoopDelay)
		self.Connections.LoopDelay = nil
	end
	if self.Connections.HoldoutDelay then
		task.cancel(self.Connections.HoldoutDelay)
		self.Connections.HoldoutDelay = nil
	end
	if self.Connections.Ended then
		self.Connections.Ended:Disconnect()
		self.Connections.Ended = nil
	end
end

function PlushieTool:Construct()
	self.CharacterController = Mince:Get("CharacterController")
	self.LoadedAnimations = {}
	self.State = "Idle"
	self.MovementLocked = false
	self.PreviousControlsEnabled = nil
	self.Connections = {}

	self.Connections.Equipped = self.Instance.Equipped:Connect(function()
		self:OnEquipped()
	end)
	self.Connections.Unequipped = self.Instance.Unequipped:Connect(function()
		self:OnUnequipped()
	end)
	self.Connections.Activated = self.Instance.Activated:Connect(function()
		self:OnActivated()
	end)
	self.Connections.Deactivated = self.Instance.Deactivated:Connect(function()
		self:OnDeactivated()
	end)

	self.Connections.CharacterAdded = Player.CharacterAdded:Connect(function()
		self:UnloadAnimations()
		if self.Instance.Parent == Player.Character then
			self:LoadAnimations()
			self:PlayHoldout()
		end
	end)
end

function PlushieTool:Destruct()
	for _, conn in pairs(self.Connections) do
		if conn then
			conn:Disconnect()
		end
	end
	self.Connections = {}
	self:StopAllAnimations()
	self:UnloadAnimations()
end

return PlushieTool
