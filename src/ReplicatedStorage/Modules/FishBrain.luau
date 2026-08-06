local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishBehavior = require(ReplicatedStorage.Modules.FishBehaviour)

local Fish = {}
Fish.Storage = {}
Fish.Boids = {}
Fish.FishGroup = nil

local function hasValidAnimationId(animation)
	if not animation or not animation:IsA("Animation") then
		return false
	end

	local animationId = animation.AnimationId
	return typeof(animationId) == "string"
		and animationId ~= ""
		and animationId ~= "0"
		and animationId ~= "rbxassetid://0"
		and not animationId:match("[?&]id=0$")
end

function Fish:SetData(data)
	self.Parent = data.Parent
	self.Region = data.Region
	self.FishModel = data.FishModel
	self.SchoolSize = data.SchoolSize
	self.SwimmingSpeed = data.SwimmingSpeed
	self.AnimationSpeed = data.AnimationSpeed
	self.MinimumCrowdDistance = data.MinimumCrowdDistance
	self.AlignWeight = data.AlignWeight
	self.SeperateWeight = data.SeperateWeight
	self.CohesionWeight = data.CohesionWeight
	self.AvoidanceWeight = data.AvoidanceWeight
	self.TargetWeight = data.TargetWeight
	self.MaxSteerForce = data.MaxSteerForce
	self.NeighborDist = data.NeighborDist
	self.RayLength = data.RayLength
	self.TimeToMove = data.TimeToMove
	self.Goal = data.Goal
	self.SwimmingAnimation = nil
end

function Fish:GetSafeSpawnPoint()
	local spawnPoint = self.Parent.Position

	if self.Limits and #self.Limits > 0 then
		local minX, maxX = math.huge, -math.huge
		local minY, maxY = math.huge, -math.huge
		local minZ, maxZ = math.huge, -math.huge

		for _, limit in ipairs(self.Limits) do
			local pos = limit.Position
			local size = limit.Size

			minX = math.min(minX, pos.X - size.X / 2)
			maxX = math.max(maxX, pos.X + size.X / 2)
			minY = math.min(minY, pos.Y - size.Y / 2)
			maxY = math.max(maxY, pos.Y + size.Y / 2)
			minZ = math.min(minZ, pos.Z - size.Z / 2)
			maxZ = math.max(maxZ, pos.Z + size.Z / 2)
		end

		local padding = 3
		spawnPoint = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)

		spawnPoint = Vector3.new(
			math.max(minX + padding, math.min(maxX - padding, spawnPoint.X)),
			math.max(minY + padding, math.min(maxY - padding, spawnPoint.Y)),
			math.max(minZ + padding, math.min(maxZ - padding, spawnPoint.Z))
		)
	end

	return spawnPoint
end

