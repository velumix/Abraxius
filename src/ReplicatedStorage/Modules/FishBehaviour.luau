--!native
--!nocheck
local FISH_DEFAULT_MAX_SPEED = 4
local FISH_DEFAULT_MIN_SPEED = 1
local FISH_DEFAULT_RAY_LENGTH = 8
local FISH_DEFAULT_NEIGHBOR_DIST = 15
local FISH_DEFAULT_CROWDING_DIST = 3
local FISH_DEFAULT_MAX_STEER_FORCE = 15

local FISH_DEFAULT_ALIGN_WEIGHT = 1.0
local FISH_DEFAULT_COHESION_WEIGHT = 1.2
local FISH_DEFAULT_SEPARATION_WEIGHT = 1.4
local FISH_DEFAULT_TARGET_WEIGHT = 0.2
local FISH_DEFAULT_AVOIDANCE_WEIGHT = 15
local FISH_DEFAULT_CONTAINMENT_WEIGHT = 1.5
local FISH_DEFAULT_WANDER_WEIGHT = 0.55
local FISH_DEFAULT_ORBIT_WEIGHT = 0.35

local OBSTACLE_CHECK_INTERVAL = 0.3
local LEADERSHIP_UPDATE_INTERVAL = 2.0
local OCTREE_UPDATE_INTERVAL = 0.1
local NEAR_LOD_DISTANCE = 60
local MID_LOD_DISTANCE = 140
local FAR_LOD_DISTANCE = 220
local MAX_NEAR_NEIGHBORS = 12
local MAX_MID_NEIGHBORS = 6
local MIN_CFRAME_POSITION_DELTA = 0.03
local MIN_CFRAME_LOOK_DELTA = 0.002
local FIELD_DIRECTION_SMOOTH_RATE = 4
local NAVIGATION_TURN_HOLD_TIME = 0.75

local AVOIDANCE_DIRECTIONS = {
	Vector3.new(0, 0, 1),
	Vector3.new(1, 0, 0.5),
	Vector3.new(-1, 0, 0.5),
	Vector3.new(0.7, 0, 0.7),
	Vector3.new(-0.7, 0, 0.7),
}

local ZERO_VECTOR = Vector3.new(0, 0, 0)
local FORWARD_VECTOR = Vector3.new(0, 0, 1)
local MIN_ANIM_SPEED_CHANGE = 0.15
local MAX_BANK_ANGLE = math.rad(12)

local function fastInvSqrt(number)
	return 1 / math.sqrt(number)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packets = require(ReplicatedStorage.Modules.BoidPackets)
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Octree = require(ReplicatedStorage.Modules.Octree)
local BoidNavigation = require(ReplicatedStorage.Modules.BoidNavigation)
local TaskScheduler = Mince.TaskScheduler

local FishTaggedInstances = {}
local FishAnimationTracks = setmetatable({}, { __mode = "k" })
local GlobalCFrameQueue = {}
local VisualCFrameTargets = setmetatable({}, { __mode = "k" })
local NetworkTargets = setmetatable({}, { __mode = "k" })
local RenderStep = RunService.PreRender or RunService.RenderStepped
local updatePerformanceMetrics

local function isFiniteVector(vector)
	return typeof(vector) == "Vector3"
		and vector.X == vector.X
		and vector.Y == vector.Y
		and vector.Z == vector.Z
		and math.abs(vector.X) < math.huge
		and math.abs(vector.Y) < math.huge
		and math.abs(vector.Z) < math.huge
end

RenderStep:Connect(function(deltaTime)
	updatePerformanceMetrics(deltaTime)

	local n = #GlobalCFrameQueue
	if n > 0 then
		for i = 1, n do
			local update = GlobalCFrameQueue[i]
			if update.instance and update.instance.PrimaryPart then
				VisualCFrameTargets[update.instance] = update.cframe
				if update.animSpeed then
					local tracks = FishAnimationTracks[update.instance]
					if tracks then
						for _, track in ipairs(tracks) do
							track:AdjustSpeed(update.animSpeed)
						end
					else
						for _, obj in pairs(update.instance:GetDescendants()) do
							if obj:IsA("AnimationTrack") then
								obj:AdjustSpeed(update.animSpeed)
							end
						end
					end
				end
			end
		end
		table.clear(GlobalCFrameQueue)
	end

	local alpha = math.clamp((deltaTime or 0) * 14, 0, 1)
	for instance, targetCFrame in pairs(VisualCFrameTargets) do
		local primaryPart = instance and instance.PrimaryPart
		if not primaryPart then
			VisualCFrameTargets[instance] = nil
			continue
		end

		local currentCFrame = primaryPart.CFrame
		local positionDelta = (targetCFrame.Position - currentCFrame.Position).Magnitude
		local lookDelta = 1 - math.clamp(targetCFrame.LookVector:Dot(currentCFrame.LookVector), -1, 1)

		if positionDelta < 0.01 and lookDelta < 0.001 then
			primaryPart.CFrame = targetCFrame
			VisualCFrameTargets[instance] = nil
		else
			primaryPart.CFrame = currentCFrame:Lerp(targetCFrame, alpha)
		end
	end
end)

Packets.TargetBatch.listen(function(updates)
	for _, update in updates do
		local node = update.node
		local target = update.target
		if typeof(node) == "Instance" and node:IsA("BasePart") and typeof(target) == "Vector3" then
			NetworkTargets[node] = target
		end
	end
end)

Packets.Ready.send()

local FishGroup = {}
local RegisteredGroups = {}
local RegisteredGroupArray = {}

local FishUpdateScheduler = nil
local FishStepTask = nil
local FishStepCursor = 1
local LastFishStep = 0
local FISH_SIMULATION_RATE = 33
local FISH_SIMULATION_INTERVAL = 1 / FISH_SIMULATION_RATE
local PerformanceProfile = {
	DeviceType = "Desktop",
	TargetFPS = 60,
	CurrentFPS = 60,
	MaxFishPerFrame = 200,
	LastFPSUpdate = 0,
	FPSHistory = {},
}

local function isnan(n)
	return n ~= n or n == math.huge or n == -math.huge
