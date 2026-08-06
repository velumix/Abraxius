local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)

return {
	Duration = 120,

	Activate = function(context)
		local duration = context.Config and context.Config.duration
		ModifierCoordinator.cancelAllExcept("PaintMutation")
		RoundGatedEffect.Bind(context, function()
			Knit.GetService("PaintMutationService"):Start(duration)
		end)
	end,

	Deactivate = function()
		Knit.GetService("PaintMutationService"):Clear()
	end,
}