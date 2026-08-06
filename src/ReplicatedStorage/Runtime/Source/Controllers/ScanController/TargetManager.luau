local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local CurrentCamera = workspace.CurrentCamera
local Config = require(script.Parent.Config)

local function toVector2(position)
	if not position then
		return nil
	end

	local positionType = typeof(position)
	if positionType == "Vector2" then
		return position
	elseif positionType == "Vector3" then
		return Vector2.new(position.X, position.Y)
	end

	return nil
end

local TargetManager = {}
TargetManager.__index = TargetManager

function TargetManager.new(scanController)
	local self = setmetatable({}, TargetManager)
	self.scanController = scanController
	self._scannableCache = {}
	self._scannableCacheTime = 0
	self._candidateCache = {}
	self._candidateCacheTime = 0
	self._ignoreListCache = {}
	self._ignoreListTime = 0
	self._raycastParams = RaycastParams.new()
	return self
end

function TargetManager:GetScanId(target)
	if not target then
		return nil
	end

	local fishId = target:GetAttribute("_fishId")
	if fishId then
		return fishId
	end

	if target:IsA("Model") then
		local scannablePart = target:FindFirstChildWhichIsA("Part")
		if scannablePart then
			return scannablePart:GetAttribute("_fishId")
		end
	end

	return nil
end

function TargetManager:_getIgnoreList()
	local now = os.clock()
	if self._ignoreListCache and (now - (self._ignoreListTime or 0)) < (Config.SCAN_IGNORE_REFRESH_INTERVAL or 0.25) then
		return self._ignoreListCache
	end

	local ignoreList = {}
	local character = self.scanController and self.scanController.Character
	if character then
		table.insert(ignoreList, character)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local playerCharacter = player.Character
		if playerCharacter then
			table.insert(ignoreList, playerCharacter)
		end
	end
	for _, ignoredPart in CollectionService:GetTagged("IgnoreOnRay") do
		if ignoredPart then
			table.insert(ignoreList, ignoredPart)
		end
	end
	if CurrentCamera then
		table.insert(ignoreList, CurrentCamera)
	end

	self._ignoreListCache = ignoreList
	self._ignoreListTime = now
	return ignoreList
end

function TargetManager:_rayParams()
	local rayParams = self._raycastParams
	if not rayParams then
		rayParams = RaycastParams.new()
		self._raycastParams = rayParams
	end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.FilterDescendantsInstances = self:_getIgnoreList()
	return rayParams
end

function TargetManager:_getScreenCandidate(part)
	CurrentCamera = workspace.CurrentCamera or CurrentCamera
	if not part or not CurrentCamera then
		return nil
	end

	local target = part
	local targetPart = part
	local worldSize = nil
	if part:IsA("Model") then
		target = part
		targetPart = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
		if not targetPart then
			return nil
		end
		local _, size = part:GetBoundingBox()
		worldSize = size
	elseif part:IsA("BasePart") then
		worldSize = part.Size
	end

	local point = targetPart:GetPivot().Position
	local vector, onScreen = CurrentCamera:WorldToViewportPoint(point)
	if not onScreen then
		return nil
	end

	local radiusPixels = 0
	if worldSize then
		local cameraCFrame = CurrentCamera.CFrame
		local rightOffset = cameraCFrame.RightVector * (worldSize.X * 0.5)
		local upOffset = cameraCFrame.UpVector * (worldSize.Y * 0.5)
		local rightVector, rightOnScreen = CurrentCamera:WorldToViewportPoint(point + rightOffset)
		local upVector, upOnScreen = CurrentCamera:WorldToViewportPoint(point + upOffset)
		if rightOnScreen then
			radiusPixels = math.max(radiusPixels, (Vector2.new(rightVector.X, rightVector.Y) - Vector2.new(vector.X, vector.Y)).Magnitude)
		end
		if upOnScreen then
			radiusPixels = math.max(radiusPixels, (Vector2.new(upVector.X, upVector.Y) - Vector2.new(vector.X, vector.Y)).Magnitude)
		end
	end

	local cameraPosition = CurrentCamera.CFrame.Position
	local direction = point - cameraPosition
	local distance = direction.Magnitude
	if distance > Config.RAYCAST_MAX_DISTANCE then
		return nil
	end

	return {
		Target = target,
		TargetPart = targetPart,
		Point = point,
		Vector = vector,
		RadiusPixels = radiusPixels,
		Direction = direction,
		Distance = distance,
		CameraPosition = cameraPosition
	}
