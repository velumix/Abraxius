local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

return function(context)
	local player = context.Executor
	local players = { player }
	
	if RunService:IsStudio() then
		warn("Cannot run this command in studio")
		return
	end
	
	local placeId = game.PlaceId
	local code = TeleportService:ReserveServerAsync(game.PlaceId)
	
	TeleportService:TeleportToPrivateServer(placeId, code, players)
end
