-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Players = game:GetService("Players") 

local Weave = require(ReplicatedStorage.Modules.Weave)

local Notice = Weave.Retrieve("Notice")
return function (_, Text,Duration,Color,Sound) 
	for _, Player in Players:GetPlayers() do 
		Notice.SendNotice(Player, Text, Color, Duration, Sound)	
	end
	
	return `Sent '{Text}' as a local notice.`
end