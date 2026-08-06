--!nocheck
-- Studio-only static navigation baker. Run BakeToModule() after aquarium geometry changes.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CELL_SIZE = 1
local CELL_PADDING = 1
local PROBE_SCALE = 0.92
local TERRAIN_VOXEL_SIZE = 4
local TERRAIN_OCCUPANCY_THRESHOLD = 0.08
local QUERIES_PER_YIELD = 600
local NAVIGATION_ID_ATTRIBUTE = "BoidNavigationId"
local DIRECTIONS = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local Baker = {}

local function key3(x, y, z)
	return `{x},{y},{z}`
end

local function worldToCell(position, cellSize)
	return math.floor(position.X / cellSize + 0.5),
		math.floor(position.Y / cellSize + 0.5),
		math.floor(position.Z / cellSize + 0.5)
end

local function cellToWorld(x, y, z, cellSize)
	return Vector3.new(x * cellSize, y * cellSize, z * cellSize)
end

local function blockedKey(field, x, y, z)
	return `{field.cellSize}:{x},{y},{z}`
end

local function fieldIndex(field, x, y, z)
	local localX = x - field.minX + 1
	local localY = y - field.minY + 1
	local localZ = z - field.minZ + 1
	if
		localX < 1
		or localX > field.sizeX
		or localY < 1
		or localY > field.sizeY
		or localZ < 1
		or localZ > field.sizeZ
	then
		return nil
	end
	return ((localZ - 1) * field.sizeY + (localY - 1)) * field.sizeX + localX
end

local function setBit(bytes, index)
	local zeroIndex = index - 1
	local byteIndex = math.floor(zeroIndex / 8) + 1
	local bitIndex = zeroIndex % 8
	bytes[byteIndex] = bit32.bor(bytes[byteIndex] or 0, bit32.lshift(1, bitIndex))
end

local function bytesToRleHex(bytes, byteCount)
	local chunks = {}
	local index = 1
	while index <= byteCount do
		local value = bytes[index] or 0
		local runLength = 1
		while index + runLength <= byteCount and runLength < 255 and (bytes[index + runLength] or 0) == value do
			runLength += 1
		end
		table.insert(chunks, string.format("%02x%02x", runLength, value))
		index += runLength
	end
	return table.concat(chunks)
end

local function makeField(node)
	local navigationId = node:GetAttribute(NAVIGATION_ID_ATTRIBUTE)
	if typeof(navigationId) ~= "string" or navigationId == "" then
		navigationId = HttpService:GenerateGUID(false)
		node:SetAttribute(NAVIGATION_ID_ATTRIBUTE, navigationId)
	end
	local goal = node:GetAttribute("Goal")
	if not node:GetAttribute("Moves") or typeof(goal) ~= "Vector3" then
		goal = node.Position
	end
	local cellSize = CELL_SIZE

	local schoolSize = node:GetAttribute("SchoolSize")
	if typeof(schoolSize) ~= "number" then
		schoolSize = 5
	end
	local radius = math.clamp(schoolSize * 2, 10, 35)
	local verticalRadius = math.min(radius, 18)
	local minimum = Vector3.new(
		math.min(node.Position.X, goal.X) - radius,
		math.min(node.Position.Y, goal.Y) - verticalRadius,
		math.min(node.Position.Z, goal.Z) - radius
	)
	local maximum = Vector3.new(
		math.max(node.Position.X, goal.X) + radius,
		math.max(node.Position.Y, goal.Y) + verticalRadius,
		math.max(node.Position.Z, goal.Z) + radius
	)

	local minX, minY, minZ = worldToCell(minimum, cellSize)
	local maxX, maxY, maxZ = worldToCell(maximum, cellSize)
	minX -= CELL_PADDING
	minY -= CELL_PADDING
	minZ -= CELL_PADDING
	maxX += CELL_PADDING
	maxY += CELL_PADDING
	maxZ += CELL_PADDING

	return {
		key = navigationId,
		path = node:GetFullName(),
		node = node,
		cellSize = cellSize,
		minX = minX,
		minY = minY,
		minZ = minZ,
		maxX = maxX,
		maxY = maxY,
		maxZ = maxZ,
		sizeX = maxX - minX + 1,
		sizeY = maxY - minY + 1,
		sizeZ = maxZ - minZ + 1,
	}
