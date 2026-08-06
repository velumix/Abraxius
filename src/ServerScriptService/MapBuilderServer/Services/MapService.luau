--> Services
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")


--> Datastores
local MapDataStore = DataStoreService:GetDataStore("MapDataStore")
local MapPopularityDataStore = DataStoreService:GetDataStore("MapPopularityDataStore")
local MapLikesRankStore = DataStoreService:GetOrderedDataStore("MapLikesRank")
local MapLoadsRankStore = DataStoreService:GetOrderedDataStore("MapLoadsRank")
local MapLikedByStore = DataStoreService:GetDataStore("MapLikedBy")
local PlayerMapIndexStore = DataStoreService:GetDataStore("PlayerMapIndex")


--> Variables
local Packages = ReplicatedStorage.Packages
local Player = Players.LocalPlayer
local Remotes = ReplicatedStorage.GameRemotes


--> Modules
local Constants = require(ReplicatedStorage.Config.Constants)
local Component = require(Packages.Component)
local Trove = require(Packages.Trove)
local Knit = require(Packages.Knit)

--> Setup
local MapService = {}
MapService.TopMapsCache = { Likes = {}, Loads = {} }
MapService.PlayerMapsCache = {}
MapService.RequestingMaps = {}

--[[
	local mapInfo = {
		MapId = mapId,
		CreatorId = player.UserId,
		Name = (existingMap and existingMap.Name) or (player.Name .. "'s Map"),
		MapData = mapData,
		CreatedAt = (existingMap and existingMap.CreatedAt) or now,
		UpdatedAt = now,
	}
--]]


--> Turns table into cframe.
local function tableToCFrame(t)
	return CFrame.new(unpack(t))
end


--> Turns cframe into a table.
local function cframeToTable(cf)
	return {cf:GetComponents()}
end


