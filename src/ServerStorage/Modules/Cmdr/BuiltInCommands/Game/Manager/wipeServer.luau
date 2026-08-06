-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Weave = require(ReplicatedStorage.Modules.Weave)

local DataManager , DataSync = Weave.Retrieve{"DataManager", "DataSync"}
return function (_, Players : {Player})
	local FormatText = ""
	for _,Player : Player in Players  do 
		DataManager.ResetProfile(Player)
		FormatText ..= `{Player.DisplayName},`
		task.wait(0.1) 
		DataSync.UpdatePlayer(Player,"All")
	end
	return ("Reset %s the have now been completely wiped!"):format(FormatText)
end