end

local function createProbe()
	local probe = Instance.new("Part")
	probe.Name = "_BoidNavigationBakeProbe"
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.CastShadow = false
	probe.Transparency = 1
	probe.Size = Vector3.one * (CELL_SIZE * PROBE_SCALE)
	probe.Parent = workspace
	return probe
end

local function createOverlapParams(probe)
	local excluded = { probe }
	local animatedLifeForms = workspace:FindFirstChild("AnimatedLifeForms")
	if animatedLifeForms then
		table.insert(excluded, animatedLifeForms)
	end
	for _, node in CollectionService:GetTagged("Boid") do
		table.insert(excluded, node)
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.MaxParts = 1
	params.RespectCanCollide = true
	return params
end

local function terrainVoxelOccupied(terrainCache, x, y, z)
	local cacheKey = key3(x, y, z)
	local cached = terrainCache[cacheKey]
	if cached ~= nil then
		return cached
	end

	local minimum = Vector3.new(x, y, z) * TERRAIN_VOXEL_SIZE
	local region = Region3.new(minimum, minimum + Vector3.one * TERRAIN_VOXEL_SIZE)
	local _, occupancy = workspace.Terrain:ReadVoxels(region, TERRAIN_VOXEL_SIZE)
	local occupied = occupancy[1][1][1] > TERRAIN_OCCUPANCY_THRESHOLD
	terrainCache[cacheKey] = occupied
	return occupied
end

local function cellTouchesTerrain(terrainCache, center, cellSize)
	local halfSize = cellSize * PROBE_SCALE * 0.5
	local minimum = center - Vector3.one * halfSize
	local maximum = center + Vector3.one * halfSize
	local minX = math.floor(minimum.X / TERRAIN_VOXEL_SIZE)
	local minY = math.floor(minimum.Y / TERRAIN_VOXEL_SIZE)
	local minZ = math.floor(minimum.Z / TERRAIN_VOXEL_SIZE)
	local maxX = math.floor((maximum.X - 0.001) / TERRAIN_VOXEL_SIZE)
	local maxY = math.floor((maximum.Y - 0.001) / TERRAIN_VOXEL_SIZE)
	local maxZ = math.floor((maximum.Z - 0.001) / TERRAIN_VOXEL_SIZE)

	for z = minZ, maxZ do
		for y = minY, maxY do
			for x = minX, maxX do
				if terrainVoxelOccupied(terrainCache, x, y, z) then
					return true
				end
			end
		end
	end
	return false
end

local function findStartCell(field, blockedCache)
	local startX, startY, startZ = worldToCell(field.node.Position, field.cellSize)
	if not blockedCache[blockedKey(field, startX, startY, startZ)] then
		return startX, startY, startZ
	end

	for radius = 1, 6 do
		for z = startZ - radius, startZ + radius do
			for y = startY - radius, startY + radius do
				for x = startX - radius, startX + radius do
					if fieldIndex(field, x, y, z) and not blockedCache[blockedKey(field, x, y, z)] then
						return x, y, z
					end
				end
			end
		end
	end
	return nil
end

local function scanField(field, probe, overlapParams, blockedCache, terrainCache, progress)
	local totalCells = field.sizeX * field.sizeY * field.sizeZ
	local scanned = 0
	probe.Size = Vector3.one * (field.cellSize * PROBE_SCALE)
	for z = field.minZ, field.maxZ do
		for y = field.minY, field.maxY do
			for x = field.minX, field.maxX do
				local cacheKey = blockedKey(field, x, y, z)
				if blockedCache[cacheKey] == nil then
					local center = cellToWorld(x, y, z, field.cellSize)
					probe.CFrame = CFrame.new(center)
					local blockedByPart = #workspace:GetPartsInPart(probe, overlapParams) > 0
					blockedCache[cacheKey] = blockedByPart or cellTouchesTerrain(terrainCache, center, field.cellSize)
					progress.queries += 1
					if progress.queries % QUERIES_PER_YIELD == 0 then
						workspace:SetAttribute("BoidNavBakeQueries", progress.queries)
						RunService.Heartbeat:Wait()
						if workspace:GetAttribute("BoidNavBakeCancel") then
							error("Boid navigation bake cancelled")
						end
					end
				end
				scanned += 1
				workspace:SetAttribute("BoidNavBakeFieldProgress", scanned / totalCells)
			end
		end
	end
