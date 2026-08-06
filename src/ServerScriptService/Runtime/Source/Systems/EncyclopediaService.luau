local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)

local PlayerDataManager
local DiscoveryEvent = Mince:GetEvent("Discovery")
local EncyclopediaService = {
	
	Events = {
		OnDiscovery = DiscoveryEvent:Extend("OnDiscovery"),
		RecordDiscovery = DiscoveryEvent:Extend("RecordDiscovery"),
		GetDiscoveries = Mince:GetFunction("GetDiscoveries")
	}
}



local ALLOWED_TYPES = {
	"Vertebrates", "Invertebrates", 
	"Corals and Plants", "Artifacts", 
	"Locations"
}


function EncyclopediaService:RecordDiscovery(player, discoveryId)
	print(player, discoveryId)
	local events = EncyclopediaService.Events
	local profile = PlayerDataManager:GetProfileData(player)

	if not profile then
		warn(`Failed to get profile for player {player.Name}`)
		return false
	end

	for _, discovery in profile.Discoveries do
		if discovery._id == discoveryId then
			return false -- Already discovered
		end
	end

	table.insert(profile.Discoveries, {
		_id = discoveryId,
		Timestamp = os.time()
	})
	events.OnDiscovery:Fire(player, discoveryId)

	return true
end

function EncyclopediaService:GetDiscoveries(player)
	local profile = PlayerDataManager:GetProfileData(player)

	if not profile then
		warn(`Failed to get profile for player {player.Name}`)
		return false
	end
	
	return profile.Discoveries
end



function EncyclopediaService:Setup()
	local events = EncyclopediaService.Events
	PlayerDataManager = Mince:Get("PlayerDataManager")
	
	events.RecordDiscovery.Event:Connect(function(player, id)
		EncyclopediaService:RecordDiscovery(player, id)
	end)
	
	events.GetDiscoveries:OnInvoke(function(player)
		return EncyclopediaService:GetDiscoveries(player)
	end)
end

--[[
return EncyclopediaService
]]

return {}