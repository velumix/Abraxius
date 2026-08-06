local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))

local PaintBucketAI = {}
PaintBucketAI.__index = PaintBucketAI

local ATTACK_RANGE = 5
local ATTACK_COOLDOWN = 1.2
local SEARCH_RADIUS = 1000
local WALK_SPEED = 12
local TICK_RATE = 0.15

function PaintBucketAI.new(bucketModel: Model)
	local self = setmetatable({}, PaintBucketAI)
	self.model = bucketModel
	self.humanoid = bucketModel:FindFirstChildOfClass("Humanoid")
	if self.humanoid then
		self.humanoid.WalkSpeed = WALK_SPEED
		self.humanoid.HipHeight = 0
	else
		warn("[PaintBucketAI] bucket model has no Humanoid, AI will not move.")
	end
	self.running = false
	self.thread = nil
	self.lastAttack = 0
	return self
end

function PaintBucketAI:start()
	if self.running then
		return
	end
	if not self.humanoid then
		return
	end
	self.running = true
	self.thread = task.spawn(function()
		while self.running do
			self:_tick()
			task.wait(TICK_RATE)
		end
	end)
end

function PaintBucketAI:stop()
	self.running = false
	if self.thread then
		task.cancel(self.thread)
		self.thread = nil
	end
	if self.humanoid then
		self.humanoid:MoveTo(self.model:GetPivot().Position)
	end
end

function PaintBucketAI:_tick()
	local root = self.model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local target = self:_findNearestPlayer(root.Position)
	if not target then
		self.humanoid:MoveTo(root.Position)
		return
	end

	local character = target.Character
	if not character then
		return
	end

	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
	if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end

	local distance = (targetRoot.Position - root.Position).Magnitude
	if distance <= ATTACK_RANGE then
		self:_attack(targetHumanoid, root.Position)
		self.humanoid:MoveTo(root.Position)
		return
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 1.4,
		AgentHeight = 4,
		AgentCanJump = false,
		AgentCanClimb = false,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, targetRoot.Position)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints >= 2 then
			self.humanoid:MoveTo(waypoints[2].Position)
		else
			self.humanoid:MoveTo(targetRoot.Position)
		end
	else
		self.humanoid:MoveTo(targetRoot.Position)
	end
end

function PaintBucketAI:_findNearestPlayer(position: Vector3): Player?
	local nearest: Player? = nil
	local nearestDist = SEARCH_RADIUS

	for _, player in ipairs(Players:GetPlayers()) do
		if ModifierUtils.getRole(player) ~= "Hider" then
			continue
		end

		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local dist = (root.Position - position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearest = player
				end
			end
		end
	end

	return nearest
end

function PaintBucketAI:_attack(humanoid: Humanoid, position: Vector3)
	local now = os.clock()
	if now - self.lastAttack < ATTACK_COOLDOWN then
		return
	end
	self.lastAttack = now

	humanoid:TakeDamage(100)
	self:_splashVisual(position)
end

function PaintBucketAI:_splashVisual(position: Vector3)
	local puddle = Instance.new("Part")
	puddle.Name = "PaintBucketSplash"
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Size = Vector3.new(0.2, 8, 8)
	puddle.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Anchored = true
	puddle.CanCollide = false
	puddle.CanQuery = false
	puddle.CanTouch = false
	puddle.Color = self.model:GetAttribute("PaintColor") or Color3.fromRGB(255, 40, 80)
	puddle.Material = Enum.Material.Neon
	puddle.Transparency = 0.3
	puddle.Parent = Workspace

	TweenService:Create(
		puddle,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, 16, 16), Transparency = 1 }
	):Play()

	task.delay(0.5, function()
		if puddle and puddle.Parent then
			puddle:Destroy()
		end
	end)
end

return PaintBucketAI