end

local function floodField(field, blockedCache)
	local startX, startY, startZ = findStartCell(field, blockedCache)
	if not startX then
		warn("No free navigation start cell", field.path)
		return "", 0
	end

	local totalCells = field.sizeX * field.sizeY * field.sizeZ
	local bytes = table.create(math.ceil(totalCells / 8), 0)
	local visited = {}
	local queueX, queueY, queueZ = {}, {}, {}
	local head = 1
	local tail = 1
	queueX[1], queueY[1], queueZ[1] = startX, startY, startZ
	visited[key3(startX, startY, startZ)] = true
	local reachable = 0

	while head <= tail do
		local x, y, z = queueX[head], queueY[head], queueZ[head]
		head += 1
		local index = fieldIndex(field, x, y, z)
		if index then
			setBit(bytes, index)
			reachable += 1
		end

		for _, direction in DIRECTIONS do
			local nextX = x + direction.X
			local nextY = y + direction.Y
			local nextZ = z + direction.Z
			local nextKey = key3(nextX, nextY, nextZ)
			if
				not visited[nextKey]
				and fieldIndex(field, nextX, nextY, nextZ)
				and not blockedCache[blockedKey(field, nextX, nextY, nextZ)]
			then
				visited[nextKey] = true
				tail += 1
				queueX[tail], queueY[tail], queueZ[tail] = nextX, nextY, nextZ
			end
		end
	end

	return bytesToRleHex(bytes, math.ceil(totalCells / 8)), reachable
end

local SHARD_SOURCE_LIMIT = 160000
local RLE_CHUNK_LENGTH = 120000
local SHARD_PREFIX = "BoidNavigationData_"

local function serializeFieldRecords(field)
	local records = {}
	local firstChunk = string.sub(field.reachable, 1, RLE_CHUNK_LENGTH)
	table.insert(
		records,
		table.concat({
			"\t{",
			`\t\tkey = {string.format("%q", field.key)},`,
			`\t\tminX = {field.minX}, minY = {field.minY}, minZ = {field.minZ},`,
			`\t\tsizeX = {field.sizeX}, sizeY = {field.sizeY}, sizeZ = {field.sizeZ},`,
			`\t\tcellSize = {field.cellSize},`,
			`\t\treachableRle = {string.format("%q", firstChunk)},`,
			"\t},",
		}, "\n")
	)
	for startIndex = RLE_CHUNK_LENGTH + 1, #field.reachable, RLE_CHUNK_LENGTH do
		local chunk = string.sub(field.reachable, startIndex, startIndex + RLE_CHUNK_LENGTH - 1)
		table.insert(records, string.format("\t{ key = %q, append = %q },", field.key, chunk))
	end
	return records
end

local function serializeShard(entries)
	local lines = {
		"--!nocheck",
		"-- Generated navigation shard. Do not edit by hand.",
		"return {",
	}
	for _, entry in entries do
		table.insert(lines, entry)
	end
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

