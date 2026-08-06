local Workspace = game:GetService("Workspace")

local CoinPlacement = {}

local activeMap = nil
local activeBounds = nil
local coinSpawnAreas = {}
local floorParts = nil

local CONFIG = {
	MAX_FLOOR_THICKNESS = 6,
	MIN_FLOOR_SIZE = 2,
	SPAWN_HEIGHT_OFFSET = 3,
	MAX_SLOPE = 0.6,
	SPAWN_Y_TOLERANCE = 4,
	VERTICAL_MIDPOINT_MARGIN = 4,
	MAX_ATTEMPTS_AREAS = 8,
	MAX_ATTEMPTS_FLOORS = 16,
	MAX_ATTEMPTS_FALLBACK = 32,
}

local function isExcluded(part: BasePart): boolean
	if part.Name == "OutOfBounds" or part.Name == "Ceiling" or part.Name == "Roof" then
		return true
	end
	local inst: Instance? = part
	while inst and inst ~= Workspace do
		if inst:GetAttribute("NoCoinSpawn") then
			return true
		end
		if inst.Name == "OutOfBounds" then
			return true
		end
		inst = inst.Parent
	end
	return false
end

local function makeRayParams(map: Model?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = map and { map } or {}
	return params
end

local function validateHit(hit: RaycastResult?, hoverHeight: number, maxSlope: number): Vector3?
	if not hit then
		return nil
	end
	if hit.Normal.Y < maxSlope then
		return nil
	end
	local inst: Instance? = hit.Instance
	while inst and inst ~= Workspace do
		if inst:GetAttribute("NoCoinSpawn") then
			return nil
		end
		inst = inst.Parent
	end
	return hit.Position + Vector3.new(0, hoverHeight, 0)
end

local function gatherFloorParts(map: Model, spawnPoints: { BasePart }): { { [string]: any } }
	local parts = {}
	local minY, maxY = math.huge, -math.huge

	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") then
			local p, s = d.Position, d.Size
			minY = math.min(minY, p.Y - s.Y / 2)
			maxY = math.max(maxY, p.Y + s.Y / 2)
		end
	end

	local midY = (minY + maxY) / 2
	local thresholdY = midY + CONFIG.VERTICAL_MIDPOINT_MARGIN

	local spawnYSet: { [number]: boolean } = {}
	for _, sp in ipairs(spawnPoints) do
		if sp:IsA("BasePart") then
			spawnYSet[math.floor((sp.Position.Y - sp.Size.Y / 2) + 0.5)] = true
		end
	end

	for _, d in ipairs(map:GetDescendants()) do
		if not d:IsA("BasePart") or isExcluded(d) then
			continue
		end
		local s = d.Size
		if s.Y > CONFIG.MAX_FLOOR_THICKNESS or s.X < CONFIG.MIN_FLOOR_SIZE or s.Z < CONFIG.MIN_FLOOR_SIZE then
			continue
		end

		local topY = d.Position.Y + s.Y / 2
		local isFloor = false
		if next(spawnYSet) then
			for y in pairs(spawnYSet) do
				if math.abs(topY - y) <= CONFIG.SPAWN_Y_TOLERANCE then
					isFloor = true
					break
				end
			end
		else
			isFloor = topY <= thresholdY
		end

		if isFloor then
			table.insert(parts, {
				part = d,
				area = s.X * s.Z,
				minX = d.Position.X - s.X / 2,
				maxX = d.Position.X + s.X / 2,
				minZ = d.Position.Z - s.Z / 2,
				maxZ = d.Position.Z + s.Z / 2,
				topY = topY,
			})
		end
	end

	return parts
end

function CoinPlacement.SetMapData(
	map: Model,
	bounds: { [string]: any }?,
	areas: { BasePart }?,
	spawnPoints: { BasePart }?
)
	activeMap = map
	activeBounds = bounds
	coinSpawnAreas = areas or {}
	floorParts = map and gatherFloorParts(map, spawnPoints or {}) or nil
end

local function tryFromAreas(hoverHeight: number, maxSlope: number): Vector3?
	if #coinSpawnAreas == 0 then
		return nil
	end

	local params = makeRayParams(activeMap)
	for _ = 1, CONFIG.MAX_ATTEMPTS_AREAS do
		local area = coinSpawnAreas[math.random(1, #coinSpawnAreas)]
		local p, s = area.Position, area.Size
		local x = p.X + math.random(-1000, 1000) / 1000 * s.X / 2
		local z = p.Z + math.random(-1000, 1000) / 1000 * s.Z / 2
		local topY = p.Y + s.Y / 2
		local origin = Vector3.new(x, topY + 14, z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -(20 + s.Y), 0), params)
		local pos = validateHit(hit, hoverHeight, maxSlope)
		if pos then
			return pos
		end
	end
	return nil
end

local function tryFromFloorParts(hoverHeight: number, maxSlope: number): Vector3?
	if not floorParts or #floorParts == 0 then
		return nil
	end

	local totalArea = 0
	for _, c in ipairs(floorParts) do
		totalArea += c.area
	end

	local params = makeRayParams(activeMap)
	for _ = 1, CONFIG.MAX_ATTEMPTS_FLOORS do
		local pick = math.random() * totalArea
		local acc = 0
		local chosen = floorParts[1]
		for _, c in ipairs(floorParts) do
			acc += c.area
			if acc >= pick then
				chosen = c
				break
			end
		end

		local x = chosen.minX + math.random() * (chosen.maxX - chosen.minX)
		local z = chosen.minZ + math.random() * (chosen.maxZ - chosen.minZ)
		local origin = Vector3.new(x, chosen.topY + 2, z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -4, 0), params)
		local pos = validateHit(hit, hoverHeight, maxSlope)
		if pos then
			return pos
		end
	end
	return nil
end

local function fallbackColumnRaycast(hoverHeight: number, maxSlope: number): Vector3?
	if not activeBounds then
		return nil
	end
	local b = activeBounds

	local topY = (b.maxY or b.groundY + 50) + 10
	local bottomY = (b.minY or b.groundY) - 10
	local params = makeRayParams(activeMap)

	local function findLowestFlatSurface(x: number, z: number)
		local origin = Vector3.new(x, topY, z)
		local down = Vector3.new(0, -1, 0)
		local remaining = topY - bottomY + 20
		local lastFlatHit = nil

		for _ = 1, 20 do
			if remaining <= 0 then
				break
			end
			local hit = Workspace:Raycast(origin, down * remaining, params)
			if not hit then
				break
			end
			if hit.Normal.Y >= maxSlope then
				lastFlatHit = hit
			end
			origin = hit.Position + Vector3.new(0, -0.2, 0)
			remaining = math.max(0, origin.Y - bottomY + 5)
		end

		return lastFlatHit
	end

	for _ = 1, CONFIG.MAX_ATTEMPTS_FALLBACK do
		local x = b.center.X - b.halfX + math.random() * (b.halfX * 2)
		local z = b.center.Z - b.halfZ + math.random() * (b.halfZ * 2)
		local hit = findLowestFlatSurface(x, z)
		local pos = validateHit(hit, hoverHeight, maxSlope)
		if pos then
			return pos
		end
	end
	return nil
end

function CoinPlacement.GetCoinSpawnPosition(hoverHeight: number?, maxSlope: number?): Vector3?
	hoverHeight = hoverHeight or CONFIG.SPAWN_HEIGHT_OFFSET
	maxSlope = maxSlope or CONFIG.MAX_SLOPE

	return tryFromAreas(hoverHeight, maxSlope)
		or tryFromFloorParts(hoverHeight, maxSlope)
		or fallbackColumnRaycast(hoverHeight, maxSlope)
end

return CoinPlacement
