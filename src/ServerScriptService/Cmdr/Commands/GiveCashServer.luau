local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local _coin
local function coinSvc()
	if not _coin then local ok, s = pcall(function() return Knit.GetService("CoinService") end) if ok then _coin = s end end
	return _coin
end

return function(_context, player: Player, amount: number)
	local cs = coinSvc()
	if not cs then return "CoinService unavailable." end
	if amount == nil or amount <= 0 then return "Amount must be a positive number." end
	cs:Credit(player, amount, "GiveCash command")
	return `Gave {amount} coins to {player.Name}.`
end