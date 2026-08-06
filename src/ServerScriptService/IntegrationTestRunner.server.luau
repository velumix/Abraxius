-- Studio-only integration smoke test. Disabled by default; enable and press Play.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EnvironmentConfig = require(ReplicatedStorage.Config.EnvironmentConfig)
local Knit = require(ReplicatedStorage.Modules.Knit)
local NetGuard = require(ServerScriptService.NetGuard)

local environment = EnvironmentConfig.Resolve()
assert(environment.UseMockData, "integration tests require Studio mock data")

Knit.OnStart():await()
local dataService = Knit.GetService("PlayerDataService")
local expectedPlayers = tonumber(game:GetAttribute("IntegrationExpectedPlayers")) or 1
local deadline = os.clock() + 15
while #Players:GetPlayers() < expectedPlayers and os.clock() < deadline do
	task.wait()
end
local testPlayers = Players:GetPlayers()
assert(#testPlayers >= expectedPlayers, `expected {expectedPlayers} players, got {#testPlayers}`)
for _, player in ipairs(testPlayers) do
	local profile = dataService:WaitForProfile(player, 10)
	assert(profile, `profile did not become ready for {player.UserId}`)
	assert(dataService:GetState(player) == "Ready", `profile state was not Ready for {player.UserId}`)
end

local player = testPlayers[1]

local coinsBefore = dataService:GetValue(player, "Coins")
local secondPlayerCoins = if testPlayers[2] then dataService:GetValue(testPlayers[2], "Coins") else nil
local coinsAfter = dataService:AwardCurrency(player, "Coins", 1, "IntegrationTest")
assert(coinsAfter == coinsBefore + 1, "typed currency mutation failed")
if testPlayers[2] then
	assert(dataService:GetValue(testPlayers[2], "Coins") == secondPlayerCoins, "player data leaked across profiles")
end
assert(dataService:_clientSnapshot(player).Commerce == nil, "private commerce data leaked to client snapshot")

local committed, result = dataService:RunCommittedMutation(player, function(data: { [any]: any })
	data.Points += 1
	return true, "COMMITTED"
end, 10)
assert(committed and result == "COMMITTED", `durable commit failed: {tostring(result)}`)

NetGuard.Define("__Integration.RateLimit", {
	RateLimit = { Requests = 1, Window = 10 },
})
for _, currentPlayer in ipairs(testPlayers) do
	local firstAllowed = NetGuard.Check(currentPlayer, "__Integration.RateLimit")
	assert(firstAllowed, `first guarded request was rejected for {currentPlayer.UserId}`)
end
local secondAllowed, secondReason = NetGuard.Check(player, "__Integration.RateLimit")
assert(not secondAllowed and secondReason == "RATE_LIMITED", "rate limit did not reject the second request")

print(`[INTEGRATION PASS] {#testPlayers} player(s): Knit, profiles, isolation, mutation, commit, privacy, and NetGuard`)
