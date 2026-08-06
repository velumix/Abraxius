local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BoostConfig = require(ReplicatedStorage.Config.BoostConfig)
local EventDefinitions = require(ReplicatedStorage.Config.EventDefinitions)
local Luck = require(ServerScriptService.SparkMod.Services.Luck)

local BOOST_LUCK_ALIAS = "BoostLuck"

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
	option: number?,
	durationMinutes: number?
): string
	local requestedEventName = EventName
	local isLuckBoost = EventName == BoostConfig.EventName or EventName == BOOST_LUCK_ALIAS
	local isSpeedBoost = EventName == "SpeedBoost"
	local usesMultiplier = isLuckBoost or isSpeedBoost
	if EventName == BOOST_LUCK_ALIAS then
		EventName = BoostConfig.EventName
	end

	local definition = EventDefinitions.get(EventName)
	if not definition then
		return "Event not found: " .. requestedEventName
	end

	local eventMultiplier: number? = nil
	if option ~= nil then
		local optionDuration = parsePositiveNumber(option)
		if usesMultiplier then
			eventMultiplier = BoostConfig.parseMultiplier(option)
			if not eventMultiplier then
				return "Multiplier must be a positive whole number."
			end
		elseif optionDuration then
			durationMinutes = durationMinutes or optionDuration
		else
			return "Duration must be a positive number of minutes."
		end
	end
	if durationMinutes ~= nil then
		durationMinutes = parsePositiveNumber(durationMinutes)
		if not durationMinutes then
			return "Duration must be a positive number of minutes."
		end
	end

	local durationSeconds = if durationMinutes then durationMinutes * 60 else nil
	local config: EventConfig = { duration = durationSeconds }

	if usesMultiplier then
		eventMultiplier = eventMultiplier or BoostConfig.DefaultMultiplier
		durationMinutes = durationMinutes or BoostConfig.DefaultDurationMinutes
		durationSeconds = math.floor(durationMinutes * 60)
		config = {
			duration = durationSeconds,
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
	end

	local triggeredBy = context.Executor and context.Executor.DisplayName or "Server"
	local ok: boolean? = nil
	local err: unknown = nil
	local startOk, startErr = pcall(function()
		local knitReady, knitErr = Knit.OnStart():await()
		if not knitReady then
			error(knitErr or "Knit did not start")
		end
		ok, err = Knit.GetService("EventService"):startEvent(EventName, durationSeconds, false, config, nil, triggeredBy)
	end)

	if not startOk then
		return "Failed to start event: " .. tostring(startErr)
	end
	if not ok then
		return "Failed to start event: " .. tostring(err or "unknown error")
	end

	local durationText = if durationMinutes then string.format(" for %g minutes", durationMinutes) else ""
	return "Started event on this server: " .. EventDefinitions.getDisplayName(EventName, config) .. durationText
end
