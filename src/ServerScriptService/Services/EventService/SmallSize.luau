local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)
local SmallSizeModifier = require(ServerScriptService.Modules.SmallSizeModifier)

return {
	Duration = 60,

	Activate = function(context)
		local cfg = context.Config or {}
		local duration = cfg.duration
		local scale = cfg.scale
		local speedMult = cfg.speedMult

		ModifierCoordinator.cancelAllExcept("SmallSize")
		RoundGatedEffect.Bind(context, function()
			Knit.GetService("ModifierService"):Start(
				"SmallSize",
				"Small Size",
				SmallSizeModifier.buildOptions(duration, scale, speedMult)
			)
		end)
	end,

	Deactivate = function()
		Knit.GetService("ModifierService"):Stop("SmallSize")
	end,
}
