local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CoinPlacement = require(script.Parent.Modules.CoinPlacement)
local MapService = require(script.Parent.MapBuilderServer.Services.MapService)

local MapManager = {}
MapManager.QueuedCustomMaps = {}

local MAPS_FOLDER = ServerStorage:WaitForChild("Maps")
local LOADED_NAME = "ActiveMap"
local DISABLED_MAPS = {
	Stadium = true,
}

local activeMap = nil
local activeMapName = nil

local activeBounds = nil
local spawnPoints = {}
local spawnBag = {}
local coinSpawnAreas = {}

local recentMaps = {}
local RECENT_KEEP = 2

local function pushRecent(name)
	if not name then
		return
	end

	for i = #recentMaps, 1, -1 do
		if recentMaps[i] == name then
			table.remove(recentMaps, i)
		end
	end
	table.insert(recentMaps, 1, name)
	while #recentMaps > RECENT_KEEP do
		table.remove(recentMaps)
	end
end

local function isRecent(name)
	for _, n in ipairs(recentMaps) do
		if n == name then
			return true
		end
	end
	return false
end

local function isMapEnabled(mapInstance)
	return mapInstance and DISABLED_MAPS[mapInstance.Name] ~= true
end

function MapManager.listMaps()
	local list = {}
	for _, m in ipairs(MAPS_FOLDER:GetChildren()) do
		if (m:IsA("Folder") or m:IsA("Model")) and isMapEnabled(m) then
			list[#list + 1] = m
		end
	end
	return list
end

function MapManager.getMapByName(name)
	if not name then
		return nil
	end
	for _, m in ipairs(MapManager.listMaps()) do
		if m.Name == name then
			return m
		end
	end
	return nil
end

function MapManager.chooseRandomMap()
	local list = MapManager.listMaps()
	if #list == 0 then
		return nil
	end
	if #list == 1 then
		return list[1]
	end

	local lastName = recentMaps[1]
	local candidates = {}
	for _, m in ipairs(list) do
		if m.Name ~= lastName then
			candidates[#candidates + 1] = m
		end
	end

	if #candidates == 0 then
		candidates = list
	end

	return candidates[math.random(1, #candidates)]
end

function MapManager.pickCandidates(count)
	count = count or 3
	local list = MapManager.listMaps()
	if #list == 0 then
		return {}
	end

	local eligible, recent = {}, {}
	for _, m in ipairs(list) do
		if isRecent(m.Name) then
			table.insert(recent, m)
		else
			table.insert(eligible, m)
		end
	end

	local function shuffle(t)
		for i = #t, 2, -1 do
			local j = math.random(1, i)
			t[i], t[j] = t[j], t[i]
		end
	end
	shuffle(eligible)

	local backfill = {}
	for i = #recentMaps, 1, -1 do
		for _, m in ipairs(recent) do
			if m.Name == recentMaps[i] then
				table.insert(backfill, m)
			end
		end
	end

	local chosen = {}
	for _, m in ipairs(eligible) do
		if #chosen >= count then
			break
		end
		table.insert(chosen, m)
	end
	for _, m in ipairs(backfill) do
		if #chosen >= count then
			break
		end
		table.insert(chosen, m)
	end
	return chosen
end

local forcedQueue = {}

local onForcedQueueChanged = nil
function MapManager.setForcedQueueChanged(cb)
	onForcedQueueChanged = cb
end
local function fireForcedQueueChanged()
	if onForcedQueueChanged then
		task.spawn(onForcedQueueChanged, MapManager.getForcedQueue())
	end
end

function MapManager.queueForcedMap(name, buyerName, buyerUserId, customMapData)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if DISABLED_MAPS[name] then
		return false
	end
	local last = forcedQueue[#forcedQueue]
	if last and last.name == name and last.buyerUserId == buyerUserId then
		return true
	end
	table.insert(forcedQueue, {
		name = name,
		buyerName = buyerName,
		buyerUserId = buyerUserId,
		customMapData = customMapData
	})
	fireForcedQueueChanged()
	return true
end

function MapManager.peekForcedMap()
	local entry = forcedQueue[1]
	if not entry then
		return nil
	end
	
	if entry.customMapData then
		print("!!!", entry.customMapData)
		local loadedMap = MapService:LoadMapToWorkspace(entry.customMapData.MapData)
		return loadedMap, true -- true meaning it's a custom map.
	end
	
	return MapManager.getMapByName(entry.name)
end

function MapManager.consumeForcedMap()
	local entry = table.remove(forcedQueue, 1)
	if entry then
		fireForcedQueueChanged()
	end
	return entry and entry.name or nil
end

function MapManager.hasForcedMap()
	return #forcedQueue > 0
end

function MapManager.getForcedQueue()
	local snapshot = {}
	for _, entry in ipairs(forcedQueue) do
		snapshot[#snapshot + 1] = {
			name = entry.name,
			buyerName = entry.buyerName,
			buyerUserId = entry.buyerUserId,
		}
	end
	return snapshot
end

local function computeBounds(mapInstance)
	local minX, minZ = math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local floorPart, floorY = nil, math.huge

	local function underMap(part)
		if part.Name == "OutOfBounds" then
			return true
		end
		local inst = part
		while inst and inst ~= mapInstance.Parent do
			if inst:GetAttribute("NoCoinSpawn") then
				return true
			end
			inst = inst.Parent
		end
		return false
	end
	for _, d in ipairs(mapInstance:GetDescendants()) do
		if d:IsA("BasePart") then
			local p, s = d.Position, d.Size
			minX = math.min(minX, p.X - s.X / 2)
			maxX = math.max(maxX, p.X + s.X / 2)
			minY = math.min(minY, p.Y - s.Y / 2)
			maxY = math.max(maxY, p.Y + s.Y / 2)
			minZ = math.min(minZ, p.Z - s.Z / 2)
			maxZ = math.max(maxZ, p.Z + s.Z / 2)

			-- Track the lowest large floor slab for a baseline ground height.
			if s.Y <= 6 and not underMap(d) then
				local topY = p.Y + s.Y / 2
				if topY < floorY then
					if s.X >= 40 and s.Z >= 40 then
						floorY = topY
						floorPart = d
					elseif s.X >= 4 and s.Z >= 4 and not floorPart then
						floorY = topY
						floorPart = d
					end
				end
			end
		end
	end
	if minX == math.huge then
		return nil
	end
	local groundY = floorPart and floorY or minY

	return {
		center = Vector3.new((minX + maxX) / 2, groundY, (minZ + maxZ) / 2),
		halfX = (maxX - minX) / 2,
		halfZ = (maxZ - minZ) / 2,
		groundY = groundY,
		minY = minY,
		maxY = maxY,
	}
end

local function gatherSpawnPoints(mapInstance)
	local points = {}
	local folder = mapInstance:FindFirstChild("SpawnPoints")
	if folder then
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") then
				points[#points + 1] = d
			end
		end
	end
	if #points == 0 then
		for _, d in ipairs(mapInstance:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "SpawnArea" then
				points[#points + 1] = d
			end
		end
	end
	return points
end

local function gatherCoinSpawnAreas(mapInstance)
	local areas = {}
	local folder = mapInstance:FindFirstChild("CoinSpawnAreas")
	if folder then
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(areas, d)
			end
		end
	end
	if #areas == 0 then
		for _, d in ipairs(mapInstance:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "CoinSpawnArea" then
				table.insert(areas, d)
			end
		end
	end
	return areas
end

function MapManager.unloadMap()
	if activeMap then
		activeMap:Destroy()
		activeMap = nil
	end

	local stray = Workspace:FindFirstChild(LOADED_NAME)
	while stray do
		stray:Destroy()
		stray = Workspace:FindFirstChild(LOADED_NAME)
	end
	activeBounds = nil
	spawnPoints = {}
	spawnBag = {}
	coinSpawnAreas = {}
	activeMapName = nil
end

function MapManager.loadMap(template, isCustom)
	MapManager.unloadMap()
	
	template = template or MapManager.chooseRandomMap()

	if not template then
		warn("[MapManager] no maps available in ServerStorage.Maps")
		return nil
	end

	local clone = (isCustom and template) or template:Clone()
	clone.Name = LOADED_NAME
	clone:SetAttribute("MapName", template.Name)
	clone.Parent = Workspace
	activeMap = clone
	activeMapName = template.Name
	pushRecent(template.Name)
	activeBounds = computeBounds(clone)
	spawnPoints = gatherSpawnPoints(clone)
	coinSpawnAreas = gatherCoinSpawnAreas(clone)
	CoinPlacement.SetMapData(clone, activeBounds, coinSpawnAreas, spawnPoints)
	spawnBag = {}
	if #spawnPoints == 0 then
		warn("[MapManager] loaded map '" .. template.Name .. "' has no SpawnPoints; player spawns will fall back to map center")
	end
	print("[MapManager] loaded map '" .. template.Name .. "' (" .. #spawnPoints .. " spawn points)")
	return clone
end

function MapManager.getActiveMap()
	return activeMap
end

function MapManager.getActiveMapName()
	return activeMapName
end

function MapManager.isLoaded()
	return activeMap ~= nil and activeMap.Parent == Workspace
end

function MapManager.getPlayerSpawnCFrame()
	if #spawnPoints == 0 then
		if not activeBounds then
			return nil
		end
		return CFrame.new(activeBounds.center + Vector3.new(0, 5, 0))
	end

	if #spawnBag == 0 then
		for i = 1, #spawnPoints do
			spawnBag[i] = i
		end

		for i = #spawnBag, 2, -1 do
			local j = math.random(1, i)
			spawnBag[i], spawnBag[j] = spawnBag[j], spawnBag[i]
		end
	end
	local idx = table.remove(spawnBag)
	local marker = spawnPoints[idx]
	if not (marker and marker.Parent) then
		marker = spawnPoints[1]
	end

	local top = marker.Position.Y + marker.Size.Y / 2
	return CFrame.new(marker.Position.X, top + 0.5, marker.Position.Z)
end

function MapManager.getCoinSpawnPosition(hoverHeight, maxSlope, maxRise)
	return CoinPlacement.GetCoinSpawnPosition(hoverHeight, maxSlope)
end

function MapManager.getBounds()
	return activeBounds
end

ReplicatedStorage.GameRemotes.QueueForcedMap.Event:Connect(function(name, buyerName, buyerUserId, customMapData)
	MapManager.queueForcedMap(name, buyerName, buyerUserId, customMapData)
end)

_G.MapManager = MapManager
return MapManager
