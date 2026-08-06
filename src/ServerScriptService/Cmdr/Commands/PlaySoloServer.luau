local ServerScriptService = game:GetService("ServerScriptService")

return function(_context, role: string)
	local matchManager = ServerScriptService:WaitForChild("MatchManager")
	local setSolo = matchManager:WaitForChild("SetSolo", 10)
	if not setSolo then
		return "MatchManager solo hook not available."
	end

	local mapped
	if role == "Hunter" then
		mapped = "Seeker"
	elseif role == "Hider" then
		mapped = "Hider"
	else
		mapped = nil -- Off
	end

	local result = setSolo:Invoke(mapped)
	if result == nil then
		return "Solo testing disabled \u{2014} rounds need the normal player count again."
	end

	local label = result == "Seeker" and "Hunter" or "Hider"
	return `Solo testing ON as {label}. The next round starts with just you and won't auto-end (run PlaySolo Off to stop).`
end
