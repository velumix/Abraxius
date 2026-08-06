local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local GameModeRegistry = require(script.Parent.Parent.GameModeRegistry)
local GameModeVoteManager = require(script.Parent.Parent.GameModeVoteManager)
local GameModeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModeConfig"))

local GameModeService = Knit.CreateService({
	Name = "GameModeService",
	ActiveChangedSignal = Signal.new(),
	RoundPreemptRequestedSignal = Signal.new(),
	Client = {
		ActiveChanged = Knit.CreateSignal(),
	},
})

GameModeService.activeModeId = nil
GameModeService.nextModeId = nil
GameModeService.forcedModeId = nil
-- True when the CURRENT round was resolved from an explicit ForcePlay (one-shot). Modes can use
-- this to bypass their minimum-player requirement for solo testing; a normal/DEV_FORCE_MODE round
-- leaves it false so rounds only start with a natural roster.
GameModeService.forcedActive = false
GameModeService.EventService = nil
GameModeService.preemptTargetMode = nil

local PAINTING_BOSS_MODE_OVERRIDE = "hideandseek"

function GameModeService:KnitStart()
	self.EventService = Knit.GetService("EventService")
end

function GameModeService:GetActive()
	return self.activeModeId
end

function GameModeService:GetNext()
	return self.nextModeId
end

function GameModeService:SetActive(id)
	if not GameModeRegistry.exists(id) then
		warn("[GameModeService] SetActive called with unknown mode '" .. tostring(id) .. "'")
		return false
	end
	self.activeModeId = id
	self.ActiveChangedSignal:Fire(id)
	self.Client.ActiveChanged:FireAll(id)
	return true
end

function GameModeService:ForceNext(id)
	if id ~= nil and not GameModeRegistry.exists(id) then
		warn("[GameModeService] ForceNext called with unknown mode '" .. tostring(id) .. "'")
		return false
	end
	self.forcedModeId = id
	return true
end

function GameModeService:RequestRoundPreempt(targetModeId: string, reason: string?)
	if not GameModeRegistry.exists(targetModeId) then
		return false
	end
	if self.activeModeId == targetModeId then
		return false
	end
	self.preemptTargetMode = targetModeId
	print(
		`[GameModeService] preempting active mode '{self.activeModeId or "none"}' for '{targetModeId}' reason={reason or "unspecified"}`
	)
	self.RoundPreemptRequestedSignal:Fire(targetModeId, reason)
	return true
end

function GameModeService:GetRoundPreemptTarget(): string?
	return self.preemptTargetMode
end

function GameModeService:ShouldSkipModeVote()
	return self.forcedModeId ~= nil or self:HasPaintingBossRoundOverride()
end

function GameModeService:HasPaintingBossRoundOverride()
	local eventService = self.EventService
	if not eventService then
		return false
	end
	return eventService:isEventActive("PaintingBoss") or eventService:isEventQueuedForRound("PaintingBoss")
end

function GameModeService:ResolveNext()
	local id
	local forced = false
	-- PaintingBoss is a full-round objective built on the classic MatchManager flow.
	-- It must take over the next runnable round before forced, voted, or dev modes.
	if self:HasPaintingBossRoundOverride() then
		id = PAINTING_BOSS_MODE_OVERRIDE
	end
	-- Explicit one-shot ForcePlay takes precedence over everything (and marks the round forced,
	-- which lets modes bypass their min-player count for solo testing).
	if not id and self.forcedModeId and GameModeRegistry.exists(self.forcedModeId) then
		id = self.forcedModeId
		self.forcedModeId = nil
		forced = true
	end
	-- Persistent dev override: forces the MODE but does NOT bypass min players -- rounds still
	-- need a natural roster to start on their own.
	if not id then
		local devForce = GameModeConfig.DEV_FORCE_MODE
		if devForce then
			if GameModeRegistry.exists(devForce) then
				id = devForce
			else
				warn("[GameModeService] DEV_FORCE_MODE '" .. tostring(devForce) .. "' is not a registered mode; ignoring")
			end
		end
	end
	if not id and GameModeVoteManager.canVote() and GameModeVoteManager.isOpen() then
		id = GameModeVoteManager.resolveVote()
	end
	if not id or not GameModeRegistry.exists(id) then
		id = GameModeRegistry.getDefaultId()
	end
	self.nextModeId = id
	self.forcedActive = forced
	if id == self.preemptTargetMode then
		self.preemptTargetMode = nil
	end
	if id == PAINTING_BOSS_MODE_OVERRIDE and self:HasPaintingBossRoundOverride() then
		print("[GameModeService] PaintingBoss queued/active; resolving next round as hideandseek")
	end
	return id
end

function GameModeService.Client:GetActive()
	return self.Server.activeModeId
end

return GameModeService
