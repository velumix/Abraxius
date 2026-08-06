-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Weave = require(ReplicatedStorage.Modules.Weave)
local RobloxAPIHandler = Weave.Retrieve("RobloxAPIHandler") 


local PlayerManager, Chat  = Weave.Retrieve{"PlayerManager", "Char"}
return function (Context, Reason,Duration,Players : {Player})
	local FormatText = ""
	for _,Player : Player in Players  do 
		PlayerManager.BanPlayer(Player,Duration,Reason)
		FormatText ..= Player.Name .. ","
	end
	
	local FormattedBan = ("%s has been banned for %ss Reason(%s)!"):format(FormatText,Duration,Reason or "NO REASON") 
	
	task.spawn(function() 
		local https = game:GetService('HttpService')
		local data = https:JSONEncode{ 
			["embeds"] = {{
				["title"] = "BanLocal",
				["description"] = `**Moderator**:({Context.Executor.UserId}){Context.Executor.Name}\n**Players**: {FormatText}\n**Reason**: {Reason}\n**Duration**(seconds): {Duration}`,
				["type"] = "rich",
				["color"] = tonumber(0x4287f5)

			}},
		}
		
		RobloxAPIHandler.HTTPQueue:PushAndWait() 
		https:PostAsync('https://webhook.newstargeted.com/api/webhooks/1139800833064710184/bPS4w_2rILjWJLue1PGAID_5Td0y0bZ5RalFSKN-948Qk7FtoNPGX8TRgmANvqgf4-18', data, Enum.HttpContentType.ApplicationJson)

	end)

	return FormattedBan
end