local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

type ActiveEventDebug = {
	displayName: string,
	eventName: string,
	status: string,
	remainingSeconds: number,
	durationSeconds: number,
	requiredGameMode: string?,
	waitingForCompatibleRound: boolean,
	triggeredBy: string?,
	config: any,
	state: any,
}

type QueuedEventDebug = {
	displayName: string,
	eventName: string,
	scope: string,
	queuedForSeconds: number?,
	requiredGameMode: string?,
	activeGameMode: string?,
	ready: boolean,
	backendActive: boolean,
	durationSeconds: number?,
	triggeredBy: string?,
	config: any,
}

type EventDebugSnapshot = {
	generatedAt: number,
	server: {
		activeGameMode: string?,
		phase: string,
		mapLoaded: boolean,
		playersInRound: boolean,
		roundActive: boolean,
	},
	queued: { QueuedEventDebug },
	globalEvents: { ActiveEventDebug },
	localEvents: { ActiveEventDebug },
}

local function formatValue(value: any, depth: number?): string
	depth = depth or 0
	if typeof(value) == "string" then
		return string.format("%q", value)
	end
	if typeof(value) ~= "table" then
		return tostring(value)
	end
	if depth >= 2 then
		return "{...}"
	end
	local parts: { string } = {}
	for key, child in value do
		table.insert(parts, tostring(key) .. "=" .. formatValue(child, depth + 1))
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function addEventSection(lines: { string }, title: string, events: { ActiveEventDebug })
	table.insert(lines, string.format("%s (%d):", title, #events))
	if #events == 0 then
		table.insert(lines, "  (none)")
		return
	end
	for _, event in ipairs(events) do
		table.insert(
			lines,
			string.format(
				"  - %s [%s] | status=%s | remaining=%ss/%ss | requiredMode=%s | waiting=%s | by=%s | config=%s | state=%s",
				event.displayName,
				event.eventName,
				event.status,
				tostring(math.floor(event.remainingSeconds)),
				tostring(event.durationSeconds),
				event.requiredGameMode or "any",
				tostring(event.waitingForCompatibleRound),
				event.triggeredBy or "unknown",
				formatValue(event.config),
				formatValue(event.state)
			)
		)
	end
end

local function getSnapshot(): EventDebugSnapshot
	return Knit.GetService("EventService"):getDebugSnapshot() :: EventDebugSnapshot
end

return function(_context): string
	local snapshot = getSnapshot()
	local server = snapshot.server
	local lines: { string } = {
		"================ EVENT STATUS ================",
		string.format(
			"Server | mode=%s | phase=%s | mapLoaded=%s | playersInRound=%s | roundActive=%s",
			server.activeGameMode or "none",
			server.phase,
			tostring(server.mapLoaded),
			tostring(server.playersInRound),
			tostring(server.roundActive)
		),
		string.format("GeneratedAt | unix=%d", snapshot.generatedAt),
		"Queued events (" .. tostring(#snapshot.queued) .. "):",
	}

	if #snapshot.queued == 0 then
		table.insert(lines, "  (none)")
	else
		for _, event in ipairs(snapshot.queued) do
			table.insert(
				lines,
				string.format(
					"  - %s [%s] | scope=%s | queuedFor=%ss | requiredMode=%s | activeMode=%s | ready=%s | backendActive=%s | duration=%ss | by=%s | config=%s",
					event.displayName,
					event.eventName,
					event.scope,
					tostring(event.queuedForSeconds or "unknown"),
					event.requiredGameMode or "any",
					event.activeGameMode or "none",
					tostring(event.ready),
					tostring(event.backendActive),
					tostring(event.durationSeconds or "default"),
					event.triggeredBy or "unknown",
					formatValue(event.config)
				)
			)
		end
	end

	addEventSection(lines, "Global active events", snapshot.globalEvents)
	addEventSection(lines, "Local active events", snapshot.localEvents)
	table.insert(lines, "==============================================")

	print(table.concat(lines, "\n"))
	return string.format(
		"Event status printed to server console: %d queued, %d global active, %d local active.",
		#snapshot.queued,
		#snapshot.globalEvents,
		#snapshot.localEvents
	)
end
