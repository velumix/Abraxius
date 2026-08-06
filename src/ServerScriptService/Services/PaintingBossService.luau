local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local PaintingBossService = Knit.CreateService({
	Name = "PaintingBossService",
	Client = {
		EventStateChanged = Knit.CreateSignal(),
		EventEnded = Knit.CreateSignal(),
	},
})

local eventActive = false
local eventDuration: number? = nil
local eventEndsAt: number? = nil

local function buildEventStatePayload()
	local remaining = nil
	if eventActive and eventEndsAt then
		remaining = math.max(0, eventEndsAt - os.clock())
	end
	return {
		active = eventActive,
		duration = eventDuration,
		remaining = remaining,
	}
end

function PaintingBossService:SetEventActive(active: boolean, durationSeconds: number?, remainingSeconds: number?)
	eventActive = active and true or false
	if eventActive then
		eventDuration = durationSeconds
		local remaining = tonumber(remainingSeconds) or tonumber(durationSeconds) or 0
		eventEndsAt = os.clock() + math.max(0, remaining)
	else
		eventDuration = nil
		eventEndsAt = nil
	end
	self.Client.EventStateChanged:FireAll(buildEventStatePayload())
end

function PaintingBossService:IsEventActive(): boolean
	return eventActive
end

function PaintingBossService.Client:GetEventState(_player)
	return buildEventStatePayload()
end

function PaintingBossService:SetBossEventVictory()
	local matchManager = ServerScriptService:FindFirstChild("MatchManager")
	if matchManager then
		matchManager:SetAttribute("BossEventVictory", true)
	end
end

function PaintingBossService:SetBossEventTimeout()
	local matchManager = ServerScriptService:FindFirstChild("MatchManager")
	if matchManager then
		matchManager:SetAttribute("BossEventTimeout", true)
	end
end

function PaintingBossService:NotifyResult(won: boolean)
	local text = if won then "YOU WON - PAINTBALL KNIFE SKIN" else "YOU LOST - TRY AGAIN NEXT TIME"
	self.Client.EventEnded:FireAll({
		won = won,
		text = text,
	})
end

local function getMatchGameplayAction()
	return ServerScriptService:FindFirstChild("MatchGameplayAction")
end

local function getGetPhase()
	local matchManager = ServerScriptService:FindFirstChild("MatchManager")
	if not matchManager then return nil end
	return matchManager:FindFirstChild("GetPhase")
end

function PaintingBossService:ReleaseSeekers()
	local action = getMatchGameplayAction()
	if not action then
		warn("[PaintingBossService] MatchGameplayAction not found")
		return
	end
	local ok, result = pcall(function()
		return action:Invoke("ReleaseSeekers")
	end)
	if not ok then
		warn("[PaintingBossService] ReleaseSeekers failed: " .. tostring(result))
	end
end

function PaintingBossService:IsHidePhase(): boolean
	local getPhase = getGetPhase()
	if not getPhase then return false end
	local ok, phase = pcall(function()
		return getPhase:Invoke()
	end)
	return ok and phase == "HIDE"
end

return PaintingBossService