end

local function clamp_magnitude(vector, min, max)
	local m = vector.Magnitude
	if isnan(m) or m ~= m then
		return ZERO_VECTOR
	end
	if m > max then
		return vector.Unit * max
	elseif m < min and m > 0 then
		return vector.Unit * min
	else
		return vector
	end
end

local function isnan_vec3(v)
	return isnan(v.X) or isnan(v.Y) or isnan(v.Z)
end

local function safe_normalize(v)
	if isnan_vec3(v) or v.Magnitude == 0 then
		return FORWARD_VECTOR
	end
	return v.Unit
end

local function safe_vector3(x, y, z)
	x = isnan(x) and 0 or x
	y = isnan(y) and 0 or y
	z = isnan(z) and 0 or z
	return Vector3.new(x, y, z)
end

local function safe_perpendicular(vector)
	local perpendicular = Vector3.new(-vector.Z, 0, vector.X)
	if isnan_vec3(perpendicular) or perpendicular.Magnitude < 0.001 then
		return Vector3.new(1, 0, 0)
	end
	return perpendicular.Unit
end

local function detectDevicePerformance()
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local isConsole = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled

	if isMobile then
		PerformanceProfile.DeviceType = "Mobile"
		PerformanceProfile.TargetFPS = 30
		PerformanceProfile.MaxFishPerFrame = 30
	elseif isConsole then
		PerformanceProfile.DeviceType = "Console"
		PerformanceProfile.TargetFPS = 45
		PerformanceProfile.MaxFishPerFrame = 100
	else
		PerformanceProfile.DeviceType = "Desktop"
		PerformanceProfile.TargetFPS = 60
		PerformanceProfile.MaxFishPerFrame = 200
	end
end

updatePerformanceMetrics = function(dt)
	local now = os.clock()
	if now - PerformanceProfile.LastFPSUpdate < 0.5 then
		return
	end
	PerformanceProfile.LastFPSUpdate = now

	local currentFPS = math.floor(1 / math.max(dt, 1 / 240))
	PerformanceProfile.CurrentFPS = currentFPS

	table.insert(PerformanceProfile.FPSHistory, currentFPS)
	if #PerformanceProfile.FPSHistory > 60 then
		table.remove(PerformanceProfile.FPSHistory, 1)
	end

	local avgFPS = 0
	for _, fps in ipairs(PerformanceProfile.FPSHistory) do
		avgFPS += fps
	end
	avgFPS = avgFPS / #PerformanceProfile.FPSHistory

	if avgFPS < 25 then
		PerformanceProfile.MaxFishPerFrame = math.max(20, math.floor(PerformanceProfile.MaxFishPerFrame * 0.7))
	elseif avgFPS < 40 then
		PerformanceProfile.MaxFishPerFrame = math.max(30, math.floor(PerformanceProfile.MaxFishPerFrame * 0.85))
	elseif avgFPS > 55 and PerformanceProfile.DeviceType == "Desktop" then
		PerformanceProfile.MaxFishPerFrame = math.min(200, PerformanceProfile.MaxFishPerFrame + 5)
	elseif avgFPS > 55 and PerformanceProfile.DeviceType == "Console" then
		PerformanceProfile.MaxFishPerFrame = math.min(100, PerformanceProfile.MaxFishPerFrame + 3)
	elseif avgFPS > 28 and PerformanceProfile.DeviceType == "Mobile" then
		PerformanceProfile.MaxFishPerFrame = math.min(40, PerformanceProfile.MaxFishPerFrame + 2)
	end
end

