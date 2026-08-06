local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataManager = require(ServerScriptService.Runtime.Source.PlayerDataManager)

return function(context, player, amount)
	if not player then
		return "Invalid player."
	end

	local newBalance = PlayerDataManager:GiveCash(player, amount)
	if not newBalance then
		return "Player data not loaded."
	end

	return `Gave {player.Name} ${amount}. New balance: ${newBalance}`
end
