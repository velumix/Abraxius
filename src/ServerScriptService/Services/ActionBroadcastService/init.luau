local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MessagingService = game:GetService("MessagingService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Actions = require(ServerScriptService.SparkMod.Services.Actions)

local ACTION_FALLBACK_TOPIC = "SparkModActionFallback"

local ActionBroadcastService = Knit.CreateService({
	Name = "ActionBroadcastService",
	Client = {},
})

local ConfigParamService
local function fallbackEnabled(): boolean
	if not ConfigParamService then ConfigParamService = Knit.GetService("ConfigParamService") end
	return ConfigParamService:Get("sparkmod_events_fallback") == true
end

local function publishActionFallback(actionName, params, targetJobId)
	pcall(function()
		MessagingService:PublishAsync(ACTION_FALLBACK_TOPIC, {
			name = actionName,
			params = params,
			targetJobId = targetJobId,
		})
	end)
end

-- ========== Public API ========== --

function ActionBroadcastService:broadcast(actionName: string, params: { [string]: any }?)
	print(`[ActionBroadcastService] broadcast '{actionName}' (fallback={fallbackEnabled()})`)
	if fallbackEnabled() then
		publishActionFallback(actionName, params, nil)
		return { ok = true, fallback = true }
	end
	return Actions:Broadcast(actionName, params)
end

function ActionBroadcastService:broadcastLimited(actionName: string, params: { [string]: any }?, serverLimit: number)
	print(`[ActionBroadcastService] broadcastLimited '{actionName}' limit={serverLimit} (fallback={fallbackEnabled()})`)
	if fallbackEnabled() then
		-- can't cap server count; degrade to local
		warn("[ActionBroadcastService] fallback active: broadcastLimited degraded to local execute")
		local ok, err = Actions:ExecuteLocal(actionName, params)
		return { ok = ok, error = err, fallback = true }
	end
	return Actions:BroadcastLimited(actionName, params, serverLimit)
end

function ActionBroadcastService:broadcastToServer(targetJobId: string, actionName: string, params: { [string]: any }?)
	print(`[ActionBroadcastService] broadcastToServer '{actionName}' -> {targetJobId} (fallback={fallbackEnabled()})`)
	if fallbackEnabled() then
		publishActionFallback(actionName, params, targetJobId)
		return { ok = true, fallback = true }
	end
	return Actions:BroadcastToServer(targetJobId, actionName, params)
end

function ActionBroadcastService:executeLocal(actionName: string, params: { [string]: any }?): (boolean, string?)
	print(`[ActionBroadcastService] executeLocal '{actionName}'`)
	return Actions:ExecuteLocal(actionName, params)
end

-- ========== Lifecycle ========== --

function ActionBroadcastService:KnitStart()
	for _, handlerScript in script:GetChildren() do
		if handlerScript:IsA("ModuleScript") then
			Actions:Register(handlerScript.Name, require(handlerScript))
		end
	end

	pcall(function()
		MessagingService:SubscribeAsync(ACTION_FALLBACK_TOPIC, function(message)
			local d = message.Data
			if type(d) ~= "table" or not d.name then return end
			if d.targetJobId and d.targetJobId ~= game.JobId then return end
			print(`[ActionBroadcastService] received fallback action '{d.name}' target={d.targetJobId or "all"}`)
			Actions:ExecuteLocal(d.name, d.params)
		end)
	end)
end

return ActionBroadcastService
