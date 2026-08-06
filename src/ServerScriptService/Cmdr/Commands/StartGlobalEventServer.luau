local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BoostConfig = require(ReplicatedStorage.Config.BoostConfig)
local EventDefinitions = require(ReplicatedStorage.Config.EventDefinitions)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local Luck = require(ServerScriptService.SparkMod.Services.Luck)

type CommandContext = { Executor: Player? }
type EventConfig = { [string]: any }

local function parsePositiveNumber(value: number): number?
	local number = tonumber(value)
	if number and number > 0 then
		return number
	end
	return nil
end

return function(
	context: CommandContext,
	EventName: string,
	value: number?,
	durationMinutes: number?
): string
	local definition = EventDefinitions.get(EventName)
	if not definition then
		return "Event not found: " .. EventName
	end

	local config: EventConfig = {}
	local isLuckBoost = EventName == "BoostLuck" or EventName == BoostConfig.EventName
	local isSpeedBoost = EventName == "SpeedBoost"
	local usesMultiplier = isLuckBoost or isSpeedBoost
	if usesMultiplier then
		local eventMultiplier = if value == nil then BoostConfig.DefaultMultiplier else BoostConfig.parseMultiplier(value)
		if not eventMultiplier then
			return "Multiplier must be a positive whole number."
		end
		durationMinutes = durationMinutes or BoostConfig.DefaultDurationMinutes
		durationMinutes = parsePositiveNumber(durationMinutes)
		if not durationMinutes then
			return "Duration must be a positive number of minutes."
		end
		config = {
			multiplier = eventMultiplier,
		}

		if isLuckBoost then
			config.channels = { BoostConfig.Channel }
			config.boostType = tostring(eventMultiplier)
		end

		if isLuckBoost and Luck._Init then
			local initOk, initErr = pcall(function()
				Luck._Init()
			end)
			if not initOk then
				return "Failed to initialize luck boost: " .. tostring(initErr)
			end
		end
	else
		durationMinutes = value
		if durationMinutes ~= nil then
			durationMinutes = parsePositiveNumber(durationMinutes)
			if not durationMinutes then
				return "Duration must be a positive number of minutes."
			end
		end
	end

	ModifierCoordinator.cancelGlobalSiblings(EventName)

	local durationSeconds = if durationMinutes then durationMinutes * 60 else nil
	config.duration = durationSeconds
	local triggeredBy = context.Executor and context.Executor.DisplayName or "Server"
	local success, err, queued = Knit.GetService("EventService")
		:startGlobalEvent(EventName, triggeredBy, durationMinutes, config)

	if success then
		local durationText = durationMinutes and (" for " .. durationMinutes .. " minutes") or ""
		if queued then
			local modeText = if definition.requiredGameMode == "hideandseek" then "Classic" else "a compatible"
			return "Queued global event: "
				.. EventDefinitions.getDisplayName(EventName, config)
				.. durationText
				.. " (preempting the active mode; starts when the "
				.. modeText
				.. " round is live; then syncs to all servers)"
		end
		return "Started global event: "
			.. EventDefinitions.getDisplayName(EventName, config)
			.. durationText
			.. " (syncing to all servers)"
	else
		return "Failed to start global event: " .. tostring(err or "unknown error")
	end
end
