local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MatchConfig"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MatchRemotes = require(script.Parent:WaitForChild("MatchRemotes"))

local CONFIG = MatchConfig.CONFIG
local REVIVE_MIN_TIME_LEFT = MatchConfig.REVIVE_MIN_TIME_LEFT
local REVIVE_MAX = MatchConfig.REVIVE_MAX
local ReviveEligibilityRemote = MatchRemotes.ReviveEligibility

local roles = MatchState.roles
local found = MatchState.found
local reviveCount = MatchState.reviveCount

local ReviveRules = {}

function ReviveRules.nextReviveTier(player)
	local used = reviveCount[player] or 0
	if used >= REVIVE_MAX then
		return nil
	end
	return used + 1
end

function ReviveRules.roundTimeLeft()
	if MatchState.current ~= "ROUND" then
		return 0
	end
	return math.max(0, CONFIG.ROUND - (os.clock() - MatchState.roundStartTime))
end

function ReviveRules.canRevive(player)
	if not player or not player.Parent then
		return false
	end
	if MatchState.current ~= "ROUND" then
		return false
	end
	if MatchState.seekerGone then
		return false
	end
	if roles[player] ~= "Hider" then
		return false
	end
	if not found[player] then
		return false
	end
	if ReviveRules.roundTimeLeft() <= REVIVE_MIN_TIME_LEFT then
		return false
	end
	if MatchState.aliveHiderCount() < 1 then
		return false
	end
	if ReviveRules.nextReviveTier(player) == nil then
		return false
	end
	return true
end

function ReviveRules.sendReviveEligibility(player)
	if not player or not player.Parent then
		return
	end
	local ok = ReviveRules.canRevive(player)
	local tier = ok and ReviveRules.nextReviveTier(player) or nil
	ReviveEligibilityRemote:FireClient(player, {
		canRevive = ok,
		tier = tier,
	})
end

return ReviveRules
