local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local SharkTail = require(script.Physics.SharkTail)
local StandardTail = require(script.Physics.StandardTail)

local ActiveTails = {}
local SMOOTHING_SPEED = 10

local Tail = Mince.Component {
	Tag = "Tail",
	CreationParents = { workspace },
}

local function isUsingSingleDPV(character)
	if not (character and character:IsA("Model")) then
		return false
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			if child.Name == "Scooter" or CollectionService:HasTag(child, "SingleDPV") then
				return true
			end
		end
	end
	return false
end

function Tail:Construct()
	self.Model = self.Instance
	self.Character = self.Instance.Parent

	if not (self.Character and self.Character:IsA("Model")) then
		return
	end

	self.LowerTorso = self.Character:FindFirstChild("LowerTorso")

	self.RenderStepped = RunService.RenderStepped:Connect(function(dt)
		self:_OnRenderStepped(dt)
	end)

	task.spawn(function()
		if not self.LowerTorso then
			repeat task.wait(0.1)
			until self.Character:FindFirstChild("LowerTorso")
			self.LowerTorso = self.Character:FindFirstChild("LowerTorso")
		end

		self.RootPart = self.Character:FindFirstChild("HumanoidRootPart")
		if not self.RootPart then
			repeat task.wait(0.1)
			until self.Character:FindFirstChild("HumanoidRootPart")
			self.RootPart = self.Character:FindFirstChild("HumanoidRootPart")
		end

		if not self.LowerTorso or not self.RootPart then
			return
		end

		self.Humanoid = self.Character:FindFirstChild("Humanoid")
		self:_SetupBones()
		self:_SetupWeld()
		self:_SetupAnimations()
		self:_SetupInfluence()
		self:_SetupCleanup()

		ActiveTails[self] = true
	end)
end

function Tail:_SetupCleanup()
	self.Instance.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then
			self:Destruct()
		end
	end)

	if self.Character then
		self.Character.AncestryChanged:Connect(function(_, newParent)
			if newParent == nil then
				self:Destruct()
			end
		end)
	end
end

function Tail:_SetupInfluence()
	local tailType = self.Instance:GetAttribute("TailType") or "Standard"
	if tailType == "Shark" then
		self.Influence = SharkTail.new(self)
	else
		self.Influence = StandardTail.new(self)
	end
end

function Tail:_SetupBones()
	self.PrimaryPart = self.Instance:FindFirstChildWhichIsA("BasePart")
	if not self.PrimaryPart then
		warn("Missing PrimaryPart on " .. self.Instance.Name)
		return
	end

	self.BoneChain = {}
	local startBone = self.PrimaryPart:FindFirstChild("Bone") or 
		self.PrimaryPart:FindFirstChild("Bone.001") or 
		self.PrimaryPart:FindFirstChildWhichIsA("Bone")

	if startBone then
		table.insert(self.BoneChain, startBone)
		for _, bone in ipairs(startBone:GetDescendants()) do
			if bone:IsA("Bone") then
				table.insert(self.BoneChain, bone)
			end
		end
		table.sort(self.BoneChain, function(a, b)
			return a.Name < b.Name
		end)
	end

	self.BoneBaseCFrames = {}
	for _, bone in ipairs(self.BoneChain) do
		self.BoneBaseCFrames[bone] = bone.CFrame
	end
end

function Tail:_SetupWeld()
	if not (self.Humanoid and self.LowerTorso and self.PrimaryPart) then return end

	local rigidConstraint = self.PrimaryPart:FindFirstChild("RigidConstraint")
	if rigidConstraint then
		local rootAttachment = self.RootPart and self.RootPart:FindFirstChild("RootRigAttachment")
		if rootAttachment then
			rigidConstraint.Attachment0 = rootAttachment
			self.PrimaryPart.Anchored = false
			rigidConstraint.Enabled = true

			local weld = Instance.new("WeldConstraint")
			weld.Name = "TailWeld"
			weld.Part0 = self.PrimaryPart
			weld.Part1 = self.LowerTorso
			weld.Parent = self.PrimaryPart

			self.Weld = weld
			rigidConstraint:Destroy()
		end
	end
end

function Tail:_SetupAnimations()
	local animationFolder = self.Instance:FindFirstChild("Animations")
	if not animationFolder then return end

	local animationController = self.Instance:FindFirstChildOfClass("AnimationController")
	if not animationController then
		animationController = Instance.new("AnimationController", self.Instance)
	end

	local animator = animationController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator", animationController)
	end

	self.Animations = { Tail = {}, Character = {} }

	local function load(folder, name, targetAnimator)
		local obj = folder:FindFirstChild(name)
		if obj and targetAnimator then
			return targetAnimator:LoadAnimation(obj)
		end
		return nil
	end

	self.Animations.Tail.Idle = load(animationFolder, "TailIdle", animator)
	self.Animations.Tail.Swim = load(animationFolder, "TailSwim", animator)

	if self.Humanoid then
		self.Animations.Character.Idle = load(animationFolder, "CharacterIdle", self.Humanoid)
		self.Animations.Character.Swim = load(animationFolder, "CharacterSwim", self.Humanoid)
	end

	self.CurrentState = "Idle"
end

