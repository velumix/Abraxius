local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)

return {
	Duration = 90,

	Activate = function(context)
		local cfg = context.Config or {}
		RoundGatedEffect.Bind(context, function()
			Knit.GetService("ChaosButtonService"):Start(cfg.amount, cfg.duration)
		end)
	end,

	Deactivate = function()
		Knit.GetService("ChaosButtonService"):Clear()
	end,
}