local ServerScriptService = game:GetService("ServerScriptService")
local MapService = require(ServerScriptService.MapBuilderServer.Services.MapService)
local MapManager = require(ServerScriptService.MapManager)

return function(_context, mapId)
	local mapInfo = MapService:LoadMap(mapId)
	if not mapInfo then
		warn("Failed to load map", mapId)
		return "Failed to load map"
	end

	print("Loaded:", mapInfo)
	
	MapService:RecordLoad(mapInfo)
	MapManager.queueForcedMap(mapInfo.Name, _context.Executor.DisplayName or _context.Executor.Name, _context.Executor, mapInfo)
	
	--table.insert(MapManager.QueuedCustomMaps, { Timestamp = os.time(), MapData = mapInfo.MapData })
	
	return mapInfo
end