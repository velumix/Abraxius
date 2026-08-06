local ServerScriptService = game:GetService("ServerScriptService")

return function(_context)
	local matchManager = ServerScriptService:WaitForChild("MatchManager")
	local api = matchManager:WaitForChild("SkipPhase", 10)
	if not api then
		return "MatchManager SkipPhase hook not available."
	end

	local phase = api:Invoke()
	return `Skipping the {tostring(phase)} phase...`
end
