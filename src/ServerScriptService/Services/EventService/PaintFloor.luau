local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PaintFloorModifier = require(ServerScriptService.Modules.PaintFloorModifier)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)

return {
	Duration = 300,

	Activate = function(context)
		local duration = context.Config and context.Config.duration
		ModifierCoordinator.cancelAllExcept("PaintFloor")
		RoundGatedEffect.Bind(context, function()
			Knit.GetService("ModifierService"):Start("PaintFloor", "Paint Floor", PaintFloorModifier.buildOptions(duration))
		end)
	end,

	Deactivate = function()
		Knit.GetService("ModifierService"):Stop("PaintFloor")
	end,
}