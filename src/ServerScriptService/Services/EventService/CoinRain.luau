local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RoundGatedEffect = require(script.Parent.Utilities.RoundGatedEffect)

return {
	Duration = 60,

	Activate = function(context)
		local cfg = context.Config or {}
		local duration = cfg.duration or 60
		local rate = cfg.rate or 4
		RoundGatedEffect.Bind(context, function()
			Knit.GetService("CoinRainService"):Start(duration, rate)
		end)
	end,

	Deactivate = function()
		Knit.GetService("CoinRainService"):Stop()
	end,
}
