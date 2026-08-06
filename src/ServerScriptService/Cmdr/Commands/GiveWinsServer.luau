local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local _stats
local function statsSvc()
	if not _stats then
		local ok, service = pcall(function()
			return Knit.GetService("StatsService")
		end)
		if ok then
			_stats = service
		end
	end
	return _stats
end

return function(_context, player: Player, amount: number)
	local service = statsSvc()
	if not service then return "StatsService unavailable." end
	if amount == nil or amount <= 0 then return "Amount must be a positive number." end

	local granted = service:GiveWins(player, amount)
	if not granted then
		return `Could not grant wins to {player.Name}.`
	end

	return `Gave {amount} wins to {player.Name}.`
end