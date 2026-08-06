-- Modules // Servvices 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Mince = require(ReplicatedStorage.Modules.Mince)
local Signal = require(ReplicatedStorage.Modules.Signal)

-- redoing on the component wriringt import from the weave one 

local DataSync = Mince:GetEvent("DataSync")
local DataPartialSync = Mince:GetEvent("DataPartialSync")

local UserProfile = {
	Listeners = {} 
}

function UserProfile:RequestUpdate(Index)
	UserProfile.RemoteEvent.Fire(Index)
end

function UserProfile.RecievePartialUpdate(ProfilePart )
	for Index,Data in ProfilePart do 
		if not Mince.Config.LocalProfile[Index] then 
			Mince.Config.LocalProfile[Index] = {} 
		end

		for SubIndex,Value in Data do 
			Mince.Config.LocalProfile[Index][SubIndex] = Value
		end
	end

	for Index,Data in ProfilePart do 
		local Listener = UserProfile.Listeners[Index] 
		if Listener and Listener.Index == Index then 
			Listener.Event:Fire(Mince.Config.LocalProfile[Index])
		end	
	end
end

function UserProfile.RecieveUpdate(ProfilePart) 
	if not Mince.Config.HasRecievedAnUpdate and RunService:IsStudio() then 
	end
	Mince.Config.HasRecievedAnUpdate = true 
	-- Firstly update the LocalProfile 
	for Index,Data in ProfilePart do 
		Mince.Config.LocalProfile[Index] = Data
	end

	-- Fire all related listeners.
	for Index,Data in ProfilePart do 
		local Listener = UserProfile.Listeners[Index] 
		if Listener and Listener.Index == Index then 
			Listener.Event:Fire(Data)
		end		
	end
end

function UserProfile:IndexUpdated(Index)
	local ExistingListner = UserProfile.Listeners[Index] 
	if ExistingListner then
		return ExistingListner.Event
	end
	local Event =  Signal.new() 
	UserProfile.Listeners[Index] = {
		Index = Index,
		Event = Event	
	}
	return Event	 
end

function UserProfile:Upon(Index, Callback)
	assert(typeof(Callback) == "function", "Callback must be a Function! (done to prevent (.,:) confusion)")
	if Mince.Config.HasRecievedAnUpdate and UserProfile.LocalProfile[Index] then 
		Callback(UserProfile.LocalProfile[Index])
	end
	UserProfile:IndexUpdated(Index):Connect(Callback)
end


function UserProfile:GetLocalProfile() 
	UserProfile:WaitUntilLoaded() 
	return UserProfile.LocalProfile
end

function UserProfile:WaitUntilLoaded() 
	repeat task.wait() until Mince.Config.HasRecievedAnUpdate
end

function UserProfile:IsLoaded()
	return Mince.Config.HasRecievedAnUpdate
end

function UserProfile.Init() 
	Mince.Config.LocalProfile = {}
	UserProfile.LocalProfile = Mince.Config.LocalProfile

	DataSync.Event:Connect(UserProfile.RecieveUpdate)
	DataPartialSync.Event:Connect(UserProfile.RecievePartialUpdate)
end

UserProfile.Init() 
return UserProfile 
