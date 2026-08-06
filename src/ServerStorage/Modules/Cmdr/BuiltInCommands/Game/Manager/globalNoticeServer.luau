-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Players = game:GetService("Players") 

local Weave = require(ReplicatedStorage.Modules.Weave)

local Notice = Weave.Retrieve("Notice")
return function (_, Text,Duration,Color,Sound)
	Notice.GlobalNotice(Text,Color,Duration,Sound)
	return `Sent '{Text}' as a global notice.`
end