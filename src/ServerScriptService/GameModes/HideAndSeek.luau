local ServerScriptService = game:GetService("ServerScriptService")

local HideAndSeek = {
	id = "hideandseek",
}

local runMatchFn

local function getRunMatch()
	if runMatchFn then
		return runMatchFn
	end
	local matchManager = ServerScriptService:WaitForChild("MatchManager")
	runMatchFn = matchManager:WaitForChild("RunMatch")
	return runMatchFn
end

function HideAndSeek.run(ctx)
	getRunMatch():Invoke()
end

return HideAndSeek
