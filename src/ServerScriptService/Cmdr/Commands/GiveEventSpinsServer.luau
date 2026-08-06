local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local _fireworkCrate
local function fireworkCrateSvc()
	if not _fireworkCrate then
		local ok, service = pcall(function()
			return Knit.GetService("FireworkCrateService")
		end)
		if ok then
			_fireworkCrate = service
		end
	end
	return _fireworkCrate
end

return function(_context, player: Player, amount: number)
	local service = fireworkCrateSvc()
	if not service then return "FireworkCrateService unavailable." end
	if amount == nil or amount <= 0 then return "Amount must be a positive number." end

	local granted = service:GrantSpins(player, amount, "GiveEventSpins command")
	if not granted then
		return `Could not grant event spins to {player.Name}.`
	end

	return `Gave {amount} event spins to {player.Name}.`
end
