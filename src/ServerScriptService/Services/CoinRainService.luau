local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CoinSpawner = require(ServerScriptService.CoinSpawner)
local MapManager = require(ServerScriptService.MapManager)
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)
local RainSpawnUtil = require(ServerScriptService.Modules.RainSpawnUtil)

local CoinRainService = Knit.CreateService({
	Name = "CoinRainService",
	Client = {},
})

export type CoinRainService = {
	Start: (self: CoinRainService, duration: number?, rate: number?) -> boolean,
	Stop: (self: CoinRainService) -> (),
	IsRunning: (self: CoinRainService) -> boolean,
}

local CONFIG = {
	DEFAULT_DURATION = 30,
	DEFAULT_RATE = 4,
	MAX_RATE = 20,
	MAX_DURATION = 300,
}

local running = false
local rainThread = nil

function CoinRainService:Start(duration: number?, rate: number?): boolean
	if running then
		self:Stop()
	end

	duration = math.clamp(duration or CONFIG.DEFAULT_DURATION, 1, CONFIG.MAX_DURATION)
	rate = math.clamp(rate or CONFIG.DEFAULT_RATE, 1, CONFIG.MAX_RATE)

	if not MapManager.isLoaded() then
		warn("[CoinRainService] no active map loaded")
		return false
	end
	if not ModifierUtils.anyInRound() then
		warn("[CoinRainService] no active round")
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
				CoinSpawner.spawnFallingCoin(startPos, landingPos, CoinSpawner.CONFIG.COIN_VALUE)
			end

			task.wait(interval)
		end
		running = false
		rainThread = nil
	end)

	return true
end

function CoinRainService:Stop(): ()
	running = false
	rainThread = nil
end

function CoinRainService:IsRunning(): boolean
	return running
end

return CoinRainService :: CoinRainService
