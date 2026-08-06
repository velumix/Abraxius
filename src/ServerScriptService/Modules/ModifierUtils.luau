local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

local ModifierUtils = {}

function ModifierUtils.inRound(player: Player): boolean
	return player:GetAttribute("InMatch") == true
end

function ModifierUtils.anyInRound(): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if ModifierUtils.inRound(player) then
			return true
		end
	end
	return false
end

function ModifierUtils.getMatchManager()
	return ServerScriptService:WaitForChild("MatchManager")
end

function ModifierUtils.getRole(player: Player): string?
	local matchManager = ModifierUtils.getMatchManager()
	local api = matchManager:FindFirstChild("GetRole")
	if api then
		return api:Invoke(player)
	end
	return nil
end

function ModifierUtils.forEachPlayerInRound(callback: (Player) -> ())
	for _, player in ipairs(Players:GetPlayers()) do
		if ModifierUtils.inRound(player) then
			pcall(callback, player)
		end
	end
end

function ModifierUtils.forEachHider(callback: (Player) -> ())
	for _, player in ipairs(Players:GetPlayers()) do
		if ModifierUtils.inRound(player) and ModifierUtils.getRole(player) == "Hider" then
			pcall(callback, player)
		end
	end
end

function ModifierUtils.forEachSeeker(callback: (Player) -> ())
	for _, player in ipairs(Players:GetPlayers()) do
		if ModifierUtils.inRound(player) and ModifierUtils.getRole(player) == "Seeker" then
			pcall(callback, player)
		end
	end
end

function ModifierUtils.getRandomMapPosition(yOffset: number?): Vector3?
	local bounds = MapManager.getBounds()
	if not bounds then
		return nil
	end
	local y = bounds.groundY + (yOffset or 3)
	local maxAttempts = 20
	for _ = 1, maxAttempts do
		local x = bounds.center.X + math.random(-bounds.halfX, bounds.halfX)
		local z = bounds.center.Z + math.random(-bounds.halfZ, bounds.halfZ)
		local origin = Vector3.new(x, y + 200, z)
		local result = Workspace:Raycast(origin, Vector3.new(0, -500, 0))
		if result then
			return result.Position + Vector3.new(0, yOffset or 3, 0)
		end
	end
	return bounds.center + Vector3.new(0, yOffset or 3, 0)
end

function ModifierUtils.applyColorToCharacter(character: Model, color: Color3)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = color
		end
	end
end

function ModifierUtils.cacheCharacterColors(character: Model): { [BasePart]: Color3 }
	local cache = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			cache[part] = part.Color
		end
	end
	return cache
end

function ModifierUtils.restoreCharacterColors(character: Model, cache: { [BasePart]: Color3 })
	for part, color in pairs(cache) do
		if part.Parent then
			part.Color = color
		end
	end
end

function ModifierUtils.randomBrightColor(): Color3
	local hue = math.random()
	local saturation = 0.5 + math.random() * 0.5
	local value = 0.7 + math.random() * 0.3
	return Color3.fromHSV(hue, saturation, value)
end

function ModifierUtils.getActiveMap(): Instance?
	return Workspace:FindFirstChild("ActiveMap")
end

function ModifierUtils.getMapBounds()
	return MapManager.getBounds()
end

function ModifierUtils.getActiveMapBoundingBox()
	local bounds = MapManager.getBounds()
	if not bounds then
		return nil
	end
	-- Build a horizontal bounding box from the cached map footprint.
	-- Height is an estimate; callers that only need X/Z extents and groundY
	-- should use getMapBounds() directly.
	local size = Vector3.new(bounds.halfX * 2, 100, bounds.halfZ * 2)
	local cf = CFrame.new(bounds.center.X, bounds.groundY, bounds.center.Z)
	return cf, size
end

function ModifierUtils.getMapGroundY(): number?
	local bounds = MapManager.getBounds()
	if bounds then
		return bounds.groundY
	end
	return nil
end

return ModifierUtils
