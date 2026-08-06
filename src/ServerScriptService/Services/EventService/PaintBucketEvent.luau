local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ModifierCoordinator = require(ServerScriptService.Modules.ModifierCoordinator)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)

return {
	Duration = 60,

	Activate = function(context)
		local cfg = context.Config or {}
		ModifierCoordinator.cancelAllExcept("PaintBucketEvent")
		RoundGatedEffect.Bind(context, function()
			Knit.GetService("PaintBucketEventService"):Start(cfg.count, cfg.duration)
		end)
	end,

	Deactivate = function()
		Knit.GetService("PaintBucketEventService"):Clear()
	end,
}