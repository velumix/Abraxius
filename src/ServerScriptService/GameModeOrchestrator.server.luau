local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GameModeRegistry = require(ServerScriptService:WaitForChild("GameModeRegistry"))
local GameModeVoteManager = require(ServerScriptService:WaitForChild("GameModeVoteManager"))
local GameModeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModeConfig"))
local StateChanged = require(ServerScriptService:WaitForChild("Match"):WaitForChild("MatchRemotes")).StateChanged

local knitStarted, knitErr = Knit.OnStart():await()
assert(knitStarted, knitErr)

local GameModeService = Knit.GetService("GameModeService")

local function buildContext(modeId)
	return {
		modeId = modeId,
		config = GameModeConfig.get(modeId),
		knit = Knit,
	}
end

print("[GameModeOrchestrator] starting mode loop")

local VOTE_SECONDS = 15
local PAINTING_BOSS_ANNOUNCE_SECONDS = 5

local function announcePaintingBossOverride()
	print("[GameModeOrchestrator] mode vote skipped/cancelled; Painting Boss is taking over the next round")
	for timeLeft = PAINTING_BOSS_ANNOUNCE_SECONDS, 1, -1 do
		StateChanged:FireAllClients({
			state = "INTERMISSION",
			voteSkipped = true,
			upcomingEvent = "Painting Boss",
			timeLeft = timeLeft,
		})
		task.wait(1)
	end
end

local function minPlayersToStart()
	local m = math.huge
	for _, cfg in ipairs(GameModeConfig.getVotable()) do
		m = math.min(m, cfg.minPlayers or 1)
	end
	return (m == math.huge) and 1 or m
end

while true do
	local voted = false
	-- A queued ForcePlay runs immediately (solo testing). Otherwise: WAIT until there are enough
	-- players to run a round, THEN open a mode-vote window before resolving -- so the very first
	-- round still gets a vote once the lobby fills, and the round that starts is the voted mode.
	if not GameModeService:ShouldSkipModeVote() then
		local need = minPlayersToStart()
		while #Players:GetPlayers() < need and not GameModeService:ShouldSkipModeVote() do
			task.wait(1)
		end
		if not GameModeService:ShouldSkipModeVote() and GameModeVoteManager.canVote() then
			GameModeVoteManager.openNextVote()
			voted = true
			print("[GameModeOrchestrator] mode vote window open (" .. VOTE_SECONDS .. "s)")
			local voteEnd = os.clock() + VOTE_SECONDS
			while os.clock() < voteEnd and not GameModeService:HasPaintingBossRoundOverride() do
				-- Surface the vote on every client's top-bar ("Voting for game mode") with a countdown.
				StateChanged:FireAllClients({ state = "INTERMISSION", voting = true, timeLeft = math.max(0, math.ceil(voteEnd - os.clock())) })
				task.wait(0.5)
			end
		end
	end

	if GameModeService:HasPaintingBossRoundOverride() then
		if voted then
			GameModeVoteManager.cancelVote()
		end
		announcePaintingBossOverride()
	end

	local modeId = GameModeService:ResolveNext()
	if voted then
		GameModeVoteManager.cancelVote()
	end
	GameModeService:SetActive(modeId)

	local mode = GameModeRegistry.get(modeId)
	if not mode then
		local fallback = GameModeRegistry.getDefaultId()
		warn("[GameModeOrchestrator] no module for '" .. tostring(modeId) .. "'; falling back to '" .. tostring(fallback) .. "'")
		modeId = fallback
		if modeId then
			GameModeService:SetActive(modeId)
			mode = GameModeRegistry.get(modeId)
		end
	end

	if not mode then
		warn("[GameModeOrchestrator] no runnable game mode found; retrying in 3s")
		task.wait(3)
	else
		local ctx = buildContext(modeId)
		if type(mode.init) == "function" and not mode._initialized then
			mode._initialized = true
			local okInit, errInit = xpcall(function()
				mode.init(ctx)
			end, debug.traceback)
			if not okInit then
				warn("[GameModeOrchestrator] init failed for '" .. modeId .. "':\n" .. tostring(errInit))
			end
		end

		local ok, err = xpcall(function()
			mode.run(ctx)
		end, debug.traceback)
		if not ok then
			warn("[GameModeOrchestrator] '" .. modeId .. "' crashed (recovered):\n" .. tostring(err))
			task.wait(3)
		end

		if type(mode.cleanup) == "function" then
			pcall(mode.cleanup, ctx)
		end
	end
end
