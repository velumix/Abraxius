local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local MapManager = require(ServerScriptService.MapManager)
local CoinSpawner = require(ServerScriptService.CoinSpawner)
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)
local CoinPlacement = require(ServerScriptService.Modules.CoinPlacement)

local RainSpawnUtil = {}

local CONFIG = {
	FALL_HEIGHT = 50,
	MAX_CEILING_SEARCH = 150,
	CEILING_MARGIN = 1,
	BOUNDS_ATTEMPTS = 16,
	PLAYER_RADIUS = 120,
	PLAYER_ATTEMPTS = 6,
	MIN_FLOOR_NORMAL = 0.5,
	MAX_SURFACE_RISE = 12,
	BOUNDS_MARGIN = 0.9,
}

local function makeMapOnlyParams()
	local activeMap = MapManager.getActiveMap()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = activeMap and { activeMap } or {}
	p.IgnoreWater = true
	return p
end

local function findCeilingY(groundPos: Vector3): number?
	local origin = groundPos + Vector3.new(0, 0.5, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, CONFIG.MAX_CEILING_SEARCH, 0), makeMapOnlyParams())
	return hit and hit.Position.Y
end

local function makeStartPos(groundPos: Vector3): Vector3
	local desired = groundPos.Y + CONFIG.FALL_HEIGHT
	local startY = desired

	local ceilingY = findCeilingY(groundPos)
	if ceilingY then
		startY = math.min(startY, ceilingY - CONFIG.CEILING_MARGIN)
	end

	-- Keep at least a small visible drop above the landing spot.
	startY = math.max(startY, groundPos.Y + 2)

	return Vector3.new(groundPos.X, startY, groundPos.Z)
end

local function getRandomPlayerBase(): Vector3?
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if ModifierUtils.inRound(player) and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				table.insert(list, hrp.Position)
			end
		end
	end
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

local function getPlayerGroundPos(): Vector3?
	local playerBase = getRandomPlayerBase()
	if not playerBase then
		return nil
	end

	local params = makeMapOnlyParams()
	for _ = 1, CONFIG.PLAYER_ATTEMPTS do
		local angle = math.random() * math.pi * 2
		local radius = math.random() * CONFIG.PLAYER_RADIUS
		local x = playerBase.X + math.cos(angle) * radius
		local z = playerBase.Z + math.sin(angle) * radius
		local origin = Vector3.new(x, playerBase.Y + 50, z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -100, 0), params)
		if hit and hit.Normal.Y >= CONFIG.MIN_FLOOR_NORMAL then
			return hit.Position + Vector3.new(0, CoinSpawner.CONFIG.HOVER_HEIGHT, 0)
		end
	end

	-- Last resort: directly above the player.
	local origin = Vector3.new(playerBase.X, playerBase.Y + 50, playerBase.Z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -100, 0), params)
	if hit and hit.Normal.Y >= CONFIG.MIN_FLOOR_NORMAL then
		return hit.Position + Vector3.new(0, CoinSpawner.CONFIG.HOVER_HEIGHT, 0)
	end
	return nil
end

-- Pick a random spot on an interior floor. CoinPlacement already knows how to
-- find real floors (and avoid roofs/outside), so reuse that for rain.
local function getFloorGroundPos(): Vector3?
	return CoinPlacement.GetCoinSpawnPosition(CoinSpawner.CONFIG.HOVER_HEIGHT)
end

function RainSpawnUtil.getRainPositions(): (Vector3?, Vector3?)
	if not MapManager.isLoaded() then
		return nil, nil
	end

	-- Rain should cover the whole active map, so use the floor-aware placement first.
	local groundPos = getFloorGroundPos() or getPlayerGroundPos()

	if not groundPos then
		warn("[RainSpawnUtil] could not find a rain spawn position on the active map")
		return nil, nil
	end

	local startPos = makeStartPos(groundPos)
	return startPos, groundPos
end

return RainSpawnUtil