local FishGroup_Methods = {
	_SteerTowards = function(self, fish, vector)
		if isnan_vec3(vector) then
			return ZERO_VECTOR
		end
		if vector.Magnitude == 0 then
			return ZERO_VECTOR
		end

		local desired = safe_normalize(vector) * fish._Speed
		if isnan_vec3(desired) then
			return ZERO_VECTOR
		end

		local steer = desired - fish._Velocity
		if isnan_vec3(steer) then
			return ZERO_VECTOR
		end

		return clamp_magnitude(steer, 0, self.MAX_STEER_FORCE)
	end,

	_AvoidObstacles = function(self, fish)
		local avoidance = ZERO_VECTOR
		local fishPos = fish._Position

		local forwardDirection = safe_normalize(fish._Velocity)
		if forwardDirection.Magnitude > 0 then
			local forwardRaycast = workspace:Raycast(fishPos, forwardDirection * self.RAY_LENGTH, self.RaycastParams)
			if forwardRaycast and not FishTaggedInstances[forwardRaycast.Instance.Parent] then
				local hitDistance = forwardRaycast.Distance or self.RAY_LENGTH
				local proximity = 1 - math.clamp(hitDistance / self.RAY_LENGTH, 0, 1)
				if proximity < 0.18 then
					return ZERO_VECTOR
				end

				local directionCount = 5
				local startIndex = (fish._AvoidanceIndex or 0) % directionCount
				fish._AvoidanceIndex = startIndex + 1

				local fishCFrame = fish._LastOrientation
				local clearDirections = fish._ClearDirCache or {}
				local clearCount = 0

				for step = 1, directionCount do
					local index = ((startIndex + step - 1) % directionCount) + 1
					local direction = AVOIDANCE_DIRECTIONS[index]
					local worldDirection = fishCFrame:VectorToWorldSpace(direction)
					local raycast = workspace:Raycast(fishPos, worldDirection * self.RAY_LENGTH, self.RaycastParams)

					if not raycast or FishTaggedInstances[raycast.Instance.Parent] then
						clearCount += 1
						clearDirections[clearCount] = worldDirection
					end
				end
				fish._ClearDirCache = clearDirections

				if clearCount > 0 then
					local bestDirection = clearDirections[1]
					local bestDot = -math.huge
					for index = 1, clearCount do
						local direction = safe_normalize(clearDirections[index])
						local dot = forwardDirection:Dot(direction)
						if dot > bestDot then
							bestDot = dot
							bestDirection = direction
						end
					end

					fish._AvoidanceDirection = fish._AvoidanceDirection
							and safe_normalize(fish._AvoidanceDirection:Lerp(bestDirection, 0.35))
						or bestDirection
					avoidance = FishGroup._SteerTowards(self, fish, fish._AvoidanceDirection)
						* (0.25 + proximity * 0.75)
				else
					local turnSign = (bit32.band(fish._AvoidanceIndex or 0, 1) == 0) and -1 or 1
					local turnDirection = Vector3.new(-forwardDirection.Z, 0, forwardDirection.X) * turnSign
					fish._AvoidanceDirection = fish._AvoidanceDirection
							and safe_normalize(fish._AvoidanceDirection:Lerp(turnDirection, 0.25))
						or turnDirection
					avoidance = FishGroup._SteerTowards(self, fish, fish._AvoidanceDirection)
						* (0.35 + proximity * 0.85)
				end
			else
				fish._AvoidanceDirection = nil
			end
		end

		return avoidance
	end,

	_StayInBounds = function(self, fish)
		local centerPoint = self.TargetPosition or self._SchoolCenter
		if not centerPoint then
			return ZERO_VECTOR
		end

		local distanceFromCenter = (fish._Position - centerPoint).Magnitude
		if distanceFromCenter > self._SchoolRadius * 0.9 then
			local offset = centerPoint - fish._Position
			if isnan_vec3(offset) then
				return ZERO_VECTOR
			end

			local toCenter = safe_normalize(offset)
			local strength = math.min((distanceFromCenter - self._SchoolRadius * 0.9) / (self._SchoolRadius * 0.1), 3)
			if isnan(strength) then
				strength = 1
			end

			local result = toCenter * strength * self.CONTAINMENT_WEIGHT
			if isnan_vec3(result) then
				return ZERO_VECTOR
			end
			return result
		end

		return ZERO_VECTOR
	end,

	_UpdateSchoolCenter = function(self)
		if self.TargetPosition then
			self._SchoolCenter = self.TargetPosition
		else
			local totalPosition = ZERO_VECTOR
			local fishCount = #self._FishArray

			for i = 1, fishCount do
				totalPosition += self._FishArray[i]._Position
			end

			if fishCount > 0 then
				self._SchoolCenter = totalPosition / fishCount
			end
		end
	end,

	_UpdateLeadership = function(self, currentTime)
		if currentTime - self._LastLeadershipUpdate < LEADERSHIP_UPDATE_INTERVAL then
			return
		end

		self._LastLeadershipUpdate = currentTime

		local bestCandidate = nil
		local bestScore = -math.huge
		local fishArray = self._FishArray

		for i = 1, #fishArray do
			local fish = fishArray[i]
			if not fish or not fish._Instance.Parent then
				continue
			end

			local score = 0

			score += fish._Velocity.Magnitude * 2

			local distanceFromCenter = (fish._Position - self._SchoolCenter).Magnitude
			score += distanceFromCenter * 0.5

			if self._Leader and self._Leader._Velocity.Magnitude > 0 then
				local schoolDirection = safe_normalize(self._Leader._Velocity)
				local forwardDot = fish._Position:Dot(schoolDirection)
				score += forwardDot * 0.3
			end

			score += math.random() * 0.5

			if fish._IsLeader then
				score += 1.0
			end

			if score > bestScore then
				bestScore = score
				bestCandidate = fish
			end
		end

		if bestCandidate and bestCandidate ~= self._Leader then
			if self._Leader then
				self._Leader._IsLeader = false
			end

			bestCandidate._IsLeader = true
			self._Leader = bestCandidate
		end
	end,

	AddFish = function(self, fish)
		fish._Speed = math.random() * (self.MAX_SPEED - self.MIN_SPEED) + self.MIN_SPEED

		self._Fish[fish._Instance] = fish
		table.insert(self._FishArray, fish)

		if not self._Leader then
			fish._IsLeader = true
			self._Leader = fish
		end

		fish._PreferredDistance = self.CROWDING_DIST + math.random() * 2
		fish._LastObstacleCheck = 0
		fish._StuckCounter = 0
		fish._LastPosition = fish._Position
	end,

	RemoveFish = function(self, fish)
		if self._Leader == fish then
			self._Leader = nil
			for _, otherFish in ipairs(self._FishArray) do
				if otherFish ~= fish then
					otherFish._IsLeader = true
					self._Leader = otherFish
					break
				end
			end
		end
		self._Fish[fish._Instance] = nil
		for i, f in ipairs(self._FishArray) do
			if f == fish then
				local n = #self._FishArray
				self._FishArray[i] = self._FishArray[n]
				self._FishArray[n] = nil
				break
			end
		end
	end,

	GetFish = function(self)
		local ret = table.create(#self._FishArray)
		table.move(self._FishArray, 1, #self._FishArray, 1, ret)
		return ret
	end,

	SetTargetPosition = function(self, targetPosition) end,

	Step = function(self, dt, budget)
		local currentTime = tick()
		self._StepCounter += 1
		local fishArray = self._FishArray
		local fishCount = #fishArray
		local playerPosition = nil
		local localPlayer = Players.LocalPlayer
		local character = localPlayer and localPlayer.Character
		if character and character.Parent then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			playerPosition = rootPart and rootPart.Position or character:GetPivot().Position
		end

		local networkTarget = NetworkTargets[self.Node]
		if networkTarget then
			local currentTarget = self._NetworkTargetPosition or self.Node.Position
			self._NetworkTargetPosition = currentTarget:Lerp(networkTarget, math.clamp(dt * 8, 0, 1))
			self.TargetPosition = self._NetworkTargetPosition
			self._SchoolCenter = self._NetworkTargetPosition
		else
			self.TargetPosition = self.Node.Position
			self._SchoolCenter = self.Node.Position
		end

		if fishCount > 1 then
			FishGroup._UpdateLeadership(self, currentTime)
		end
		local navigationField = BoidNavigation.GetField(self.Node)

		-- Use the actual centroid so leadership changes cannot snap the shared field vector.
		local fieldSamplePosition = ZERO_VECTOR
		local fieldSampleCount = 0
		for _, fish in fishArray do
			if fish and fish._Instance.Parent and isFiniteVector(fish._Position) then
				fieldSamplePosition += fish._Position
				fieldSampleCount += 1
			end
		end
		fieldSamplePosition = if fieldSampleCount > 0
			then fieldSamplePosition / fieldSampleCount
			else self._SchoolCenter

		local rawFieldDirection = BoidNavigation.GetAvoidance(navigationField, fieldSamplePosition)
		local previousFieldDirection = self._SmoothedFieldDirection or ZERO_VECTOR
		local fieldAlpha = 1 - math.exp(-FIELD_DIRECTION_SMOOTH_RATE * math.min(dt, 0.1))
		local schoolFieldDirection = previousFieldDirection:Lerp(rawFieldDirection, fieldAlpha)
		if not isFiniteVector(schoolFieldDirection) then
			schoolFieldDirection = ZERO_VECTOR
		end
		self._SmoothedFieldDirection = schoolFieldDirection
		local schoolFieldStrength = schoolFieldDirection.Magnitude

		local octreeUpdateInterval = OCTREE_UPDATE_INTERVAL
		if PerformanceProfile.DeviceType == "Mobile" then
			octreeUpdateInterval = octreeUpdateInterval * 2
		end

		if fishCount > 3 and currentTime - (self._LastOctreeUpdate or 0) > octreeUpdateInterval then
			if not self._Octree then
				self._Octree = Octree.new()
				self._OctreeNodes = {}
			end

			local updateOctree = function()
				for instance, node in pairs(self._OctreeNodes) do
					local fish = self._Fish[instance]
					if fish and fish._Instance.Parent then
						local positionDelta = (fish._Position - node.Position).Magnitude
						if positionDelta > 2 then
							self._Octree:ChangeNodePosition(node, fish._Position)
						end
					else
						self._Octree:RemoveNode(node)
						self._OctreeNodes[instance] = nil
					end
				end

				local fishArray = self._FishArray
				for i = 1, #fishArray do
					local fish = fishArray[i]
					local instance = fish._Instance
					if fish and instance.Parent and not self._OctreeNodes[instance] then
						self._OctreeNodes[instance] = self._Octree:CreateNode(fish._Position, fish)
					end
				end
			end

			if PerformanceProfile.DeviceType == "Mobile" and PerformanceProfile.CurrentFPS < 25 then
				FishUpdateScheduler:enqueue(updateOctree, TaskScheduler.Priority.LOW, "OctreeUpdate")
			else
				updateOctree()
			end

			self._LastOctreeUpdate = currentTime
		end

		if self._StepCounter % 5 == 0 or #self._ProcessedFish == 0 then
			table.clear(self._ProcessedFish)
			for _, fish in pairs(self._Fish) do
				table.insert(self._ProcessedFish, fish)
			end
			if #self._ProcessedFish > 1 then
				table.sort(self._ProcessedFish, function(a, b)
					return (a._IsLeader and 1 or 0) > (b._IsLeader and 1 or 0)
				end)
			end
		end

		local limit = PerformanceProfile.MaxFishPerFrame
		if budget then
			limit = math.min(limit, budget)
		end

		local fishToProcess = math.min(limit, #self._ProcessedFish)
		if fishToProcess <= 0 then
			return 0
		end

		local totalBatches = math.max(1, math.ceil(#self._ProcessedFish / fishToProcess))
		local currentBatch = (self._StepCounter - 1) % totalBatches
		local startIndex = currentBatch * fishToProcess + 1

		if #self._ProcessedFish <= fishToProcess then
			startIndex = 1
			fishToProcess = #self._ProcessedFish
		end

		if not self._CFrameUpdateBatch then
			self._CFrameUpdateBatch = {}
			self._NearbyFishCache = {}
		end
		local cframeUpdateBatch = self._CFrameUpdateBatch
		table.clear(cframeUpdateBatch)

		for i = startIndex, math.min(startIndex + fishToProcess - 1, #self._ProcessedFish) do
			local fish = self._ProcessedFish[i]
			if not fish or not fish._Instance.Parent then
				continue
			end

			local fishPos = fish._Position
			local lod = 1
			local distanceToPlayer = 0
			if playerPosition then
				distanceToPlayer = (fishPos - playerPosition).Magnitude
				if distanceToPlayer > FAR_LOD_DISTANCE then
					lod = 4
				elseif distanceToPlayer > MID_LOD_DISTANCE then
					lod = 3
				elseif distanceToPlayer > NEAR_LOD_DISTANCE then
					lod = 2
				end
			end

			if lod == 4 and not fish._IsLeader and self._StepCounter % 6 ~= 0 then
				fish._AccumulatedDt = (fish._AccumulatedDt or 0) + dt
				continue
			elseif lod == 3 and not fish._IsLeader and self._StepCounter % 3 ~= 0 then
				fish._AccumulatedDt = (fish._AccumulatedDt or 0) + dt
				continue
			elseif lod == 2 and not fish._IsLeader and self._StepCounter % 2 ~= 0 then
				fish._AccumulatedDt = (fish._AccumulatedDt or 0) + dt
				continue
			end
			local simulationDt = math.min(dt + (fish._AccumulatedDt or 0), 0.2)
			fish._AccumulatedDt = 0

			local alignment = ZERO_VECTOR
			local cohesion = ZERO_VECTOR
			local separation = ZERO_VECTOR
			local neighborCount = 0
			local tooCloseNeighbors = 0
			local veryCloseNeighbors = 0
			local neighborDist = fish._IsLeader and self.NEIGHBOR_DIST or self.NEIGHBOR_DIST * 0.6
			if lod == 2 then
				neighborDist *= 0.75
			elseif lod >= 3 then
				neighborDist *= 0.45
			end
			local neighborDistSq = neighborDist * neighborDist
			local preferredDistSq = fish._PreferredDistance * fish._PreferredDistance
			local preferredDistHalfSq = preferredDistSq * 0.25
			local maxNeighbors = lod == 1 and MAX_NEAR_NEIGHBORS or MAX_MID_NEIGHBORS

			local nearbyFish = self._NearbyFishCache
			table.clear(nearbyFish)
			if lod >= 3 and not fish._IsLeader then
				-- Far fish only follow the school target; dense local boid checks are not visible enough to justify the cost.
			elseif self._Octree then
				for node in self._Octree:ForEachInRadius(fishPos, self.NEIGHBOR_DIST) do
					table.insert(nearbyFish, node.Object)
					if #nearbyFish >= maxNeighbors + 1 then
						break
					end
				end
			else
				for j = 1, math.min(#self._ProcessedFish, maxNeighbors + 1) do
					nearbyFish[j] = self._ProcessedFish[j]
				end
			end

			for _, neighbor in ipairs(nearbyFish) do
				if neighbor == fish then
					continue
				end

				local offset = neighbor._Position - fishPos
				local distanceSq = offset:Dot(offset)

				if distanceSq < neighborDistSq and distanceSq > 0.01 then
					alignment += neighbor._Velocity
					cohesion += neighbor._Position

					if distanceSq < preferredDistSq then
						local invDist = fastInvSqrt(distanceSq)
						separation += -offset * invDist
						tooCloseNeighbors += 1
						if distanceSq < preferredDistHalfSq then
							veryCloseNeighbors += 1
						end
					end

					neighborCount += 1
					if neighborCount >= maxNeighbors then
						break
					end
				end
			end

			fish._Acceleration = ZERO_VECTOR

			if neighborCount > 0 then
				local invNeighborCount = 1 / neighborCount
				alignment *= invNeighborCount
				local alignmentForce = FishGroup._SteerTowards(self, fish, alignment) * self.ALIGN_WEIGHT
				fish._Acceleration += alignmentForce

				cohesion *= invNeighborCount
				local cohesionOffset = cohesion - fishPos
				local cohesionForce = FishGroup._SteerTowards(self, fish, cohesionOffset) * self.COHESION_WEIGHT
				fish._Acceleration += cohesionForce

				local separationForce = FishGroup._SteerTowards(self, fish, separation) * self.SEPARATION_WEIGHT
				fish._Acceleration += separationForce
			end

			local isSoloSwimming = #self._FishArray <= 1 or neighborCount == 0
			if isSoloSwimming then
				local forwardDirection = safe_normalize(fish._Velocity)
				local sideDirection = safe_perpendicular(forwardDirection)
				local wanderTime = currentTime + (fish._WanderSeed or 0)
				local wanderDirection = safe_normalize(
					forwardDirection * 0.7
						+ sideDirection * math.sin(wanderTime * 0.85) * 0.25
						+ Vector3.new(0, math.sin(wanderTime * 0.55) * 0.12, 0)
				)

				fish._Acceleration += FishGroup._SteerTowards(self, fish, wanderDirection) * FISH_DEFAULT_WANDER_WEIGHT

				local centerPoint = self.TargetPosition or self._SchoolCenter
				if centerPoint then
					local fromCenter = fishPos - centerPoint
					local distanceFromCenter = fromCenter.Magnitude
					if distanceFromCenter > 1 and distanceFromCenter < self._SchoolRadius * 0.75 then
						local orbitDirection = safe_perpendicular(fromCenter.Unit)
						if math.sin(wanderTime * 0.31) < 0 then
							orbitDirection = -orbitDirection
						end
						fish._Acceleration += FishGroup._SteerTowards(self, fish, orbitDirection) * FISH_DEFAULT_ORBIT_WEIGHT
					end
				end
			end

			local obstacleInterval = OBSTACLE_CHECK_INTERVAL
			if PerformanceProfile.DeviceType == "Mobile" then
				obstacleInterval = obstacleInterval * 3.0
			elseif PerformanceProfile.DeviceType == "Console" then
				obstacleInterval = obstacleInterval * 1.5
			end
			if lod >= 2 then
				obstacleInterval = math.huge
			end
			if navigationField then
				obstacleInterval = math.huge
			end

			if schoolFieldStrength > 0.001 then
				local fieldForce = FishGroup._SteerTowards(self, fish, schoolFieldDirection)
					* self.AVOIDANCE_WEIGHT
					* 0.45
					* schoolFieldStrength
				fish._Acceleration += clamp_magnitude(fieldForce, 0, self.MAX_STEER_FORCE * 0.75)
			end

			if playerPosition then
				local fromPlayer = fishPos - playerPosition
				local playerDistance = fromPlayer.Magnitude
				if playerDistance > 0.001 and playerDistance < 8 then
					local playerForce = FishGroup._SteerTowards(self, fish, fromPlayer)
						* self.AVOIDANCE_WEIGHT
						* (1 - playerDistance / 8)
					fish._Acceleration += clamp_magnitude(playerForce, 0, self.MAX_STEER_FORCE)
				end
			end

			if fish._IsLeader then
				obstacleInterval = obstacleInterval * 0.5
			elseif neighborCount > 8 then
				obstacleInterval = math.huge
			elseif neighborCount > 5 then
				obstacleInterval = obstacleInterval * 2.0
			end

			local shouldProcessAvoidance = (currentTime - fish._LastObstacleCheck > obstacleInterval)

			if shouldProcessAvoidance then
				local avoidanceForce = FishGroup._AvoidObstacles(self, fish) * self.AVOIDANCE_WEIGHT
				if not isnan_vec3(avoidanceForce) and avoidanceForce.Magnitude > 0 then
					avoidanceForce = clamp_magnitude(avoidanceForce, 0, self.MAX_STEER_FORCE * 1.1)
					fish._Acceleration = avoidanceForce + fish._Acceleration * 0.65
				end
				fish._LastObstacleCheck = currentTime
			end

			if self.TargetPosition then
				local targetOffset = self.TargetPosition - fishPos
				local targetDistance = targetOffset.Magnitude

				local strength = self.TARGET_WEIGHT

				if targetDistance > self._SchoolRadius then
					strength = strength * 0.75
				elseif targetDistance < self._SchoolRadius * 0.3 then
					if #self._FishArray <= 1 or neighborCount == 0 then
						strength = strength * 0.18
					else
						strength = strength * 0.0125
					end
				end

				if fish._IsLeader then
					strength = strength * 1.2
				end

				local targetForce = FishGroup._SteerTowards(self, fish, targetOffset) * strength
				fish._Acceleration += targetForce
			end

			local containmentForce = FishGroup._StayInBounds(self, fish)
			fish._Acceleration += containmentForce

			if
				navigationField
				and fish._NavigationUntil > currentTime
				and fish._NavigationDirection.Magnitude > 0.001
			then
				local navigationForce = FishGroup._SteerTowards(self, fish, fish._NavigationDirection) * 3
				fish._Acceleration = fish._Acceleration * 0.35 + navigationForce
			end

			local movementDistance = (fish._Position - fish._LastPosition).Magnitude
			local minimumExpectedMovement = math.max(0.002, self.MIN_SPEED * 0.2 * simulationDt * 0.25)
			if movementDistance < minimumExpectedMovement then
				fish._StuckCounter += simulationDt
				if fish._StuckCounter > 1.5 then
					local escapeDirection = if navigationField
						then BoidNavigation.GetDeflectionDirection(
							navigationField,
							fish._Position,
							fish._Velocity,
							fish._WanderSeed + fish._StuckCounter
						)
						else Vector3.new(math.random(-1, 1), math.random(-0.3, 0.3), math.random(-1, 1)).Unit
					if escapeDirection.Magnitude < 0.001 then
						escapeDirection = safe_normalize(fish._Velocity)
					end
					fish._Acceleration += escapeDirection * self.MAX_STEER_FORCE * 0.3
					fish._StuckCounter = 0
				end
			else
				fish._StuckCounter = 0
			end
			fish._LastPosition = fishPos

			fish._Velocity += fish._Acceleration * simulationDt

			if isnan_vec3(fish._Velocity) then
				fish._Velocity = Vector3.new(0, 0, self.MIN_SPEED)
			end

			local targetSpeed = fish._Speed
			local currentSpeed = fish._Velocity.Magnitude
			local shouldSlowDown = false

			if veryCloseNeighbors > 1 and fish._Acceleration.Magnitude < self.MAX_STEER_FORCE * 0.3 then
				targetSpeed = math.max(self.MIN_SPEED * 0.6, fish._Speed * 0.7)
				shouldSlowDown = true
			end

			if shouldSlowDown and currentSpeed > targetSpeed then
				local decelerationFactor = math.max(0.95, targetSpeed / currentSpeed)
				fish._Velocity = fish._Velocity * decelerationFactor
			end

			fish._Velocity = clamp_magnitude(fish._Velocity, self.MIN_SPEED * 0.2, fish._Speed)

			local proposedMovement = fish._Velocity * simulationDt
			local newPosition = fish._Position + proposedMovement

			if isnan_vec3(newPosition) then
				fish._Position = self._SchoolCenter + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
				fish._Velocity = Vector3.new(0, 0, self.MIN_SPEED)
			else
				local movementDistance = proposedMovement.Magnitude

				if navigationField then
					if not BoidNavigation.IsNavigable(navigationField, fish._Position) then
						local recoveryTarget =
							BoidNavigation.GetNearestNavigablePosition(navigationField, fish._Position, 4)
						if recoveryTarget then
							local recoveryOffset = recoveryTarget - fish._Position
							local recoveryDirection = safe_normalize(recoveryOffset)
							local recoveryDistance = math.min(
								recoveryOffset.Magnitude,
								math.max(fish._Velocity.Magnitude, self.MIN_SPEED) * simulationDt
							)
							fish._Position += recoveryDirection * recoveryDistance
							fish._Velocity = recoveryDirection
								* math.max(self.MIN_SPEED * 0.65, fish._Velocity.Magnitude)
							fish._NavigationDirection = recoveryDirection
							fish._NavigationUntil = currentTime + NAVIGATION_TURN_HOLD_TIME
						else
							fish._Velocity *= 0.5
						end
					elseif BoidNavigation.IsSegmentNavigable(navigationField, fish._Position, newPosition) then
						fish._Position = newPosition
					else
						local deflectionIntent = if fish._NavigationUntil > currentTime
								and fish._NavigationDirection.Magnitude > 0.001
							then fish._NavigationDirection
							else fish._Velocity
						local escapeDirection = BoidNavigation.GetDeflectionDirection(
							navigationField,
							fish._Position,
							deflectionIntent,
							fish._WanderSeed
						)
						if escapeDirection.Magnitude < 0.001 then
							escapeDirection = BoidNavigation.GetAvoidance(navigationField, fish._Position)
						end
						if escapeDirection.Magnitude > 0.001 then
							fish._NavigationDirection = escapeDirection
							fish._NavigationUntil = currentTime + NAVIGATION_TURN_HOLD_TIME
							local retainedSpeed = math.max(self.MIN_SPEED * 0.65, fish._Velocity.Magnitude * 0.8)
							fish._Velocity = safe_normalize(fish._Velocity:Lerp(escapeDirection * fish._Speed, 0.4))
								* retainedSpeed
							local slideMovement = fish._Velocity * simulationDt
							local slidePosition = fish._Position + slideMovement
							if BoidNavigation.IsSegmentNavigable(navigationField, fish._Position, slidePosition) then
								fish._Position = slidePosition
							end
						else
							fish._Velocity *= 0.5
						end
					end
				elseif movementDistance > 0.1 then
					-- Safe fallback while a place has not been baked yet.
					local pathRaycast = workspace:Raycast(fish._Position, proposedMovement, self.RaycastParams)

					if pathRaycast and not FishTaggedInstances[pathRaycast.Instance.Parent] then
						local safeDistance = math.max(pathRaycast.Distance - 0.35, 0)
						local movementDirection = proposedMovement.Unit
						local safePosition = fish._Position + movementDirection * safeDistance

						fish._Velocity = fish._Velocity * 0.55

						local deflectionOffset = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit * 0.25

						fish._Velocity = fish._Velocity + deflectionOffset
						fish._Position = safePosition
					else
						fish._Position = newPosition
					end
				else
					fish._Position = newPosition
				end
			end

			if fish._Velocity.Magnitude > 0.05 and not isnan_vec3(fish._Velocity) then
				local lookDirection = fish._Position + safe_normalize(fish._Velocity)
				if not isnan_vec3(lookDirection) then
					local targetCFrame = CFrame.lookAt(fish._Position, lookDirection)
					if targetCFrame then
						local lerpFactor = math.min(simulationDt * fish._Responsiveness, 1)
						if isnan(lerpFactor) then
							lerpFactor = 0.1
						end

						local speedFactor = fish._Velocity.Magnitude / fish._Speed
						lerpFactor = lerpFactor * math.max(0.1, speedFactor)

						local previousForward = fish._LastOrientation.LookVector

						if #self._FishArray <= 1 or neighborCount == 0 then
							lerpFactor = math.max(lerpFactor * 0.65, math.min(simulationDt * 2.5, 0.12))
							lerpFactor = math.min(lerpFactor, 0.28)
						end
						if lod >= 3 then
							lerpFactor = math.min(lerpFactor * 0.75, 0.12)
						end

						local desiredDirection = safe_normalize(fish._Velocity)
						local turnAmount = previousForward:Cross(desiredDirection).Y
						if isnan(turnAmount) then
							turnAmount = 0
						end

						fish._BankAngle = fish._BankAngle or 0
						local targetBankAngle = math.clamp(-turnAmount * 0.75, -MAX_BANK_ANGLE, MAX_BANK_ANGLE)
						fish._BankAngle += (targetBankAngle - fish._BankAngle) * math.min(simulationDt * 4, 1)

						local bankedTargetCFrame = targetCFrame * CFrame.Angles(0, 0, fish._BankAngle)
						local newCFrame = fish._LastOrientation:Lerp(bankedTargetCFrame, lerpFactor)
						local previousCFrame = fish._LastQueuedCFrame or fish._LastOrientation
						fish._LastOrientation = newCFrame

						local animSpeed = math.max(0.1, math.min(2.0, currentSpeed / self.MIN_SPEED))
						local shouldUpdateAnim = not fish._LastAnimSpeed
							or math.abs(animSpeed - fish._LastAnimSpeed) > MIN_ANIM_SPEED_CHANGE
						if shouldUpdateAnim then
							fish._LastAnimSpeed = animSpeed
						end

						local positionDelta = (newCFrame.Position - previousCFrame.Position).Magnitude
						local lookDelta = 1 - math.clamp(newCFrame.LookVector:Dot(previousCFrame.LookVector), -1, 1)
						local shouldQueueCFrame = shouldUpdateAnim
							or positionDelta >= MIN_CFRAME_POSITION_DELTA
							or lookDelta >= MIN_CFRAME_LOOK_DELTA

						if shouldQueueCFrame then
							fish._LastQueuedCFrame = newCFrame
							table.insert(cframeUpdateBatch, {
								instance = fish._Instance,
								cframe = newCFrame,
								animSpeed = shouldUpdateAnim and animSpeed or nil,
							})
						end
					end
				end
			else
				if not isnan_vec3(fish._Position) then
					local newCFrame = CFrame.new(fish._Position)
						* (fish._LastOrientation - fish._LastOrientation.Position)
					local previousCFrame = fish._LastQueuedCFrame or fish._LastOrientation
					if (newCFrame.Position - previousCFrame.Position).Magnitude >= MIN_CFRAME_POSITION_DELTA then
						fish._LastQueuedCFrame = newCFrame
						table.insert(cframeUpdateBatch, {
							instance = fish._Instance,
							cframe = newCFrame,
							animSpeed = nil,
						})
					end
				end
			end
		end

		if #cframeUpdateBatch > 0 then
			local queue = GlobalCFrameQueue
			for _, update in ipairs(cframeUpdateBatch) do
				queue[#queue + 1] = update
			end
		end

		return fishToProcess
	end,
}

FishGroup.new = function(Min, Max, Crowding, Align, Seperate, Target, Raylength)
	local self = {
		_Fish = {},
		_FishArray = {},
		TargetPosition = nil,
		RaycastParams = RaycastParams.new(),
		MAX_SPEED = Max or FISH_DEFAULT_MAX_SPEED,
		MIN_SPEED = Min or FISH_DEFAULT_MIN_SPEED,
		RAY_LENGTH = Raylength or FISH_DEFAULT_RAY_LENGTH,
		NEIGHBOR_DIST = FISH_DEFAULT_NEIGHBOR_DIST,
		CROWDING_DIST = Crowding or FISH_DEFAULT_CROWDING_DIST,
		MAX_STEER_FORCE = FISH_DEFAULT_MAX_STEER_FORCE,
		ALIGN_WEIGHT = Align or FISH_DEFAULT_ALIGN_WEIGHT,
		COHESION_WEIGHT = FISH_DEFAULT_COHESION_WEIGHT,
		SEPARATION_WEIGHT = Seperate or FISH_DEFAULT_SEPARATION_WEIGHT,
		TARGET_WEIGHT = Target or FISH_DEFAULT_TARGET_WEIGHT,
		AVOIDANCE_WEIGHT = FISH_DEFAULT_AVOIDANCE_WEIGHT,
		CONTAINMENT_WEIGHT = FISH_DEFAULT_CONTAINMENT_WEIGHT,
		_StepCounter = 0,
		_Leader = nil,
		_SchoolCenter = ZERO_VECTOR,
		_SchoolRadius = 15,
		_ProcessedFish = {},
		_LastLeadershipUpdate = 0,
		_Octree = nil,
		_LastOctreeUpdate = 0,
		_OctreeNodes = nil,
		_CFrameUpdateBatch = nil,
		_NearbyFishCache = nil,
		_SmoothedFieldDirection = ZERO_VECTOR,
	}

	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RaycastParams.FilterDescendantsInstances = {}

	self._SteerTowards = FishGroup_Methods._SteerTowards
	self._AvoidObstacles = FishGroup_Methods._AvoidObstacles
	self._StayInBounds = FishGroup_Methods._StayInBounds
	self._UpdateSchoolCenter = FishGroup_Methods._UpdateSchoolCenter
	self._UpdateLeadership = FishGroup_Methods._UpdateLeadership
	self.AddFish = FishGroup_Methods.AddFish
	self.RemoveFish = FishGroup_Methods.RemoveFish
	self.GetFish = FishGroup_Methods.GetFish
	self.SetTargetPosition = FishGroup_Methods.SetTargetPosition
	self.Step = FishGroup_Methods.Step

	return self
end

FishGroup._SteerTowards = FishGroup_Methods._SteerTowards
FishGroup._AvoidObstacles = FishGroup_Methods._AvoidObstacles
FishGroup._StayInBounds = FishGroup_Methods._StayInBounds
FishGroup._UpdateSchoolCenter = FishGroup_Methods._UpdateSchoolCenter
FishGroup._UpdateLeadership = FishGroup_Methods._UpdateLeadership
FishGroup.AddFish = FishGroup_Methods.AddFish
FishGroup.RemoveFish = FishGroup_Methods.RemoveFish
FishGroup.GetFish = FishGroup_Methods.GetFish
FishGroup.SetTargetPosition = FishGroup_Methods.SetTargetPosition
FishGroup.Step = FishGroup_Methods.Step

function FishGroup.CreateFish(inst)
	local startPosition = inst:GetPivot().Position

	if isnan_vec3(startPosition) then
		startPosition = ZERO_VECTOR
	end

	local randomVelocity =
		safe_vector3(math.random(-50, 50) / 100, math.random(-15, 15) / 100, math.random(-50, 50) / 100)

	if randomVelocity.Magnitude == 0 then
		randomVelocity = FORWARD_VECTOR * 0.5
	end

	randomVelocity = safe_normalize(randomVelocity) * (FISH_DEFAULT_MIN_SPEED * 0.3)

	local speed = math.random() * (FISH_DEFAULT_MAX_SPEED - FISH_DEFAULT_MIN_SPEED) + FISH_DEFAULT_MIN_SPEED
	if isnan(speed) then
		speed = FISH_DEFAULT_MIN_SPEED
	end

	local responsiveness = math.random() * 2 + 4
	if isnan(responsiveness) then
		responsiveness = 5
	end

	return {
		_Instance = inst,
		_Position = startPosition,
		_Velocity = randomVelocity,
		_Acceleration = ZERO_VECTOR,
		_LastOrientation = inst:GetPivot(),
		_LastQueuedCFrame = inst:GetPivot(),
		_Speed = speed,
		_Responsiveness = responsiveness,
		_PreferredDistance = FISH_DEFAULT_CROWDING_DIST,
		_LastObstacleCheck = 0,
		_IsLeader = false,
		_StuckCounter = 0,
		_LastPosition = startPosition,
		_LastAnimSpeed = nil,
		_ClearDirCache = nil,
		_NavigationDirection = ZERO_VECTOR,
		_NavigationUntil = 0,
		_WanderSeed = math.random() * 100,
		_BankAngle = 0,
	}
end

function FishGroup.RegisterGroup(fishGroup, fishBrain)
	if not RegisteredGroups[fishGroup] then
		RegisteredGroups[fishGroup] = fishBrain
		table.insert(RegisteredGroupArray, fishGroup)

		if not FishUpdateScheduler then
			detectDevicePerformance()
			FishUpdateScheduler = TaskScheduler.new({
				maxTasksPerFrame = 2,
				timeBudgetMs = 3,
				enableRateLimit = false,
				enableMetrics = false,
				stepEvent = RunService.PreSimulation,
				runInParallel = true,
			})
			FishUpdateScheduler:start()
		end

		if not FishStepTask then
			LastFishStep = os.clock()
			FishStepTask = FishUpdateScheduler:every(FISH_SIMULATION_INTERVAL, function()
				if not workspace:GetAttribute("FishSimulation") then
					return
				end

				local now = os.clock()
				local dt = math.min(now - LastFishStep, 0.1)
				LastFishStep = now
				local budget = PerformanceProfile.MaxFishPerFrame
				local groupCount = #RegisteredGroupArray
				if groupCount == 0 then
					return
				end

				FishStepCursor = math.clamp(FishStepCursor, 1, groupCount)
				for offset = 0, groupCount - 1 do
					if budget <= 0 then
						break
					end

					local index = ((FishStepCursor + offset - 1) % groupCount) + 1
					local group = RegisteredGroupArray[index]
					local groupsRemaining = groupCount - offset
					local groupBudget = math.max(1, math.floor(budget / groupsRemaining))
					local processed = group:Step(dt, groupBudget)
					budget -= processed
				end

				FishStepCursor = (FishStepCursor % groupCount) + 1
			end, TaskScheduler.Priority.HIGH, "FishSimulation33Hz", true)
		end
	end
end

function FishGroup.UnregisterGroup(fishGroup)
	if RegisteredGroups[fishGroup] then
		RegisteredGroups[fishGroup] = nil
		local index = table.find(RegisteredGroupArray, fishGroup)
		if index then
			table.remove(RegisteredGroupArray, index)
		end

		if #RegisteredGroupArray == 0 and FishStepTask then
			FishUpdateScheduler:cancel(FishStepTask)
			FishStepTask = nil
			FishStepCursor = 1
		end
	end
end

function FishGroup.RegisterFishInstance(inst)
	FishTaggedInstances[inst] = true
end

function FishGroup.UnregisterFishInstance(inst)
	FishTaggedInstances[inst] = nil
	FishAnimationTracks[inst] = nil
end

function FishGroup.RegisterAnimationTracks(inst, tracks)
	FishAnimationTracks[inst] = tracks
end

function FishGroup.GetPerformanceMetrics()
	return {
		DeviceType = PerformanceProfile.DeviceType,
		CurrentFPS = PerformanceProfile.CurrentFPS,
		TargetFPS = PerformanceProfile.TargetFPS,
		MaxFishPerFrame = PerformanceProfile.MaxFishPerFrame,
		SimulationRate = FISH_SIMULATION_RATE,
		AverageFPS = #PerformanceProfile.FPSHistory > 0 and (function()
			local sum = 0
			for _, fps in ipairs(PerformanceProfile.FPSHistory) do
				sum += fps
			end
			return sum / #PerformanceProfile.FPSHistory
		end)() or 0,
	}
end

return FishGroup
