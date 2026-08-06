-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage.Modules.Weave)

local DataManager = Weave.Retrieve("DataManager")
local DataSync = Weave.Retrieve("DataSync")

local PlayerManager = Weave.Retrieve("PlayerManager")

return function (_, Category, Amount, Players : {Player})
	if Weave.Config.ServerSettings.MainGameID == game.PlaceId and (Amount > 50000 or Amount < -50000) then 
		return "In the main game amounts must be less than 50,000!"
	end
	
	local FormatText = ""
	for _,Player : Player in Players do  
		PlayerManager.GiveCurrency(Player, Category, Amount, {
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,  
			`CMDR:GiveCurrency`
		}) 
		
		FormatText ..= Player.Name
	end
	
	return ("Give %s %s '%s' !"):format(FormatText, Amount, Category)
end