end

function TargetManager:_candidates()
	local now = os.clock()
	if self._candidateCache and (now - (self._candidateCacheTime or 0)) < (Config.SCAN_CANDIDATE_REFRESH_INTERVAL or 0.5) then
		return self._candidateCache
	end

	local candidates = {}
	local function addCandidate(instance)
		if instance and instance.Parent then
			table.insert(candidates, instance)
		end
	end

	local function processModelContainer(container)
		if not container then return end
		for _, model in container:GetChildren() do
			if model:IsA("Model") then
				addCandidate(model)
			end
		end
	end

	local function processNodeContainer(container)
		if not container then return end
		for _, node in container:GetDescendants() do
			if not node:IsA("BasePart") then
				continue
			end
			for _, part in node:GetChildren() do
				if part:IsA("Model") then
					addCandidate(part)
				end
			end
		end
	end

	local animatedLifeForms = workspace:FindFirstChild("AnimatedLifeForms")
	local nodesFolder = animatedLifeForms and animatedLifeForms:FindFirstChild("Nodes")
	processNodeContainer(nodesFolder)

	local eventAnimals = workspace:FindFirstChild("EventAnimals")
	processModelContainer(eventAnimals)

	local selectableParts = CollectionService:GetTagged("Selectable")
	for _, selectablePart in selectableParts do
		addCandidate(selectablePart)
	end

	local discoveryInjectors = CollectionService:GetTagged("DiscoveryInjector")
	for _, injectorPart in discoveryInjectors do
		addCandidate(injectorPart)
	end

	self._candidateCache = candidates
	self._candidateCacheTime = now
	return candidates
end

function TargetManager:_getCandidateType(candidate)
	if not candidate then
		return "other"
	end
	if CollectionService:HasTag(candidate, "Selectable") or CollectionService:HasTag(candidate, "DiscoveryInjector") then
		return "selectable"
	end
	local animatedLifeForms = workspace:FindFirstChild("AnimatedLifeForms")
	if animatedLifeForms and candidate:IsDescendantOf(animatedLifeForms) then
		return "boid"
	end
	local eventAnimals = workspace:FindFirstChild("EventAnimals")
	if eventAnimals and candidate:IsDescendantOf(eventAnimals) then
		return "boid"
	end
	return "other"
end


function TargetManager:GetPartOnScreen(part, baseIgnoreList, baseRayParams, screenCandidate)
	local data = screenCandidate or self:_getScreenCandidate(part)
	if not data then
		return nil
	end

	local target = data.Target
	local point = data.Point
	local vector = data.Vector
	local direction = data.Direction
	local distance = data.Distance
	local cameraPosition = data.CameraPosition

	local baseIgnore = baseIgnoreList or self:_getIgnoreList()
	local ignoreList = baseIgnore
	local rayParams = baseRayParams or self:_rayParams()
	rayParams.FilterDescendantsInstances = ignoreList
	local function isNonOccluding(hitPart)
		if not hitPart or not hitPart:IsA("BasePart") then
			return false
		end
		if hitPart.Material == Enum.Material.Glass then
			return true
		end
		if hitPart.Transparency >= (Config.SCAN_OCCLUSION_TRANSPARENCY or 0.6) then
			return true
		end
		return false
	end

	local rayOrigin = cameraPosition
	local rayDirection = direction
	local remainingDistance = distance

	for _ = 1, 6 do
		local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
		if not result then
			break
		end

		local hit = result.Instance

		if target:IsA("Model") then
			if hit:IsDescendantOf(target) then
				break
			end
		elseif hit == target or hit:IsDescendantOf(target) then
			break
		end

		if isNonOccluding(hit) then
			if ignoreList == baseIgnore then
				ignoreList = table.clone(ignoreList)
			end
			table.insert(ignoreList, hit)
			rayParams.FilterDescendantsInstances = ignoreList
			remainingDistance -= result.Distance
			if remainingDistance <= 0 then
				return nil
			end
			rayOrigin = result.Position + rayDirection.Unit * 0.05
			rayDirection = rayDirection.Unit * remainingDistance
		else
			return nil
		end
	end

	return {
		Position = Vector2.new(vector.X, vector.Y),
		Radius = data.RadiusPixels or 0,
		Instance = target
	}