local function serialize(fields)
	local shardSources = {}
	local entries = {}
	local currentSize = 80
	for _, field in fields do
		for _, entry in serializeFieldRecords(field) do
			assert(#entry < SHARD_SOURCE_LIMIT, `Navigation record {field.path} is too large for one shard`)
			if #entries > 0 and currentSize + #entry + 1 > SHARD_SOURCE_LIMIT then
				table.insert(shardSources, serializeShard(entries))
				entries = {}
				currentSize = 80
			end
			table.insert(entries, entry)
			currentSize += #entry + 1
		end
	end
	if #entries > 0 then
		table.insert(shardSources, serializeShard(entries))
	end

	local indexLines = {
		"--!nocheck",
		"-- Generated by ServerStorage.BoidNavigationBaker. Do not edit by hand.",
		"local modules = script.Parent",
		"local fields = {}",
	}
	for index in shardSources do
		local shardName = string.format("%s%03d", SHARD_PREFIX, index)
		table.insert(indexLines, `for _, record in require(modules.{shardName}) do`)
		table.insert(indexLines, "\tlocal field = fields[record.key]")
		table.insert(indexLines, "\tif record.append then")
		table.insert(indexLines, "\t\tfield.reachableRle ..= record.append")
		table.insert(indexLines, "\telse")
		table.insert(indexLines, "\t\tfields[record.key] = record")
		table.insert(indexLines, "\tend")
		table.insert(indexLines, "end")
	end
	table.insert(indexLines, string.format("return { version = 1, cellSize = %s, fields = fields }", CELL_SIZE))
	return table.concat(indexLines, "\n"), shardSources
end

function Baker.BakeToModule()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Bake navigation in Studio Edit mode")
	workspace:SetAttribute("BoidNavBakeCancel", false)
	workspace:SetAttribute("BoidNavBakeComplete", false)
	workspace:SetAttribute("BoidNavBakeQueries", 0)

	local fields = {}
	for _, node in CollectionService:GetTagged("Boid") do
		if node:IsA("BasePart") and node.Parent then
			table.insert(fields, makeField(node))
		end
	end
	table.sort(fields, function(a, b)
		return a.path == b.path and a.key < b.key or a.path < b.path
	end)

	local probe = createProbe()
	local overlapParams = createOverlapParams(probe)
	local blockedCache = {}
	local terrainCache = {}
	local progress = { queries = 0 }

	local ok, result, shardSources = xpcall(function()
		for index, field in fields do
			workspace:SetAttribute("BoidNavBakeField", field.path)
			workspace:SetAttribute("BoidNavBakeFieldIndex", index)
			workspace:SetAttribute("BoidNavBakeFieldCount", #fields)
			scanField(field, probe, overlapParams, blockedCache, terrainCache, progress)
			field.reachable, field.reachableCount = floodField(field, blockedCache)
		end
		return serialize(fields)
	end, debug.traceback)
	probe:Destroy()

	if not ok then
		workspace:SetAttribute("BoidNavBakeError", tostring(result))
		error(result)
	end

	local modules = ReplicatedStorage:FindFirstChild("Modules") or Instance.new("Folder")
	modules.Name = "Modules"
	modules.Parent = ReplicatedStorage
	for index, source in shardSources do
		local shardName = string.format("%s%03d", SHARD_PREFIX, index)
		local shard = modules:FindFirstChild(shardName) or Instance.new("ModuleScript")
		shard.Name = shardName
		shard.Source = source
		shard.Parent = modules
	end
	for _, child in modules:GetChildren() do
		if child:IsA("ModuleScript") and string.sub(child.Name, 1, #SHARD_PREFIX) == SHARD_PREFIX then
			local index = tonumber(string.sub(child.Name, #SHARD_PREFIX + 1))
			if not index or index > #shardSources then
				child:Destroy()
			end
		end
	end
	local output = modules:FindFirstChild("BoidNavigationData") or Instance.new("ModuleScript")
	output.Name = "BoidNavigationData"
	output.Source = result
	output.Parent = modules
	local totalSourceBytes = #result
	local largestShardBytes = 0
	for _, source in shardSources do
		totalSourceBytes += #source
		largestShardBytes = math.max(largestShardBytes, #source)
	end
	workspace:SetAttribute("BoidNavBakeSourceBytes", totalSourceBytes)
	workspace:SetAttribute("BoidNavBakeShardCount", #shardSources)
	workspace:SetAttribute("BoidNavBakeLargestShardBytes", largestShardBytes)
	workspace:SetAttribute("BoidNavBakeComplete", true)
	workspace:SetAttribute("BoidNavBakeId", HttpService:GenerateGUID(false))
	return output
end

return Baker
