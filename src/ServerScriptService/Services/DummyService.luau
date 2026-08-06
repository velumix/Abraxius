--!strict
-- @author Velumix
-- @version 0.0.1
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BehaviorTree = require(ServerScriptService.AI.BehaviorTree)
local Knit = require(ReplicatedStorage.Modules.Knit)
local Trove = require(ReplicatedStorage.Modules.Trove)

local DUMMY_TAG = "Dummy"
local WANDER_RADIUS = 18
local WALK_SPEED = 7
local THINK_INTERVAL = 0.1
local THREAT_MEMORY = 15

type Blackboard = BehaviorTree.Blackboard & {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Origin: Vector3,
	Target: Player?,
	ThreatExpires: number,
	NextWanderAt: number,
	NextCombatMove: number,
	AimJoint: AnimationConstraint?,
}

local DummyService = Knit.CreateService({
	Name = "DummyService",
	Client = {},
})

DummyService._trove = Trove.new()
DummyService._random = Random.new()
DummyService._agents = {} :: { [Model]: Blackboard }

local function targetIsValid(blackboard: Blackboard): boolean
	local target = blackboard.Target
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return target ~= nil
		and target.Parent == Players
		and os.clock() < blackboard.ThreatExpires
		and humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
end

local function equipPistol(blackboard: Blackboard)
	if blackboard.Model:FindFirstChild("M45") then
		return
	end
	local source = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Pistols")
		and ReplicatedStorage.Assets.Pistols:FindFirstChild("M45")
	if not source or not source:IsA("Tool") then
		return
	end
	local tool = source:Clone()
	local legacy = tool:FindFirstChild("ClientHandler")
	if legacy and legacy:IsA("LocalScript") then
		legacy.Enabled = false
	end
	tool.Parent = blackboard.Model
end

local function faceAndAim(blackboard: Blackboard): string
	local target = blackboard.Target
	local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not targetRoot:IsA("BasePart") then
		return BehaviorTree.Status.Failure
	end
	blackboard.Humanoid.AutoRotate = false
	local offset = targetRoot.Position - blackboard.Root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > 0.01 then
		blackboard.Root.CFrame = CFrame.lookAt(blackboard.Root.Position, blackboard.Root.Position + flat.Unit)
	end
	local joint = blackboard.AimJoint
	local upperTorso = blackboard.Model:FindFirstChild("UpperTorso")
	if joint and joint.IsKinematic and upperTorso and upperTorso:IsA("BasePart") then
		local look = (targetRoot.Position - upperTorso.Position).Unit
		local localLook = upperTorso.CFrame:VectorToObjectSpace(look)
		local pitch = math.asin(math.clamp(localLook.Y, -1, 1))
		local yaw = math.atan2(-localLook.X, -localLook.Z)
		joint.Transform = CFrame.Angles(pitch, yaw, 0)
	end
	equipPistol(blackboard)
	return BehaviorTree.Status.Success
end

