local ServerScriptService = game:GetService("ServerScriptService")
local MapService = require(ServerScriptService.MapBuilderServer.Services.MapService)

return function(_context, count: number)
	count = count or 10

	local topMaps = MapService:GetTopMaps(count)
	if #topMaps == 0 then
		return "No maps found."
	end

	local lines = {}
	for i, entry in ipairs(topMaps) do
		table.insert(lines, `{i}. {entry.MapId} — {entry.Likes} likes`)
	end

	return table.concat(lines, "\n")
end