end

function TargetManager:GetScannables()
	local humanoidRootPart = self.scanController.HumanoidRootPart
	if not humanoidRootPart or not humanoidRootPart.Parent then
		self._scannableCache = {}
		self._scannableCacheTime = os.clock()
		return self._scannableCache
	end

	local now = os.clock()
	if self._scannableCache and (now - (self._scannableCacheTime or 0)) < (Config.SCAN_REFRESH_INTERVAL or 0.2) then
		return self._scannableCache
	end

	local scannables = {}
	local candidates = self:_candidates()
	local baseIgnoreList = self:_getIgnoreList()
	local baseRayParams = self:_rayParams()
	local screenCandidates = {}
	for _, candidate in ipairs(candidates) do
		if candidate and candidate.Parent then
			local data = self:_getScreenCandidate(candidate)
			if data then
				data.CandidateType = self:_getCandidateType(candidate)
				table.insert(screenCandidates, data)
			end
		end
	end

	table.sort(screenCandidates, function(a, b)
		return a.Distance < b.Distance
	end)

	local budget = Config.SCAN_RAYCAST_BUDGET
	local limit = budget and math.min(#screenCandidates, budget) or #screenCandidates
	local boids = {}
	local selectables = {}
	local others = {}
	for _, data in ipairs(screenCandidates) do
		if data.CandidateType == "boid" then
			table.insert(boids, data)
		elseif data.CandidateType == "selectable" then
			table.insert(selectables, data)
		else
			table.insert(others, data)
		end
	end

	local half = math.floor(limit / 2)
	local boidLimit = math.min(#boids, half)
	local selectableLimit = math.min(#selectables, limit - boidLimit)
	local remaining = limit - (boidLimit + selectableLimit)
	local otherLimit = math.min(#others, remaining)

	local function addScannables(list, count)
		for i = 1, count do
			local data = list[i]
			if data then
				local screenData = self:GetPartOnScreen(data.Target, baseIgnoreList, baseRayParams, data)
				if screenData then
					scannables[data.Target] = screenData
				end
			end
		end
	end

	addScannables(boids, boidLimit)
	addScannables(selectables, selectableLimit)
	addScannables(others, otherLimit)

	self._scannableCache = scannables
	self._scannableCacheTime = now
	return scannables
end

function TargetManager:FindNearestScannable(mouseLocation, scannerCursor)
	local scannables = self:GetScannables()
	local closestDistance = math.huge
	local closestTarget = nil

	local pointerPosition = toVector2(mouseLocation)
	if not pointerPosition and scannerCursor then
		pointerPosition = Vector2.new(scannerCursor.Position.X.Offset, scannerCursor.Position.Y.Offset)
	end
	if not pointerPosition then
		return nil
	end

	local cursor = scannerCursor
	if not cursor then
		local cursorManager = self.scanController and self.scanController.CursorManager
		if cursorManager and cursorManager.GetScannerCursor then
			cursor = cursorManager:GetScannerCursor()
		else
			cursor = self.scanController and self.scanController.ScannerCursor
		end
	end

	local cursorRadius = Config.MIN_CURSOR_HIT_RADIUS
	if cursor then
		local absoluteSize = cursor.AbsoluteSize
		if absoluteSize then
			cursorRadius = math.max(absoluteSize.X, absoluteSize.Y) * 0.35 + Config.SCAN_HITBOX_MODIFIER * 0.8
		end
	end

	cursorRadius = math.max(cursorRadius, Config.MIN_CURSOR_HIT_RADIUS * 0.9)

	for _, object in scannables do
		local instance = object and object.Instance
		if not instance or not instance:IsDescendantOf(workspace) then
			self._scannableCache = nil
			self._scannableCacheTime = 0
			continue
		end

		local distance = (object.Position - pointerPosition).Magnitude
		local objectRadius = object.Radius or 0
		local adjustedDistance = distance - objectRadius
		if adjustedDistance < closestDistance then
			closestDistance = adjustedDistance
			closestTarget = object
		end
	end

	if closestDistance <= cursorRadius then
		return closestTarget
	end

	return nil
end

return TargetManager