function DummyService:_createTree()
	return BehaviorTree.Selector({
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(blackboard)
				return targetIsValid(blackboard :: Blackboard)
			end),
			BehaviorTree.Action(function(blackboard)
				return faceAndAim(blackboard :: Blackboard)
			end),
			BehaviorTree.Action(function(rawBlackboard)
				local blackboard = rawBlackboard :: Blackboard
				local target = blackboard.Target
				local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if not targetRoot or not targetRoot:IsA("BasePart") then
					return BehaviorTree.Status.Failure
				end
				if os.clock() >= blackboard.NextCombatMove then
					local side = if self._random:NextNumber() < 0.5 then -1 else 1
					local strafe = targetRoot.CFrame.RightVector * side * self._random:NextNumber(5, 9)
					local toward = targetRoot.Position - blackboard.Root.Position
					local flatToward = Vector3.new(toward.X, 0, toward.Z)
					local depth = if flatToward.Magnitude > 0.01
						then flatToward.Unit * self._random:NextNumber(-2, 3)
						else Vector3.zero
					blackboard.Humanoid:MoveTo(blackboard.Root.Position + strafe + depth)
					blackboard.NextCombatMove = os.clock() + self._random:NextNumber(1.1, 2)
				end
				local tool = blackboard.Model:FindFirstChild("M45")
				if tool and tool:IsA("Tool") then
					local spread = Vector3.new(
						self._random:NextNumber(-0.3, 0.3),
						self._random:NextNumber(-0.2, 0.35),
						self._random:NextNumber(-0.3, 0.3)
					)
					self._weaponService:FireNPC(blackboard.Model, tool, targetRoot.Position + spread)
				end
				return BehaviorTree.Status.Running
			end),
		}),
		BehaviorTree.Action(function(rawBlackboard)
			local blackboard = rawBlackboard :: Blackboard
			blackboard.Humanoid.AutoRotate = true
			if blackboard.AimJoint and blackboard.AimJoint.IsKinematic then
				blackboard.AimJoint.Transform = CFrame.identity
			end
			if os.clock() < blackboard.NextWanderAt then
				return BehaviorTree.Status.Running
			end
			local offset = Vector3.new(
				self._random:NextNumber(-WANDER_RADIUS, WANDER_RADIUS),
				0,
				self._random:NextNumber(-WANDER_RADIUS, WANDER_RADIUS)
			)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { blackboard.Model }
			local ground =
				workspace:Raycast(blackboard.Origin + offset + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
			if ground then
				blackboard.Humanoid:MoveTo(ground.Position)
			end
			blackboard.NextWanderAt = os.clock() + self._random:NextNumber(2.5, 5)
			return BehaviorTree.Status.Running
		end),
	})
end

function DummyService:_startDummy(model: Instance)
	if not model:IsA("Model") or self._agents[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local rightUpperArm = model:FindFirstChild("RightUpperArm")
	local aimJoint = rightUpperArm and rightUpperArm:FindFirstChild("RightShoulder")
	local blackboard: Blackboard = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Origin = root.Position,
		Target = nil,
		ThreatExpires = 0,
		NextWanderAt = 0,
		NextCombatMove = 0,
		AimJoint = if aimJoint and aimJoint:IsA("AnimationConstraint") then aimJoint else nil,
	}
	self._agents[model] = blackboard
	humanoid.WalkSpeed = WALK_SPEED
	local tree = self:_createTree()
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 and not model:GetAttribute("WeaponRagdolled") do
			tree:Tick(blackboard, THINK_INTERVAL)
			task.wait(THINK_INTERVAL)
		end
		self._agents[model] = nil
	end)
end

function DummyService:KnitStart()
	local weaponService = Knit.GetService("WeaponService")
	self._weaponService = weaponService
	self._trove:Add(weaponService.CharacterHit:Connect(function(player, character)
		local blackboard = self._agents[character]
		if blackboard then
			blackboard.Target = player
			blackboard.ThreatExpires = os.clock() + THREAT_MEMORY
			print("[DummyAI] Threat acquired", character:GetFullName(), player.Name)
		end
	end))
	self._trove:Add(CollectionService:GetInstanceAddedSignal(DUMMY_TAG):Connect(function(instance)
		self:_startDummy(instance)
	end))
	for _, instance in CollectionService:GetTagged(DUMMY_TAG) do
		self:_startDummy(instance)
	end
	local rig = workspace:FindFirstChild("Rig")
	if rig then
		self:_startDummy(rig)
	end
	self._trove:Add(RunService.PreSimulation:Connect(function()
		for _, blackboard in self._agents do
			if targetIsValid(blackboard) and blackboard.AimJoint then
				faceAndAim(blackboard)
			end
		end
	end))
end

function DummyService:Destroy()
	table.clear(self._agents)
	self._trove:Destroy()
end

return DummyService
