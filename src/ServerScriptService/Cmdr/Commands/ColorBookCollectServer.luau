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

return function(context, page, part, targetPlayer, mapName)
	local svc = cb()
	if not svc then return "ColoringBookService unavailable." end
	local player = targetPlayer or context.Executor
	if not player then return "No target player." end
	if not mapName or mapName == "" then mapName = activeMapName() end
	if not mapName or mapName == "" then return "No map given and no active map is loaded." end

	-- 'all' -> collect every part of the page (fast completion test)
	if part:lower() == "all" then
		local parts = svc:GetPageParts(mapName, page)
		if #parts == 0 then
			return ("No parts found for %s/%s (folder missing or empty)."):format(mapName, page)
		end
		local lastStatus
		for _, id in ipairs(parts) do
			local _, status = svc:CollectPart(player, mapName, page, id)
			lastStatus = status
		end
		local st = svc:GetPageState(player, mapName, page)
		return ("Collected all of %s/%s for %s -> %d/%d%s (last: %s)"):format(
			mapName, page, player.Name, st.collectedCount, st.total,
			st.complete and " COMPLETE" or "", tostring(lastStatus)
		)
	end

	local ok, status = svc:CollectPart(player, mapName, page, part)
	local st = svc:GetPageState(player, mapName, page)
	return ("%s %s/%s/%s for %s -> %d/%d%s [%s]"):format(
		ok and "OK" or "FAIL", mapName, page, part, player.Name,
		st.collectedCount, st.total, st.complete and " COMPLETE" or "", tostring(status)
	)
end