--> Turns color3 into string for saving.
local function color3ToString(color)
	return string.format("%d,%d,%d",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end


--> Turns string to color3.
local function stringToColor3(str)
	if not str then return end
	local r, g, b = str:match("(%d+),(%d+),(%d+)")
	return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
end


local function attempt(fn, retries)
	retries = retries or 3
	local lastErr
	for i = 1, retries do
		local ok, resultOrErr = pcall(fn)
		if ok then
			return true, resultOrErr
		end
		lastErr = resultOrErr
		task.wait(0.5 * i)
	end
	return false, lastErr
end


local function generateMapId()
	return HttpService:GenerateGUID(false)
end


local function saveMap(mapId, mapInfo)
	local ok = attempt(function()
		MapDataStore:SetAsync(mapId, mapInfo)
	end)
	return ok
end


local function getMap(mapId)
	local ok, result = attempt(function()
		return MapDataStore:GetAsync(mapId)
	end)
	if not ok then
		return nil, result
	end
	return result, nil
end


local function deleteMap(mapId)
	return attempt(function()
		MapDataStore:RemoveAsync(mapId)
	end)
end


local function addMapToPlayerIndex(userId, mapId)
	local key = tostring(userId)
	return attempt(function()
		PlayerMapIndexStore:UpdateAsync(key, function(list)
			list = list or {}
			for _, id in ipairs(list) do
				if id == mapId then
					return list
				end
			end
			table.insert(list, mapId)
			return list
		end)
	end)
end


--> Removing a map from the players index
local function removeMapFromPlayerIndex(userId, mapId)
	local key = tostring(userId)
	return attempt(function()
		PlayerMapIndexStore:UpdateAsync(key, function(list)
			if not list then
				return list
			end
			for i, id in ipairs(list) do
				if id == mapId then
					table.remove(list, i)
					break
				end
			end
			return list
		end)
	end)
end


--> Remove stats from a map.
local function removeStats(mapId)
	attempt(function()
		MapPopularityDataStore:RemoveAsync(mapId)
	end)
	attempt(function()
		MapLikesRankStore:RemoveAsync(mapId)
	end)
	attempt(function()
		MapLoadsRankStore:RemoveAsync(mapId)
	end)
	attempt(function()
		MapLikedByStore:RemoveAsync(mapId)
	end)
end


--> Increment load times by map id.
local LOAD_FLUSH_INTERVAL = 180
local LOAD_FLUSH_JITTER = 30

local pendingLoadCounts = {}

local function recordLoad(mapId)
	if not mapId then return end
	pendingLoadCounts[mapId] = (pendingLoadCounts[mapId] or 0) + 1
end

local function flushLoadCounts()
	if next(pendingLoadCounts) == nil then return end
	local batch = pendingLoadCounts
	pendingLoadCounts = {}
	for mapId, delta in batch do
		if delta > 0 then
			attempt(function()
				MapPopularityDataStore:UpdateAsync(mapId, function(stats)
					stats = stats or { Likes = 0, Dislikes = 0, Loads = 0, CreatedAt = os.time() }
					stats.Loads = (stats.Loads or 0) + delta
					return stats
				end)
			end)
			attempt(function()
				MapLoadsRankStore:IncrementAsync(mapId, delta)
			end)
		end
	end
end


--> Liking a map.
local function likeMap(mapId, userId)
	local likeKey = mapId .. "_" .. tostring(userId)
	local alreadyLiked = false

	local ok1 = attempt(function()
		MapLikedByStore:UpdateAsync(likeKey, function(existing)
			if existing then
				alreadyLiked = true
				return existing
			end
			return true
		end)
	end)
	if not ok1 then
		return false, "datastore_error"
	end
	if alreadyLiked then
		return false, "already_liked"
	end

	attempt(function()
		MapPopularityDataStore:UpdateAsync(mapId, function(stats)
			stats = stats or { Likes = 0, Dislikes = 0, Loads = 0, CreatedAt = os.time() }
			stats.Likes = (stats.Likes or 0) + 1
			return stats
		end)
	end)
	attempt(function()
		MapLikesRankStore:IncrementAsync(mapId, 1)
	end)

	return true, "liked"
end


--> Gets full popularity stats (Likes, Dislikes, Loads) for a single map.
function MapService:GetMapStats(mapId)
	local ok, result = attempt(function()
		return MapPopularityDataStore:GetAsync(mapId)
	end)
	if not ok then
		return nil, result
	end
	return result, nil
end


--> Maps a sort key to its OrderedDataStore.
local RankStores = {
	Likes = { Store = MapLikesRankStore, Field = "Likes" },
	Loads = { Store = MapLoadsRankStore, Field = "Loads" },
}

--> Returns the top maps. SortBy = "Likes" or "Loads"
function MapService:GetTopMaps(count, sortBy)
	count = count or 10
	sortBy = sortBy or "Likes"

	local rankInfo = RankStores[sortBy]
	if not rankInfo then
		warn(("GetTopMaps: unknown sortBy '%s', defaulting to Likes"):format(tostring(sortBy)))
		rankInfo = RankStores.Likes
	end

	local ok, pages = attempt(function()
		return rankInfo.Store:GetSortedAsync(false, math.min(count, 100))
	end)
	if not ok then
		return {}
	end

	local results = {}
	for i, entry in ipairs(pages:GetCurrentPage()) do
		if i > count then
			break
		end
		local mapData = getMap(entry.key)
		table.insert(results, { MapId = entry.key, [rankInfo.Field] = entry.value, CreatorId = mapData.CreatorId, Name = mapData.Name })
	end
	return results
end


--> Loads a map's data and records a load for popularity tracking.
function MapService:LoadMap(mapId)
	local mapInfo, err = getMap(mapId)
	if not mapInfo then
		return nil, err or "not_found"
	end
	return mapInfo, nil
end


--> Like map function.
function MapService:LikeMap(player, mapId)
	return likeMap(mapId, player.UserId)
end


function MapService:RecordLoad(mapInfo)
	local mapId = mapInfo
	if type(mapInfo) == "table" then
		mapId = mapInfo.MapId or mapInfo.mapId
	end
	recordLoad(mapId)
end


--> Load map to workspace
function MapService:LoadMapToWorkspace(plotData)
	local pauseBetween = 10
	local count = 0

	local buildTemplate = ServerStorage.CustomMap:Clone()
	buildTemplate.Parent = workspace
	buildTemplate.Name = "BuildZone"

	buildTemplate.Floor.Color = stringToColor3(plotData.baseplateColor or "255,255,255")

	for _, blockData in plotData.blocks do
		local blockName = blockData.Name
		local blockColor = stringToColor3(blockData.Color) or Color3.fromRGB(255, 255, 255)
		local blockCFrame = tableToCFrame(blockData.CFrame)
		local block = ReplicatedStorage.Assets.Blocks.SELECTABLE:FindFirstChild(blockName)

		if not block then return end

		local blockClone = block:Clone()
		blockClone:PivotTo(blockCFrame)
		blockClone.Parent = buildTemplate.BlocksModel.Blocks

		local _, confirmedSaturation = Color3.toHSV(blockColor)

		local function applyTint(basePart)
			local originalColor = basePart:GetAttribute("OriginalColor")
			if not originalColor then return end
			basePart.Color = originalColor:Lerp(blockColor, confirmedSaturation * 0.75)
		end

		local model = blockClone.Parent:IsA("Model") and blockClone.Parent or blockClone:IsA("Model") and blockClone
		if model then
			for _, basePart in model:GetDescendants() do
				if basePart:IsA("BasePart") then
					applyTint(basePart)
				end
			end
		else
			applyTint(blockClone)
		end

		count = math.min(count + 1, pauseBetween)

		if count == pauseBetween then
			count = 0
			task.wait()
		end
	end

	buildTemplate.BlocksModel:PivotTo(buildTemplate.Floor:GetPivot())

	return buildTemplate
end


--> Gets players maps by userid.
function MapService:GetPlayerMaps(userId)
	local ok, result = attempt(function()
		return PlayerMapIndexStore:GetAsync(tostring(userId))
	end)
	if not ok then
		return {}
	end
	return result or {}
end


--> Adds cooldown
local function addCooldown(player, attribute, cooldown)
	player:SetAttribute(attribute, true)
	task.delay(cooldown, function()
		if player then
			player:SetAttribute(attribute, nil)
		end
	end)
end


--> Player added function. Handles loading player maps.
function MapService:PlayerAdded(player)
	repeat task.wait(1) until not player or player:GetAttribute("DataLoaded")

	local playerData = Knit.GetService("DataService"):Get(player)
	if not playerData then
		warn("No data found for", player)
		return
	end

	local builds = playerData.Builds or {}

	local userId = player.UserId
	local playersMaps = {}
	local loadedMaps = next(builds) ~= nil and MapService:GetPlayerMaps(userId) or {}

	for slot, playerMap in builds do
		if playerMap.mapId and table.find(loadedMaps, playerMap.mapId) then
			table.insert(playersMaps, {mapId = playerMap.mapId, slot = slot})
		end
	end

	MapService.PlayerMapsCache[userId] = playersMaps
	MapService.RequestingMaps[userId] = {}
end


--> Returns if the mapId is correct, then stores to attempting map queue.
function MapService:QueueMap(player, mapId)
	if not mapId then return end
	if player:GetAttribute("MapQueueCooldown") then return end
	player:SetAttribute("MapQueueCooldown", true)
	
	task.delay(60, function()
		if player then
			player:SetAttribute("MapQueueCooldown", nil)
		end
	end)
	
	local mapInfo = self:LoadMap(mapId)
	if not mapInfo then return end
	
	MapService.RequestingMaps[player.UserId] = mapInfo
	
	local isPrivateServer = game.PrivateServerId ~= ""
	if not isPrivateServer then
		MarketplaceService:PromptProductPurchase(player, Constants.QUEUE_CUSTOM_MAP_PRODUCT)
	else
		self:RecordLoad(mapInfo)
		ReplicatedStorage.GameRemotes.QueueForcedMap:Fire(mapInfo.Name, player.DisplayName or player.Name, player, mapInfo)
	end
	
	return true
end


--> Gets map that the players attempting to queue.
function MapService:GetPurchasingQueuedMap(player)
	if MapService.RequestingMaps[player.UserId] then
		return MapService.RequestingMaps[player.UserId]
	end
end


--> Removes player from cache.
function MapService:PlayerRemoving(player)
	local userId = player.UserId
	MapService.PlayerMapsCache[userId] = nil
	MapService.RequestingMaps[userId] = nil
end


--> Initialize function, connecting events etc.
function MapService:Initialize()
	if not Constants.CUSTOM_MAPS_ENABLED then
		workspace.MapBuilderPortal:Destroy()
		return
	end
	
	ReplicatedStorage.GameRemotes.GetTopMaps.OnServerInvoke = function(player)
		if player:GetAttribute("TopMapsLoadCooldown") then return end
		addCooldown(player, "TopMapsLoadCooldown", 3)
		repeat task.wait(1) until not player or MapService.TopMapsCache["Loads"]
		return MapService.TopMapsCache["Loads"]
	end

	ReplicatedStorage.GameRemotes.GetPlayerMaps.OnServerInvoke = function(player)
		if player:GetAttribute("PlayerMapsLoadCooldown") then return end
		addCooldown(player, "PlayerMapsLoadCooldown", 3)
		repeat task.wait(1) until not player or MapService.PlayerMapsCache[player.UserId]
		return MapService.PlayerMapsCache[player.UserId]
	end

	ReplicatedStorage.GameRemotes.RequestMapPurchase.OnServerInvoke = function(player, mapId)
		return self:QueueMap(player, mapId)
	end

	for _, player in Players:GetPlayers() do
		MapService:PlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function(player)
		MapService:PlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MapService:PlayerRemoving(player)
	end)

	task.spawn(function()
		while true do
			MapService.TopMapsCache.Likes = MapService:GetTopMaps(10, "Likes")
			MapService.TopMapsCache.Loads = MapService:GetTopMaps(10, "Loads")
			task.wait(5 * 60) -- refreshing every 5 minutes
		end
	end)

	task.spawn(function()
		while true do
			task.wait(LOAD_FLUSH_INTERVAL + math.random(0, LOAD_FLUSH_JITTER))
			flushLoadCounts()
		end
	end)

	game:BindToClose(function()
		flushLoadCounts()
	end)
end


return MapService