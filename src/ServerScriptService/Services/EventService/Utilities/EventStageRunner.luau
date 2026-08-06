--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Signal = require(ReplicatedStorage.Packages.Signal) :: any
local AdminSignalDispatcher = require(script.Parent.AdminSignalDispatcher)
local Events = require(ServerScriptService.SparkMod.Services.Events) :: any

export type StageInfo = {
	name: string,
	index: number,
	total: number,
}

export type Stage = {
	Name: string,
	Enter: (ctx: any, advance: () -> (), stage: StageInfo) -> (),
	Exit: ((ctx: any, stage: StageInfo) -> ())?,
	AdminSignals: { [string]: any }?,
}

local EventStageRunner = {}

local function buildSkipSet(value: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if typeof(value) ~= "table" then return set end
	for _, name in value do
		if typeof(name) == "string" then set[name] = true end
	end
	return set
end

local function resolveStartIndex(stages: { Stage }, startStage: any): number
	if typeof(startStage) ~= "string" or startStage == "" then return 1 end
	for i, stage in stages do
		if stage.Name == startStage then return i end
	end
	warn(`[EventStageRunner] startStage '{startStage}' not found; defaulting to first`)
	return 1
end

local function runStages(context: any, stages: { Stage })
	local config = context.Config or {}
	local state = context.State or {}
	local skipSet = buildSkipSet(config.skipStages)
	local startStage = if typeof(state.currentStage) == "string"
		then state.currentStage
		else config.startStage
	local startIndex = resolveStartIndex(stages, startStage)

	local aborted = false
	local currentAdvance: (() -> ())? = nil
	local currentIndex = startIndex

	context.trove:Add(function()
		aborted = true
		local fn = currentAdvance
		currentAdvance = nil
		if fn then fn() end
	end)

	local stateConn = Events.StateChanged:Connect(function(eName: string, newState: any, _changedKeys: any)
		if eName ~= context.EventName then return end
		if typeof(newState) ~= "table" then return end
		local newCurrent = newState.currentStage
		if typeof(newCurrent) ~= "string" then return end
		local targetIndex = nil
		for i, stage in stages do
			if stage.Name == newCurrent then targetIndex = i; break end
		end
		if targetIndex and targetIndex > currentIndex and currentAdvance then
			currentAdvance()
		end
	end)
	context.trove:Add(function() stateConn:Disconnect() end)

	for i = startIndex, #stages do
		if aborted then return end
		local stage = stages[i]
		if skipSet[stage.Name] then continue end
		currentIndex = i

		-- Dedupe avoids HTTP-spam on hydration where state is already correct.
		if state.currentStage ~= stage.Name then
			state.currentStage = stage.Name
			pcall(function()
				Events:UpdateState(context.EventName, { currentStage = stage.Name })
			end)
		end

		local info: StageInfo = { name = stage.Name, index = i, total = #stages }

		local done = Signal.new()
		local advanced = false
		local function advance()
			if advanced then return end
			advanced = true
			done:Fire()
		end
		currentAdvance = advance

		if stage.AdminSignals then
			AdminSignalDispatcher.Register(context.EventName, stage.AdminSignals, context, advance)
		end

		local ok, err = pcall(stage.Enter, context, advance, info)
		if not ok then
			warn(`[EventStageRunner] {context.EventName}.{stage.Name} Enter error: {err}`)
			advance()
		end

		if not advanced then
			done:Wait()
		end
		done:Destroy()
		currentAdvance = nil

		if stage.AdminSignals then
			AdminSignalDispatcher.Unregister(context.EventName, stage.AdminSignals)
		end

		if aborted then return end

		if stage.Exit then
			local exitOk, exitErr = pcall(stage.Exit, context, info)
			if not exitOk then
				warn(`[EventStageRunner] {context.EventName}.{stage.Name} Exit error: {exitErr}`)
			end
		end
	end
end

-- Spawned in background so Activate returns before Events.Started fires.
-- Skip semantics: config.startStage = "Name" jumps to it; config.skipStages
-- = { "A" } drops named stages.
function EventStageRunner.Run(context: any, stages: { Stage })
	if not stages or #stages == 0 then return end
	task.spawn(runStages, context, stages)
end

return EventStageRunner
