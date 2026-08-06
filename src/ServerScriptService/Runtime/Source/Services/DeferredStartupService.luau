local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)

local CLIENT_READY_GRACE_SECONDS = 5

local DeferredStartupService = {
	Name = "DeferredStartupService",
}

local function waitForFirstClientHandshake()
	for _, player in Players:GetPlayers() do
		if Mince:GetHandshake(player) then
			return
		end
	end

	Mince.UponPlayerReadyHandshake:Wait()
end

local function runStep(name: string, callback: () -> ())
	local startedAt = os.clock()
	local success, result = xpcall(callback, debug.traceback)
	local duration = os.clock() - startedAt

	if success then
		print(`[DeferredStartup] {name} completed in {duration * 1000 // 1}ms.`)
	else
		warn(`[DeferredStartup] {name} failed after {duration * 1000 // 1}ms.`)
		warn(result)
	end
end

function DeferredStartupService:GameStart()
	task.spawn(function()
		waitForFirstClientHandshake()
		task.wait(CLIENT_READY_GRACE_SECONDS)

		runStep("Store cosmetic preload", function()
			Mince:Get("StoreService"):PreloadCosmeticAssets()
		end)
		task.wait()

		runStep("Adonis", function()
			Mince:Get("AdonisService"):StartDeferred()
		end)
		task.wait()

		runStep("Global notice subscription", function()
			Mince:Get("Notice"):StartSubscription()
		end)
	end)
end

return DeferredStartupService
