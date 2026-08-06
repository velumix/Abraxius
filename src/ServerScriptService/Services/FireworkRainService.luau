local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CoinSpawner = require(ServerScriptService.CoinSpawner)
local MapManager = require(ServerScriptService.MapManager)
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)
local RainSpawnUtil = require(ServerScriptService.Modules.RainSpawnUtil)

local FireworkRainService = Knit.CreateService({
	Name = "FireworkRainService",
	Client = {},
})

export type FireworkRainService = {
	Start: (self: FireworkRainService, duration: number?, rate: number?) -> boolean,
	Stop: (self: FireworkRainService) -> (),
	IsRunning: (self: FireworkRainService) -> boolean,
}

local CONFIG = {
	DEFAULT_DURATION = 30,
	DEFAULT_RATE = 4,
	MAX_RATE = 20,
	MAX_DURATION = 300,
}

local running = false
local rainThread = nil
local EVENT_ACTIVE = false

function FireworkRainService:Start(duration: number?, rate: number?): boolean
	if not EVENT_ACTIVE then
		return false
	end
	if running then
		self:Stop()
	end

	duration = math.clamp(duration or CONFIG.DEFAULT_DURATION, 1, CONFIG.MAX_DURATION)
	rate = math.clamp(rate or CONFIG.DEFAULT_RATE, 1, CONFIG.MAX_RATE)

	if not MapManager.isLoaded() then
		warn("[FireworkRainService] no active map loaded")
		return false
	end
	if not ModifierUtils.anyInRound() then
		warn("[FireworkRainService] no active round")
		return false
	end

	running = true
	rainThread = task.spawn(function()
		local start = os.clock()
		local interval = 1 / rate
		while running do
			if os.clock() - start >= duration then
				break
			end
			if not MapManager.isLoaded() or not ModifierUtils.anyInRound() then
				break
			end

			local startPos, landingPos = RainSpawnUtil.getRainPositions()
			if startPos and landingPos then
				CoinSpawner.spawnFallingCoin(startPos, landingPos, CoinSpawner.CONFIG.FIREWORK_VALUE, true)
			end

			task.wait(interval)
		end
		running = false
		rainThread = nil
	end)

	return true
end

function FireworkRainService:Stop(): ()
	running = false
	rainThread = nil
end

function FireworkRainService:IsRunning(): boolean
	return running
end

return FireworkRainService :: FireworkRainService
