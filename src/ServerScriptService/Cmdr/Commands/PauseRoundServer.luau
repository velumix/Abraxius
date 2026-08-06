local ServerScriptService = game:GetService("ServerScriptService")

return function(_context)
	local matchManager = ServerScriptService:WaitForChild("MatchManager")
	local api = matchManager:WaitForChild("PauseRound", 10)
	if not api then
		return "MatchManager PauseRound hook not available."
	end

	local paused, phase = api:Invoke()
	if paused then
		return `Match paused during the {tostring(phase)} phase. Run PauseRound again to resume.`
	end
	return `Match resumed (was {tostring(phase)}).`
end
