-- Modules // Services 
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Mince = require(ReplicatedStorage.Modules.Mince)
local Unify = require(ReplicatedStorage.Modules.Unify)

local PlayerDataManager = Mince:Get("PlayerDataManager")

local CONSTS = table.freeze({
	DAY_IN_SECONDS = 86400
})

local SessionCounter = {} 


function SessionCounter.SavePlayerSessionTime(Player : Player, Profile)
	local LocalData = PlayerDataManager:GetLocalData(Player)  
	if not LocalData or not Profile or not Profile.Data then
		return
	end

	Profile.Data.SessionLength += Unify.GetServerTimeFrom(LocalData.JoinedOn) 

end


function SessionCounter.Setup() 
	PlayerDataManager.ProfileLoaded:Connect(function(Player, Profile) 	
		Profile.Data.LastSessionCounted = Profile.Data.LastSessionCounted or Unify.GetServerTime() 
		local TimePassed = Unify.GetServerTimeFrom(Profile.Data.LastSessionCounted) 
		if TimePassed > CONSTS.DAY_IN_SECONDS then 
			Profile.Data.SessionLength = 0
			Profile.Data.LastSessionCounted = Unify.GetServerTime() 
		end
	end)
	PlayerDataManager:WhenReleasing(SessionCounter.SavePlayerSessionTime)
end

return SessionCounter