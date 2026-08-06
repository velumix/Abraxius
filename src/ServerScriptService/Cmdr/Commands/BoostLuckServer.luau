local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local BoostConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BoostConfig"))
local Luck = require(ServerScriptService:WaitForChild("SparkMod"):WaitForChild("Services"):WaitForChild("Luck"))

return function(context, multiplier: number?, durationMinutes: number?)
	local config = BoostConfig.get(multiplier)
	if not config then
		return "Luck multiplier must be a positive whole number."
	end

	durationMinutes = durationMinutes or BoostConfig.DefaultDurationMinutes
	if type(durationMinutes) ~= "number" or durationMinutes <= 0 then
		return "Time must be a positive number of minutes."
	end

	if Luck._Init then
		local initOk, initErr = pcall(function()
			Luck._Init()
		end)
		if not initOk then
			return "Failed to initialize luck boost: " .. tostring(initErr)
		end
	end

	local durationSeconds = math.floor(durationMinutes * 60)
	local triggeredBy = context.Executor and context.Executor.DisplayName or "Server"
	local success, err
	local startOk, startErr = pcall(function()
		local knitReady, knitErr = Knit.OnStart():await()
		if not knitReady then
			error(knitErr or "Knit did not start")
		end

		success, err = Knit.GetService("EventService"):startGlobalEvent(BoostConfig.EventName, triggeredBy, durationMinutes, {
			duration = durationSeconds,
			multiplier = config.multiplier,
			channels = { BoostConfig.Channel },
			boostType = config.id,
		})
	end)

	if not startOk then
		return "Failed to start luck boost: " .. tostring(startErr)
	end

	if not success then
		return "Failed to start luck boost: " .. (err or "unknown error")
	end

	return string.format("Started global %s for %s minute(s).", config.displayName, tostring(durationMinutes))
end