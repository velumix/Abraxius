--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Events = require(ServerScriptService.SparkMod.Services.Events) :: any

local AdminSignalDispatcher = {}

type Entry = {
	kind: "broadcast" | "state",
	run: ((options: { [string]: any }) -> ())?,
	buildUpdate: ((options: { [string]: any }) -> { [string]: any }?)?,
}

local handlers: { [string]: { [string]: Entry } } = {}

local function inspectStatic(value: any): ({ kind: "state" | "broadcast", description: string }?)
	if typeof(value) ~= "table" then return nil end
	local description = if typeof(value.Description) == "string" then value.Description else ""
	if value.StateUpdate ~= nil then
		return { kind = "state", description = description }
	elseif typeof(value.Run) == "function" then
		return { kind = "broadcast", description = description }
	end
	return nil
end

function AdminSignalDispatcher.Register(
	eventName: string,
	signals: { [string]: any },
	ctx: any,
	advance: () -> ()
)
	if typeof(signals) ~= "table" then return end
	handlers[eventName] = handlers[eventName] or {}

	for action, value in signals do
		local info = inspectStatic(value)
		if not info then
			warn(`[AdminSignalDispatcher] {eventName}.{action} invalid shape`)
			continue
		end

		if info.kind == "broadcast" then
			local runFn = value.Run
			handlers[eventName][action] = {
				kind = "broadcast",
				run = function(options)
					local ok, err = pcall(runFn, ctx, advance, options or {})
					if not ok then
						warn(`[AdminSignalDispatcher] {eventName}.{action} Run error: {err}`)
					end
				end,
			}
		else
			local sUpdate = value.StateUpdate
			handlers[eventName][action] = {
				kind = "state",
				buildUpdate = if typeof(sUpdate) == "function"
					then function(options)
						local ok, result = pcall(sUpdate, ctx, options or {})
						if not ok then
							warn(`[AdminSignalDispatcher] {eventName}.{action} StateUpdate builder error: {result}`)
							return nil
						end
						return result
					end
					else function(_options) return sUpdate end,
			}
		end
	end
end

function AdminSignalDispatcher.Unregister(eventName: string, signals: { [string]: any }?)
	if not handlers[eventName] then return end
	if signals == nil then
		handlers[eventName] = nil
		return
	end
	for action in signals do
		handlers[eventName][action] = nil
	end
	if not next(handlers[eventName]) then
		handlers[eventName] = nil
	end
end

function AdminSignalDispatcher.GetKind(eventName: string, action: string): ("broadcast" | "state")?
	local entry = handlers[eventName] and handlers[eventName][action]
	return entry and entry.kind
end

function AdminSignalDispatcher.BuildStateUpdate(eventName: string, action: string, options: { [string]: any }?): { [string]: any }?
	local entry = handlers[eventName] and handlers[eventName][action]
	if not entry or entry.kind ~= "state" or not entry.buildUpdate then return nil end
	return entry.buildUpdate(options or {})
end

function AdminSignalDispatcher.Dispatch(eventName: string, action: string, options: { [string]: any }?): boolean
	local entry = handlers[eventName] and handlers[eventName][action]
	if not entry then
		warn(`[AdminSignalDispatcher] no handler for {eventName}.{action}`)
		return false
	end
	if entry.kind == "broadcast" and entry.run then
		entry.run(options or {})
		return true
	end
	if entry.kind == "state" and entry.buildUpdate then
		-- Fallback when origin wasn't a server with the event active.
		local update = entry.buildUpdate(options or {})
		if update then
			pcall(function() Events:UpdateState(eventName, update) end)
		end
		return true
	end
	return false
end

function AdminSignalDispatcher.HasHandler(eventName: string, action: string): boolean
	local bucket = handlers[eventName]
	return bucket ~= nil and bucket[action] ~= nil
end

function AdminSignalDispatcher.CollectManifest(handlersByName: { [string]: any }): { [string]: { [string]: string } }
	local manifest: { [string]: { [string]: string } } = {}

	local function pushSignals(eventName: string, signals: any)
		if typeof(signals) ~= "table" then return end
		for action, value in signals do
			local info = inspectStatic(value)
			if not info then continue end
			manifest[eventName] = manifest[eventName] or {}
			manifest[eventName][action] = info.description
		end
	end

	for eventName, handler in handlersByName do
		if typeof(handler) ~= "table" then continue end
		pushSignals(eventName, handler.AdminSignals)
		if typeof(handler.Stages) == "table" then
			for _, stage in handler.Stages do
				if typeof(stage) == "table" then
					pushSignals(eventName, stage.AdminSignals)
				end
			end
		end
	end

	return manifest
end

return AdminSignalDispatcher
