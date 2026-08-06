local ServerScriptService = game:GetService("ServerScriptService")
local MapService = require(ServerScriptService.MapBuilderServer.Services.MapService)

return function(context)
	local mapIds = MapService:GetPlayerMaps(context.Executor.UserId)
	if #mapIds == 0 then
		return "You haven't published any maps."
	end
	
	print(mapIds)

	return `Your maps: {table.concat(mapIds, ", ")}`
end