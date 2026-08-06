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
	cs:CreditFireworks(player, amount, "GiveFireworks command")
	return `4th of July event is ended; gave {amount} coins to {player.Name} instead.`
end
