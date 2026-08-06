local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ColorSwapModifier = require(ServerScriptService.Modules.ColorSwapModifier)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)

return {
	Duration = 300,

	Activate = function(context)
		local duration = context.Config and context.Config.duration
		ModifierCoordinator.cancelAllExcept("ColorSwap")
		RoundGatedEffect.Bind(context, function()
			local ms = Knit.GetService("ModifierService")
			ms:Start("ColorSwap", "Color Swap", ColorSwapModifier.buildOptions(duration, ms))
		end)
	end,

	Deactivate = function()
		Knit.GetService("ModifierService"):Stop("ColorSwap")
	end,
}