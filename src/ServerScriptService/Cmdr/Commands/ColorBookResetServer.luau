local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local _svc
local function cb()
	if not _svc then
		local ok, s = pcall(function() return Knit.GetService("ColoringBookService") end)
		if ok then _svc = s end
	end
	return _svc
end

return function(context, targetPlayer, mapName)
	local svc = cb()
	if not svc then return "ColoringBookService unavailable." end
	local player = targetPlayer or context.Executor
	if not player then return "No target player." end

	if mapName == "" then mapName = nil end
	svc:ResetBook(player, mapName) -- nil map = reset all maps

	if mapName then
		return ("Reset coloring book '%s' for %s."):format(mapName, player.Name)
	end
	return ("Reset ALL coloring books for %s."):format(player.Name)
end
