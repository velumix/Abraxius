-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage.Modules.Weave)

local DataManager = Weave.Retrieve("DataManager")
local DataSync = Weave.Retrieve("DataSync")

local LevelHandler = Weave.Retrieve("Levels")

return function (_, Category, XP, Players : {Player})
	local FormatText = ""
	for _,Player : Player in Players do  
		LevelHandler.GiveXP(Player, Category, XP)
		
	end
	
	return ("Give %s %s '%s' xp!"):format(FormatText,XP, Category)
end