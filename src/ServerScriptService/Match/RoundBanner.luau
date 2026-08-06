local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MatchRemotes = require(script.Parent:WaitForChild("MatchRemotes"))
local BackKnife = require(ServerScriptService:WaitForChild("BackKnife"))

local ScreenFade = MatchRemotes.ScreenFade
local WinSequence = MatchRemotes.WinSequence

local roles = MatchState.roles
local found = MatchState.found
local foundTime = MatchState.foundTime

local RoundBanner = {}

local deps = {}
function RoundBanner.init(d)
	deps = d
end

function RoundBanner.show(bossEventVictory, bossEventTimeout, seekersWin, resultText)
	local Placement = deps.placement
	local Knife = deps.knife

	local BANNER_HOLD = 2.0
	local FADE_IN_TIME = 0.5
	local FADE_OUT_TIME = 0.5

	local DEATH_SCREEN_DURATION = 1.5
	local lastKillAt = 0
	for _, t in pairs(foundTime) do
		if t and t > lastKillAt then
			lastKillAt = t
		end
	end
	if lastKillAt > 0 then
		local sinceKill = os.clock() - lastKillAt
		if sinceKill < DEATH_SCREEN_DURATION then
			task.wait(DEATH_SCREEN_DURATION - sinceKill)
		end
	end

	local function didWin(plr)
		local r = roles[plr]
		if not r then
			return false
		end
		if bossEventVictory then
			return true
		end
		if bossEventTimeout then
			return false
		end
		if seekersWin then
			return r == "Seeker"
		else
			return r == "Hider"
		end
	end

	local resultFadePlayers = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if roles[plr] ~= nil then
			resultFadePlayers[plr] = true
			ScreenFade:FireClient(plr, "in", { fadeTime = FADE_IN_TIME, maxHold = BANNER_HOLD + FADE_IN_TIME + FADE_OUT_TIME + 3 })
			WinSequence:FireClient(plr, {
				won = didWin(plr),
				winner = (bossEventVictory and "Everyone") or (bossEventTimeout and "Painting Boss") or (seekersWin and "Seeker" or "Hider"),
				headline = resultText,
				hold = BANNER_HOLD,
			})
		end
	end

	task.wait(FADE_IN_TIME + 0.1)
	for _, plr in ipairs(Players:GetPlayers()) do
		if roles[plr] ~= nil and not found[plr] then
			local ok, err = pcall(function()
				-- Respawn survivors back to the lobby instead of teleporting the map character.
				-- This cleanly clears pose/shift-lock/state issues that can survive a teleport.
				Knife.clearKnife(plr)
				BackKnife.setSuppressed(plr, false)
				Placement.setLobbyRespawn(plr)
				plr:LoadCharacter()
				deps.markSentToLobby(plr)
			end)
			if not ok then
				warn("[MatchManager] round-end lobby respawn failed for " .. plr.Name .. ": " .. tostring(err))
			end
		end
	end

	task.wait(BANNER_HOLD)
	for plr in pairs(resultFadePlayers) do
		if plr.Parent then
			ScreenFade:FireClient(plr, "out", { fadeTime = FADE_OUT_TIME })
		end
	end
	task.wait(FADE_OUT_TIME + 0.05)
	for plr in pairs(resultFadePlayers) do
		if plr.Parent then
			deps.clearRoundScreens(plr)
		end
	end
end

return RoundBanner
