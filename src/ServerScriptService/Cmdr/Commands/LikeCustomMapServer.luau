local ServerScriptService = game:GetService("ServerScriptService")
local MapService = require(ServerScriptService.MapBuilderServer.Services.MapService)

return function(context, mapId: string)
	local success, reason = MapService:LikeMap(context.Executor, mapId)
	if success then
		return `Liked map "{mapId}".`
	end

	if reason == "already_liked" then
		return `You've already liked map "{mapId}".`
	end

	return `Failed to like map "{mapId}": {reason}.`
end