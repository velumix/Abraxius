-- Modules // Sevices
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Weave = require(ReplicatedStorage.Modules.Weave)
local Unify = require(ReplicatedStorage.Modules.Unify)

local PlayerManager = Weave.Retrieve("PlayerManager")
local DataManager  = Weave.Retrieve("DataManager")
local ChatHandler =  Weave.Retrieve("Chat")
local RobloxAPIHandler = Weave.Retrieve("RobloxAPIHandler") 

return function (Context, Reason,Duration,PlayerID)
	local Result = ChatHandler.NewGlobalBan(PlayerID,Duration,Reason)
	
	local Success, Name = pcall(function() 
		return game:GetService("Players"):GetNameFromUserIdAsync(PlayerID)
	end)

	if not Success then 
		Name = "{PLAYERID:".. PlayerID .."}"
	end
	
	local FormattedBan = ("%s has been banned for %ss Reason(%s)!"):format(Name,Duration,Reason or "NO REASON") 
	
	task.spawn(function() 
		local https = game:GetService('HttpService')
		local data = https:JSONEncode{ 
			["embeds"] = {{
				["title"] = "BanID (GlobalIndexed)",
				["description"] = `**Moderator**:({Context.Executor.UserId}){Context.Executor.Name}\n**Player**:({PlayerID}){Name}\n**Reason**: {Reason}\n**Duration**(seconds): {Duration}`,
				["type"] = "rich",
				["color"] = tonumber(0x4287f5)

			}},
		}
		
		RobloxAPIHandler.HTTPQueue:PushAndWait()
		https:PostAsync('https://webhook.newstargeted.com/api/webhooks/1139800833064710184/bPS4w_2rILjWJLue1PGAID_5Td0y0bZ5RalFSKN-948Qk7FtoNPGX8TRgmANvqgf4-18', data, Enum.HttpContentType.ApplicationJson)
	end)
	
	
	if not PlayerManager.UseNewPlayersServiceBans then 
		local Profile = DataManager.ProfileStore:LoadProfileAsync("PID:" .. PlayerID)
		if Profile and Profile.Data then 
			Profile.Data.Banned = {
				IsForever = Duration >= math.huge or Duration <= -1,
				Reason = Reason
			}

			if not Profile.Data.Banned.IsForever then 
				Profile.Data.Banned.BannedUntil = Unify.GetServerTimeIn(Duration)
			end

			Profile:Release() 

			return "Profile was loaded"
		end
	end
	
	
	return Result or "Profile was not loaded"
end