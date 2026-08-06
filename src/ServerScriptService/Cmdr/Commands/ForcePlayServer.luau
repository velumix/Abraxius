local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

return function(_context, modeId: string, mapType: string, role: string?)
	local ok, gameModeSvc = pcall(function()
		return Knit.GetService("GameModeService")
	end)
	if not ok or not gameModeSvc then
		return "GameModeService not available."
	end

	if not gameModeSvc:ForceNext(modeId) then
		return `"{modeId}" is not a valid game mode.`
	end

	local template = MapManager.getMapByName(mapType)
	if not template then
		return `"{mapType}" is not a valid map.`
	end
	MapManager.queueForcedMap(template.Name)

	local mapped = nil
	if role == "Hunter" then
		mapped = "Seeker"
	elseif role == "Hider" then
		mapped = "Hider"
	end
	local setSolo = ServerScriptService:WaitForChild("MatchManager"):FindFirstChild("SetSolo")
	if setSolo then
		setSolo:Invoke(mapped)
	end

	local roleLabel = (mapped ~= nil) and (" as " .. tostring(role)) or ""
	return `Next round forced: {modeId} on "{template.Name}"{roleLabel}.`
end