function Fish:Start(node, limits)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.Parent }
	params.RespectCanCollide = true

	if not node then
		warn("No node provided")
		return
	end

	local Attributes = node:GetAttributes()

	self.Align = self.AlignWeight or Attributes.Align or 0.5
	self.Seperate = self.SeperateWeight or Attributes.Seperate or 0.6
	self.Cohesion = self.CohesionWeight or Attributes.Cohesion or 0.1
	self.Avoidance = self.AvoidanceWeight or Attributes.Avoidance or 100
	self.TargetSeek = self.TargetWeight or Attributes.TargetWeight or 1
	self.MaxSteer = self.MaxSteerForce or Attributes.MaxSteerForce or 30
	self.NeighborDistance = self.NeighborDist or Attributes.NeighborDist or 50
	self.Raylength = self.RayLength or Attributes.RayLength or 5
	self.Target = self.Goal or Attributes.Target
	self.Goal = self.Goal or Attributes.Target
	self.TargetNode = node

	self.TargetNodePosition = node.Position

	local FishGroup = FishBehavior.new(
		self.SwimmingSpeed.Min,
		self.SwimmingSpeed.Max,
		self.MinimumCrowdDistance,
		self.Align,
		self.Seperate,
		self.TargetSeek,
		self.Raylength
	)

	FishGroup.RaycastParams = params
	FishGroup.TargetPosition = self.Goal or self.TargetNodePosition
	FishGroup._SchoolRadius = math.max(10, self.SchoolSize * 2)
	FishGroup.ALIGN_WEIGHT = self.Align
	FishGroup.SEPARATION_WEIGHT = self.Seperate
	FishGroup.COHESION_WEIGHT = self.Cohesion
	FishGroup.AVOIDANCE_WEIGHT = self.Avoidance
	FishGroup.TARGET_WEIGHT = self.TargetSeek
	FishGroup.MAX_STEER_FORCE = self.MaxSteer
	FishGroup.NEIGHBOR_DIST = self.NeighborDistance
	FishGroup.RAY_LENGTH = self.Raylength
	FishGroup.Node = self.TargetNode

	self.FishGroup = FishGroup
	self.FishGroup.Limits = limits
	self.Limits = limits

	local spawnPoint = self:GetSafeSpawnPoint()

	for i = 1, self.SchoolSize do
		if not self.FishModel then
			warn("Fish model is missing", self.Parent)
			return
		end

		local newFish = self.FishModel:Clone()
		newFish.Name = i

		local primaryPart = newFish.PrimaryPart or newFish:FindFirstChildWhichIsA("BasePart")
		if not primaryPart then
			warn("Fish model has no BasePart", newFish)
			newFish:Destroy()
			continue
		end

		newFish.PrimaryPart = primaryPart

		local clusterOffset = Vector3.new(math.random(-1, 1) * 0.5, math.random(-1, 1) * 0.2, math.random(-1, 1) * 0.5)
		newFish.PrimaryPart.CFrame = CFrame.new(spawnPoint + clusterOffset)
		newFish.Parent = self.Parent

		CollectionService:AddTag(newFish, "Fish")
		FishBehavior.RegisterFishInstance(newFish)
		local MainPart = newFish.PrimaryPart

		table.insert(FishGroup.RaycastParams.FilterDescendantsInstances, newFish)

		local fish = FishBehavior.CreateFish(newFish)
		FishGroup:AddFish(fish)

		local Animation = MainPart:FindFirstChild("Animation")
		if hasValidAnimationId(Animation) then
			local animationController = MainPart:FindFirstChild("AnimationController")
			local animator = animationController and animationController:FindFirstChildOfClass("Animator")
			if not animator then
				warn("Fish model missing AnimationController/Animator", newFish)
				FishBehavior.RegisterAnimationTracks(newFish, {})
				self.Storage[i] = {
					Fish = fish,
					Model = newFish,
					Animation = nil,
				}
				continue
			end

			local swimmingAnimation = animator:LoadAnimation(Animation)

			swimmingAnimation:AdjustSpeed(math.random(self.AnimationSpeed.Min, self.AnimationSpeed.Max))

			swimmingAnimation:Play()

			local tracks = {}
			for _, obj in pairs(newFish:GetDescendants()) do
				if obj:IsA("AnimationTrack") then
					table.insert(tracks, obj)
				end
			end
			FishBehavior.RegisterAnimationTracks(newFish, tracks)

			self.Storage[i] = {
				Fish = fish,
				Model = newFish,
				Animation = swimmingAnimation,
			}
		else
			local tracks = {}
			for _, obj in pairs(newFish:GetDescendants()) do
				if obj:IsA("AnimationTrack") then
					table.insert(tracks, obj)
				end
			end
			FishBehavior.RegisterAnimationTracks(newFish, tracks)

			self.Storage[i] = {
				Fish = fish,
				Model = newFish,
				Animation = nil,
			}
		end
	end

	FishBehavior.RegisterGroup(FishGroup, self)
end

function Fish:Stop()
	FishBehavior.UnregisterGroup(self.FishGroup)
	for _, object in self.Storage do
		if object.Animation then
			object.AnimationSpeed = object.Animation.Speed
			object.Animation:AdjustSpeed(0)
		end
	end
end

function Fish:Resume()
	FishBehavior.RegisterGroup(self.FishGroup, self)
	for _, object in self.Storage do
		if object.Animation then
			object.Animation:AdjustSpeed(object.AnimationSpeed or 1)
			object.AnimationSpeed = nil
		end
	end
end

function Fish:Destroy()
	FishBehavior.UnregisterGroup(self.FishGroup)

	for _, object in self.Storage do
		self.FishGroup:RemoveFish(object.Fish)
		FishBehavior.UnregisterFishInstance(object.Model)
		object.Model:Destroy()
	end

	self.FishGroup = nil

	table.clear(self.Storage)
end

return Fish
