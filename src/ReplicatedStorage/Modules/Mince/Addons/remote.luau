-- Folders // Locatison -- 
local MinceFolder = script.Parent.Parent 
local RemoteFolder = script 

-- Inhertied Modules -- 
local Signal = require(MinceFolder.Signal)
local RefMutate = require(MinceFolder.RefMutate)

local IsAPlayer = function(Player) return typeof(Player) == "Instance" and Player:IsA("Player") end 


local RemoteExistance = {} 

local ServerRemote = {} 
ServerRemote.__index = ServerRemote

function ServerRemote:GetEvent(value : any, ...)
	local MutatedIndex = RefMutate.Convert(value) 	
	if RemoteExistance[MutatedIndex] then 
		return RemoteExistance[MutatedIndex]
	end

	RemoteExistance[MutatedIndex] = ServerRemote.newEvent(MutatedIndex, ...) 

	return RemoteExistance[MutatedIndex]
end

function ServerRemote.newEvent(index : string, ...)
	local ThisRemote = setmetatable({}, ServerRemote)
	ThisRemote:__Create(index, ...)
	return ThisRemote
end

function ServerRemote:__Create(RegisterIndex, Unreliable : boolean)
	self.Event = Signal.new()
	self.Extenders = {}
	self.DoesExtend = false
	
	self.RegisterIndex = RegisterIndex
	self.RemoteEvent = Instance.new(Unreliable and "UnreliableRemoteEvent" or "RemoteEvent", RemoteFolder) :: RemoteEvent
	self.RemoteEvent.Name = RegisterIndex
	
	self.RemoteEvent.OnServerEvent:Connect(function(...)
		self:UponRemoteEvent(...)
	end)
end

function ServerRemote:UponRemoteEvent(...)
	if self.DoesExtend then 
		local Player , Name = ... 
		local RemoteExtender = self.Extenders[Name] 
		if RemoteExtender then 
			RemoteExtender.Event:Fire(Player, select(3,...))
			return 
		else 
			warn(`Dropped server extender '{Name}' ({self.RegisterIndex}) did you forget to extend this? Player has been kicked as a security measure.`)
			Player:Kick("Recieved communication to unconnected event extension. Please re-join or report to developer.")
		end
	end 
	
	self.Event:Fire(...)
end

function ServerRemote:Fire(Player : Player, ...) 
	assert(IsAPlayer(Player), ":Fire([1]) must be a player!")
	self.RemoteEvent:FireClient(Player, ...)
end

function ServerRemote:FireAll(...)
	self.RemoteEvent:FireAllClients(...)
end

function ServerRemote:Extend(Name : string) -- this does not work at all LOL!
	if self.Extenders[Name] then 
		return self.Extenders[Name] 
	end
	
	
	self.DoesExtend = true 
	self.RemoteEvent:SetAttribute("Extends", true)	
	
	-- This is a mini-factory! Because why would i crteate extender classes! -- Sad to see you've gone back to your old ways 😔
	local that = self 
	local RemoteExtender = {
		Event = Signal.new(),
	} 
	
	function RemoteExtender:Fire(Player : Player, ...) 
		assert(IsAPlayer(Player), ":Fire([1]) must be a player!")
		that.RemoteEvent:FireClient(Player, Name, ...) -- me when I pull self.RemoteEvent out of my buttocks
	end
	
	function RemoteExtender:FireAll(...) 
		that.RemoteEvent:FireAllClients(Name, ...)
	end
	
	
	self.Extenders[Name] = RemoteExtender 
	return RemoteExtender
end


local ClientRemote = {} 
ClientRemote.__index = ClientRemote 

function ClientRemote:GetEvent(value : any)
	local MutatedIndex = RefMutate.Convert(value) 	
	if RemoteExistance[MutatedIndex] then 
		return RemoteExistance[MutatedIndex]
	end
	
	RemoteExistance[MutatedIndex] = ClientRemote.newEvent(MutatedIndex) 
	
	return RemoteExistance[MutatedIndex]
end

function ClientRemote.newEvent(index : string, ...) 
	local ThisRemote = setmetatable({}, ClientRemote)
	ThisRemote:__Create(index, ...) 
	return ThisRemote
end

function ClientRemote:__Create(RegisterIndex, Unreliable : boolean)  
	self.Event = Signal.new() 
	self.Extenders = {}  

	self.RegisterIndex = RegisterIndex
	self.RemoteEvent = RemoteFolder:FindFirstChild(RegisterIndex) :: RemoteEvent 
	if not self.RemoteEvent then 
		error(`There's no server remote by the name of "{RegisterIndex}".`)
	end

	self.DoesExtend = self.RemoteEvent:GetAttribute("Extends")  
	self.RemoteEvent:GetAttributeChangedSignal("Extends"):Connect(function()
		self.DoesExtend = self.RemoteEvent:GetAttribute("Extends")  
	end)

	self.RemoteEvent.OnClientEvent:Connect(function(...)
		self:UponRemoteEvent(...)
	end)
end 

function ClientRemote:UponRemoteEvent(...)
	if self.DoesExtend then 
		local Name = ... 
		local RemoteExtender = self.Extenders[Name] 
		if RemoteExtender then 
			RemoteExtender.Event:Fire(select(2, ...))
			return 
		else 
			warn(`Dropped extender '{Name}' ({self.RegisterIndex}) did you forget to extend this? `)
		end
	end 
	
	self.Event:Fire(...)
end

function ClientRemote:Fire(...)  
	if self.DoesExtend then 
		error("You cannot fire an extended remote.")
	end
	
	self.RemoteEvent:FireServer(...)
end


function ClientRemote:Extend(Name : string)
	if not self.DoesExtend then 
		error("You cannot extend a remote that is not extended on the server!")
	end
	
	if self.Extenders[Name] then 
		return self.Extenders[Name] 
	end
	
	-- This is a mini-factory! Because why would i crteate extender classes! 
	local that = self 
	local RemoteExtender = {
		Event = Signal.new(),
	} 

	function RemoteExtender:Fire(...) 
		that.RemoteEvent:FireServer(Name, ...)
	end

	self.Extenders[Name] = RemoteExtender 
	return RemoteExtender
end


return {
	Client = {GetEvent = ClientRemote.GetEvent}, 
	Server = {GetEvent = ServerRemote.GetEvent} 
} 