function Tail:_PlayState(state, speed)
	if not self.Animations then return end
	if self.CurrentState == state then
		self:_UpdateSpeed(speed)
		return
	end

	local fadeTime = 0.25

	for _, anim in pairs(self.Animations.Tail) do
		if anim and anim.IsPlaying then
			anim:Stop(fadeTime)
		end
	end
	for _, anim in pairs(self.Animations.Character) do
		if anim and anim.IsPlaying then
			anim:Stop(fadeTime)
		end
	end

	if self.Animations.Tail[state] then
		self.Animations.Tail[state]:Play(fadeTime)
		self.Animations.Tail[state]:AdjustSpeed(speed or 1)
	end
	if self.Animations.Character[state] then
		self.Animations.Character[state]:Play(fadeTime)
		self.Animations.Character[state]:AdjustSpeed(speed or 1)
	end

	self.CurrentState = state
	self.CurrentSpeed = speed or 1
end

function Tail:_UpdateSpeed(speed)
	if not self.Animations then return end
	speed = speed or 1
	if self.CurrentSpeed == speed then return end
	self.CurrentSpeed = speed

	for _, anim in pairs(self.Animations.Tail) do
		if anim and anim.IsPlaying then
			anim:AdjustSpeed(speed)
		end
	end
	for _, anim in pairs(self.Animations.Character) do
		if anim and anim.IsPlaying then
			anim:AdjustSpeed(speed)
		end
	end
end

function Tail:_OnRenderStepped(dt)
	if dt > 0.1 then dt = 0.016 end

	if not self.Character or not self.Instance:IsDescendantOf(self.Character) then
		self:StopAllAnimations(0)
		return
	end

	if not self.RootPart or not self.Influence then return end

	local player = Players:GetPlayerFromCharacter(self.Character)
	local isSwimming = player and player:GetAttribute("Swimming") == true
	local gearsVisible = player and player:GetAttribute("ShowGearInObservatory") == true
	local usingDoubleDPV = player and player:GetAttribute("UsingDoubleDPV") == true
	local usingSingleDPV = isUsingSingleDPV(self.Character)

	local shouldAnimate = isSwimming or gearsVisible

	if not shouldAnimate then
		self:StopAllAnimations(0)
		if self.BoneChain and self.BoneBaseCFrames then
			for _, bone in ipairs(self.BoneChain) do
				if bone and self.BoneBaseCFrames[bone] then
					bone.CFrame = self.BoneBaseCFrames[bone]
				end
			end
		end
		self.SmoothedInfluence = nil
		return
	end

	local velocity = self.RootPart.AssemblyLinearVelocity
	local speed = velocity.Magnitude

	local targetState = "Idle"
	local animSpeed = 1

	if speed > 0.5 then
		targetState = "Swim"
		animSpeed = math.clamp(0.5 + (speed / 10), 0.5, 2.0)
	else
		targetState = "Idle"
		animSpeed = 1
	end

	if usingDoubleDPV or usingSingleDPV then
		animSpeed = animSpeed * 0.3
	end

	self:_PlayState(targetState, animSpeed)

	local angularVelocity = self.RootPart.AssemblyAngularVelocity
	local influence = self.Influence:Calculate(dt, speed, velocity, angularVelocity, isSwimming)
	self:_ApplyInfluence(influence, dt)
end

function Tail:_ApplyInfluence(influence, dt)
	if not self.BoneChain or #self.BoneChain == 0 then return end
	if not self.BoneBaseCFrames then return end

	self.SmoothedInfluence = self.SmoothedInfluence or {Pitch = 0, Yaw = 0, Roll = 0}

	local alpha = 1 - math.exp(-SMOOTHING_SPEED * dt)
	self.SmoothedInfluence.Pitch += ((influence.Pitch or 0) - self.SmoothedInfluence.Pitch) * alpha
	self.SmoothedInfluence.Yaw += ((influence.Yaw or 0) - self.SmoothedInfluence.Yaw) * alpha
	self.SmoothedInfluence.Roll += ((influence.Roll or 0) - self.SmoothedInfluence.Roll) * alpha

	for i, bone in ipairs(self.BoneChain) do
		if not bone then continue end
		local denom = math.max(#self.BoneChain - 1, 1)
		local t = (i - 1) / denom
		local rootBend = influence.RootBend or 0.3
		local influenceFactor = rootBend + (1 - rootBend) * (t * t * t)
		local pitch = self.SmoothedInfluence.Pitch * influenceFactor
		local yaw = self.SmoothedInfluence.Yaw * influenceFactor
		local roll = self.SmoothedInfluence.Roll * influenceFactor
		local offset = CFrame.Angles(pitch, yaw, roll)
		local baseCFrame = self.BoneBaseCFrames[bone]
		if baseCFrame then
			bone.CFrame = baseCFrame * offset
		end
	end
end

function Tail:StopAllAnimations(fadeTime)
	fadeTime = fadeTime or 0
	if not self.Animations then return end
	for _, anim in pairs(self.Animations.Tail) do
		if anim then anim:Stop(fadeTime) end
	end
	for _, anim in pairs(self.Animations.Character) do
		if anim then anim:Stop(fadeTime) end
	end
end

function Tail:Destruct()
	if self.Destroyed then return end
	self.Destroyed = true

	if self.RenderStepped then
		self.RenderStepped:Disconnect()
		self.RenderStepped = nil
	end
	ActiveTails[self] = nil
	self:StopAllAnimations(0)
end

return Tail
