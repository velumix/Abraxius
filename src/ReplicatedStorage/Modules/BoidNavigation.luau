--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Modules.BoidNavigationData)

local Navigation = {}
local DIRECTIONS = {
	Vector3.xAxis,
	-Vector3.xAxis,
	Vector3.yAxis,
	-Vector3.yAxis,
	Vector3.zAxis,
	-Vector3.zAxis,
}
local DEFLECTION_DIRECTIONS = {}
for x = -1, 1 do
	for y = -1, 1 do
		for z = -1, 1 do
			if x ~= 0 or y ~= 0 or z ~= 0 then
				table.insert(DEFLECTION_DIRECTIONS, Vector3.new(x, y, z).Unit)
			end
		end
	end
end

local function decodeField(field)
	if field.bytes then
		return
	end

	local hex = field.reachableRle
	local totalCells = field.sizeX * field.sizeY * field.sizeZ
	local byteCount = math.ceil(totalCells / 8)
	local bytes = buffer.create(byteCount)
	local outputIndex = 0
	for sourceIndex = 1, #hex, 4 do
		local runLength = tonumber(string.sub(hex, sourceIndex, sourceIndex + 1), 16) or 0
		local value = tonumber(string.sub(hex, sourceIndex + 2, sourceIndex + 3), 16) or 0
		for _ = 1, runLength do
			if outputIndex >= byteCount then
				break
			end
			buffer.writeu8(bytes, outputIndex, value)
			outputIndex += 1
		end
	end
	field.bytes = bytes
	field.reachableRle = nil
end

local function worldToIndex(field, position)
	local cellSize = field.cellSize or Data.cellSize
	local x = math.floor(position.X / cellSize + 0.5) - field.minX + 1
	local y = math.floor(position.Y / cellSize + 0.5) - field.minY + 1
	local z = math.floor(position.Z / cellSize + 0.5) - field.minZ + 1
	if x < 1 or x > field.sizeX or y < 1 or y > field.sizeY or z < 1 or z > field.sizeZ then
		return nil
	end
	return ((z - 1) * field.sizeY + (y - 1)) * field.sizeX + x
end

local function bitIsSet(field, index)
	if not index then
		return false
	end
	decodeField(field)
	local zeroIndex = index - 1
	local byteIndex = math.floor(zeroIndex / 8)
	if byteIndex >= buffer.len(field.bytes) then
		return false
	end
	return bit32.band(buffer.readu8(field.bytes, byteIndex), bit32.lshift(1, zeroIndex % 8)) ~= 0
end

function Navigation.GetField(node)
	if not node then
		return nil
	end
	local navigationId = node:GetAttribute("BoidNavigationId")
	return typeof(navigationId) == "string" and Data.fields[navigationId] or nil
end

function Navigation.IsNavigable(field, position)
	return field ~= nil and bitIsSet(field, worldToIndex(field, position))
end

function Navigation.IsSegmentNavigable(field, origin, destination)
	if not field then
		return false
	end
	local displacement = destination - origin
	local distance = displacement.Magnitude
	if distance < 0.001 then
		return Navigation.IsNavigable(field, destination)
	end

	local cellSize = field.cellSize or Data.cellSize
	local steps = math.max(1, math.ceil(distance / (cellSize * 0.4)))
	for step = 1, steps do
		if not Navigation.IsNavigable(field, origin + displacement * (step / steps)) then
			return false
		end
	end
	return true
end

function Navigation.GetAvoidance(field, position)
	if not field then
		return Vector3.zero
	end

	if not Navigation.IsNavigable(field, position) then
		local bestOffset = nil
		local bestDistance = math.huge
		for radius = 1, 4 do
			for _, direction in DIRECTIONS do
				local offset = direction * (field.cellSize or Data.cellSize) * radius
				if offset.Magnitude < bestDistance and Navigation.IsNavigable(field, position + offset) then
					bestOffset = offset
					bestDistance = offset.Magnitude
				end
			end
			if bestOffset then
				return bestOffset.Unit
			end
		end
		return Vector3.zero
	end

	local avoidance = Vector3.zero
	local blockedCount = 0
	for _, direction in DIRECTIONS do
		if not Navigation.IsNavigable(field, position + direction * (field.cellSize or Data.cellSize)) then
			avoidance -= direction
			blockedCount += 1
		end
	end
	if blockedCount == 0 or avoidance.Magnitude < 0.001 then
		return Vector3.zero
	end
	return avoidance.Unit * math.min(blockedCount / 3, 1)
end

function Navigation.GetNearestNavigablePosition(field, position, maximumRadius)
	if not field then
		return nil
	end
	if Navigation.IsNavigable(field, position) then
		return position
	end

	local bestPosition = nil
	local bestDistanceSquared = math.huge
	local cellSize = field.cellSize or Data.cellSize
	local centerX = math.floor(position.X / cellSize + 0.5)
	local centerY = math.floor(position.Y / cellSize + 0.5)
	local centerZ = math.floor(position.Z / cellSize + 0.5)
	for radius = 1, maximumRadius or 4 do
		for x = -radius, radius do
			for y = -radius, radius do
				for z = -radius, radius do
					if math.max(math.abs(x), math.abs(y), math.abs(z)) ~= radius then
						continue
					end
					local distanceSquared = x * x + y * y + z * z
					if distanceSquared >= bestDistanceSquared then
						continue
					end
					local candidate = Vector3.new(centerX + x, centerY + y, centerZ + z) * cellSize
					if Navigation.IsNavigable(field, candidate) then
						bestPosition = candidate
						bestDistanceSquared = distanceSquared
					end
				end
			end
		end
		if bestPosition then
			break
		end
	end
	return bestPosition
end

function Navigation.GetDeflectionDirection(field, position, desiredDirection, preferenceSeed)
	if not field then
		return Vector3.zero
	end
	if desiredDirection.Magnitude < 0.001 then
		desiredDirection = Vector3.zAxis
	else
		desiredDirection = desiredDirection.Unit
	end

	local seed = preferenceSeed or 0
	local preference = Vector3.new(math.sin(seed), math.sin(seed * 0.73) * 0.35, math.cos(seed))
	if preference.Magnitude > 0.001 then
		preference = preference.Unit
	end
	local avoidance = Navigation.GetAvoidance(field, position)
	local steeredDirection = desiredDirection + avoidance * 0.8
	if steeredDirection.Magnitude > 0.001 then
		steeredDirection = steeredDirection.Unit
	else
		steeredDirection = desiredDirection
	end

	local bestDirection = Vector3.zero
	local bestScore = -math.huge
	local probeDistance = (field.cellSize or Data.cellSize) * 0.9
	for _, direction in DEFLECTION_DIRECTIONS do
		local destination = position + direction * probeDistance
		if Navigation.IsSegmentNavigable(field, position, destination) then
			local forwardScore = direction:Dot(steeredDirection)
			local score = forwardScore * 4 + direction:Dot(preference) * 0.15
			if forwardScore < -0.15 then
				score -= 2
			end
			if score > bestScore then
				bestScore = score
				bestDirection = direction
			end
		end
	end
	return bestDirection
end

function Navigation.GetStats()
	local fieldCount = 0
	local encodedBytes = 0
	for _, field in Data.fields do
		fieldCount += 1
		encodedBytes += field.reachableRle and #field.reachableRle * 0.5 or buffer.len(field.bytes)
	end
	return {
		Version = Data.version,
		CellSize = Data.cellSize,
		FieldCount = fieldCount,
		EncodedBytes = encodedBytes,
	}
end

return Navigation
