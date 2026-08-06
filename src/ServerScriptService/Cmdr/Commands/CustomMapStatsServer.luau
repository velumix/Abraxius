local ServerScriptService = game:GetService("ServerScriptService")
local MapService = require(ServerScriptService.MapBuilderServer.Services.MapService)

return function(_context, mapId: string)
	local stats = MapService:GetMapStats(mapId)
	if not stats then
		return `Failed to get stats for map "{mapId}".`
	end

	return `Map {mapId} — Likes: {stats.Likes or 0}, Dislikes: {stats.Dislikes or 0}, Loads: {stats.Loads or 0}`
end