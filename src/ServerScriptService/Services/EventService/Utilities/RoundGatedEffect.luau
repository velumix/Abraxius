local ServerScriptService = game:GetService("ServerScriptService")
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)

local RoundGatedEffect = {}

local LIVE_PHASES = { HIDE = true, ROUND = true }
local POLL_INTERVAL = 0.5

-- HIDE precedes InMatch: also require placed
local function roundActive(): boolean
	local mm = ServerScriptService:FindFirstChild("MatchManager")
	local api = mm and mm:FindFirstChild("GetPhase")
	if not api then return false end
	local ok, phase = pcall(function() return api:Invoke() end)
	if not ok or not LIVE_PHASES[phase] then return false end
	return ModifierUtils.anyInRound()
end

function RoundGatedEffect.Bind(context, applyFn, options)
	options = options or {}
	local alive = true
	local appliedForCurrentRound = false
	context.trove:Add(function()
		alive = false
	end)

	local function tryApply()
		if not alive or not roundActive() or appliedForCurrentRound then return end
		local ok, result = pcall(applyFn)
		if not ok then
			warn(`[RoundGatedEffect] {context.EventName or "event"} apply error: {result}`)
			if not options.retryWhileActive then
				appliedForCurrentRound = true
			end
			return
		end
		if result ~= false or not options.retryWhileActive then
			appliedForCurrentRound = true
		end
	end

	task.spawn(function()
		local prev = roundActive()
		if prev then tryApply() end
		while alive do
			task.wait(POLL_INTERVAL)
			local now = roundActive()
			if not now then
				appliedForCurrentRound = false
			end
			if now and (not prev or options.retryWhileActive) then tryApply() end
			prev = now
		end
	end)
end

return RoundGatedEffect
