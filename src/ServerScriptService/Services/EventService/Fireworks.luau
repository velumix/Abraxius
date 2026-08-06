local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local FireworkEventConfig = require(ReplicatedStorage.Config.FireworkEventConfig)

return {
	Duration = FireworkEventConfig.DEFAULT_DURATION,

	Activate = function(context)
		local cfg = context.Config or {}
		local duration = cfg.duration or FireworkEventConfig.DEFAULT_DURATION

		local service = Knit.GetService("FireworkEventService")
		service:Start(duration)

		-- Safety cleanup in case SparkMod cleans up the trove before Deactivate fires.
		if context.trove then
			context.trove:Add(function()
				service:Stop()
			end)
		end
	end,

	Deactivate = function()
		Knit.GetService("FireworkEventService"):Stop()
	end,
}
