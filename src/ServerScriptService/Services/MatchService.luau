local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local MatchState = require(ServerScriptService:WaitForChild("Match"):WaitForChild("MatchState"))

local MatchService = Knit.CreateService({
	Name = "MatchService",
	Client = {},
})

function MatchService:GetRole(player)
	return MatchState.roles[player]
end

function MatchService:GetPhase()
	return MatchState.current
end

function MatchService:IsActiveHider(player)
	return MatchState.roles[player] == "Hider" and not MatchState.found[player]
end

function MatchService:GetActiveSeekers()
	local out = {}
	for _, s in ipairs(MatchState.seekers) do
		if s and s.Parent and MatchState.roles[s] == "Seeker" and not MatchState.seekerOut[s] then
			table.insert(out, s)
		end
	end
	return out
end

function MatchService:IsKnifeTarget(player)
	if MatchState.current == "REVEALING_HIDERS" then
		return false
	end
	return MatchState.roles[player] == "Hider" and not MatchState.found[player]
end

function MatchService:IsKnifeAttacker(player)
	return MatchState.roles[player] == "Seeker" and not MatchState.seekerOut[player]
end

local MatchManagerScript = ServerScriptService:WaitForChild("MatchManager")

local function invokeManagerApi(name, ...)
	local api = MatchManagerScript:FindFirstChild(name)
	if api and api:IsA("BindableFunction") then
		return api:Invoke(...)
	end
	warn("[MatchService] manager API not available: " .. name)
	return nil
end

function MatchService:SetSolo(role)
	return invokeManagerApi("SetSolo", role)
end

function MatchService:SkipPhase()
	return invokeManagerApi("SkipPhase")
end

function MatchService:EndRound()
	return invokeManagerApi("EndRound")
end

function MatchService:PauseRound()
	return invokeManagerApi("PauseRound")
end

function MatchService:MarkFound(player)
	return invokeManagerApi("MarkFound", player)
end

function MatchService:GameplayAction(action, ...)
	local api = ServerScriptService:FindFirstChild("MatchGameplayAction")
	if api and api:IsA("BindableFunction") then
		return api:Invoke(action, ...)
	end
	warn("[MatchService] MatchGameplayAction not available")
	return nil
end

return MatchService
