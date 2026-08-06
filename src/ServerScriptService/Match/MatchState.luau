local MatchState = {}

MatchState.roles = {}
MatchState.found = {}
MatchState.hiders = {}
MatchState.seekers = {}
MatchState.seekerOut = {}
MatchState.pity = {}
MatchState.lastSeekers = {}
MatchState.ownsSeekerGamepass = {}
MatchState.reviveCount = {}
MatchState.foundTime = {}
MatchState.kills = {}
MatchState.foundOrder = {}
MatchState.sizePurchasedThisRound = {}
MatchState.eliminating = {}
MatchState.diedConns = {}
MatchState.hiderPlacedAt = {}
MatchState.joinedAsSeeker = {}
MatchState.placing = {}

MatchState.current = "INTERMISSION"
MatchState.seekerGone = false
MatchState.roundStartTime = 0
-- Set true by the SkipPhase command; consumed by whichever mode is running (MatchManager's runTimer
-- for the regular mode, Reverse Race's phase waits) to end the current phase early.
MatchState.skipPhase = false
-- Persistent until the running mode returns to the orchestrator. Unlike skipPhase, this aborts the
-- entire special-mode round instead of advancing only its current phase.
MatchState.preemptRound = false

local roles = MatchState.roles
local found = MatchState.found
local hiders = MatchState.hiders
local seekers = MatchState.seekers
local seekerOut = MatchState.seekerOut

function MatchState.hiderStillParticipating(h)
	return h.Parent ~= nil
end

function MatchState.aliveHiderCount()
	local n = 0
	for _, h in ipairs(hiders) do
		if h.Parent ~= nil and not found[h] then
			n = n + 1
		end
	end
	return n
end

function MatchState.aliveHidersList()
	local list = {}
	for _, h in ipairs(hiders) do
		if h.Parent ~= nil and not found[h] then
			table.insert(list, h)
		end
	end
	return list
end

function MatchState.seekerCountActive()
	local n = 0
	for _, s in ipairs(seekers) do
		if s and s.Parent and roles[s] == "Seeker" and not seekerOut[s] then
			n += 1
		end
	end
	return n
end

function MatchState.allHidersFound()
	local liveHiders = 0
	for _, h in ipairs(hiders) do
		if h.Parent ~= nil then
			liveHiders += 1
			if not found[h] then
				return false
			end
		end
	end
	if liveHiders == 0 then
		return false
	end
	return true
end

return MatchState
