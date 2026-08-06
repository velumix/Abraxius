local ServerScriptService = game:GetService("ServerScriptService")

local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

return function(_context, mapType: string)
	local template = MapManager.getMapByName(mapType)
	if not template then
		local names = {}
		for _, m in ipairs(MapManager.listMaps()) do
			table.insert(names, m.Name)
		end
		table.sort(names)
		return `"{mapType}" is not a valid map. Available: {table.concat(names, ", ")}`
	end

	MapManager.queueForcedMap(template.Name)
	return `Next round forced to "{template.Name}".`
end
