local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

local _svc
local function cb()
	if not _svc then
		local ok, s = pcall(function() return Knit.GetService("ColoringBookService") end)
		if ok then _svc = s end
	end
	return _svc
end

local function activeMapName()
	return MapManager.getActiveMapName and MapManager.getActiveMapName() or nil
end

return function(context, targetPlayer, mapName)
	local svc = cb()
	if not svc then return "ColoringBookService unavailable." end
	local player = targetPlayer or context.Executor
	if not player then return "No target player." end
	if not mapName or mapName == "" then mapName = activeMapName() end
	if not mapName or mapName == "" then return "No map given and no active map is loaded." end

	local pages = svc:GetPages(mapName)
	if #pages == 0 then
		return ("Map '%s' has no ColoringBook pages (folder missing or empty). Try ColorBookMock to author a test book."):format(mapName)
	end

	local lines = { ("[%s] coloring book '%s':"):format(player.Name, mapName) }
	for _, pageId in pages do
		local st = svc:GetPageState(player, mapName, pageId)
		lines[#lines + 1] = ("  %s: %d/%d%s%s"):format(
			pageId,
			st.collectedCount,
			st.total,
			st.complete and "  [COMPLETE]" or "",
			st.claimed and " (reward claimed)" or ""
		)
	end
	return table.concat(lines, "\n")
end
