local ServerScriptService = game:GetService("ServerScriptService")

return function(_context)
	local matchManager = ServerScriptService:WaitForChild("MatchManager")
	local api = matchManager:WaitForChild("EndRound", 10)
	if not api then
		return "MatchManager EndRound hook not available."
	end

	api:Invoke()
	return "Ending the current round..."
end
