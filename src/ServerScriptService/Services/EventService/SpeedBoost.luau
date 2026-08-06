local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)
local SpeedBoostModifier = require(ServerScriptService.Modules.SpeedBoostModifier)

return {
	Duration = 60,

	Activate = function(context)
		local cfg = context.Config or {}
		local duration = cfg.duration
		local multiplier = tonumber(cfg.multiplier) or 2
		if multiplier <= 0 then
			multiplier = 2
		end

		ModifierCoordinator.cancelAllExcept("SpeedBoost")
		RoundGatedEffect.Bind(context, function()
			Knit.GetService("ModifierService"):Start(
				"SpeedBoost",
				"Super Speed",
				SpeedBoostModifier.buildOptions(duration, multiplier)
			)
		end)
	end,

	Deactivate = function()
		Knit.GetService("ModifierService"):Stop("SpeedBoost")
	end,
}
