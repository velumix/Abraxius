-- Folders // Locatison -- 
local MinceFolder = script.Parent.Parent 
local RemoteFolder = script 
local AllowServerInvoke = true

-- Inhertied Modules -- 
local Signal = require(MinceFolder.Signal)
local RefMutate = require(MinceFolder.RefMutate)

local IsAPlayer = function(Player) return typeof(Player) == "Instance" and Player:IsA("Player") end 

local RemoteExistance = {} 

local ServerRemote = {} 
ServerRemote.__index = ServerRemote

function ServerRemote:GetFunction(value : any)
	local MutatedIndex = RefMutate.Convert(value) 	
	if RemoteExistance[MutatedIndex] then 
		return RemoteExistance[MutatedIndex]
	end

	RemoteExistance[MutatedIndex] = ServerRemote.newFunction(MutatedIndex) 

	return RemoteExistance[MutatedIndex]
end

function ServerRemote.newFunction(index : string, ...)
	local ThisRemote = setmetatable({}, ServerRemote)
	ThisRemote:__Create(index, ...)
	return ThisRemote
end

function ServerRemote:__Create(RegisterIndex)
	self.Function = Signal.new()
	self.Middleware = {}
	
	self.RegisterIndex = RegisterIndex
	self.RemoteFunction = Instance.new("RemoteFunction", RemoteFolder) :: RemoteFunction
	self.RemoteFunction.Name = RegisterIndex
	
	self.RemoteFunction.OnServerInvoke = function(...)
		return self:UponInvoke(...)
	end
end

function ServerRemote:UponInvoke(...)
	for Index, Middleware in ipairs(self.Middleware) do 
		local Success , Reason = Middleware(...) 
		if Success == nil  then Success = true end
		if not Success then 
			warn(`Middleware failed while running on function! \n{Reason}`)
			return 
		end
	end
	
	return self.OnInvoke(...)
end

function ServerRemote:Invoke(Player, ...)
	if not IsAPlayer(Player) then 
		error("ServerRemote.Invoke([1]) : Expected Player got "..typeof(Player))	
	end
	
	if AllowServerInvoke then 
		return self.RemoteFunction:InvokeClient(Player,...)	
	else 
		error("You cannot invoke the client as it is disabled!")
	end
end

function ServerRemote:OnInvoke()
	warn("Default function invocation recieved")
	
	return nil
end

function ServerRemote:Add(Middleware)
	if type(Middleware) ~= "function" then 
		error("ServerRemote:Add([1]) : Expected Middleware function got "..typeof(Middleware))	
	end
	
	table.insert(self.Middleware, Middleware)
end


local ClientRemote = {} 
ClientRemote.__index = ClientRemote 

function ClientRemote:GetFunction(value : any)
	local MutatedIndex = RefMutate.Convert(value) 	
	if RemoteExistance[MutatedIndex] then 
		return RemoteExistance[MutatedIndex]
	end

	RemoteExistance[MutatedIndex] = ClientRemote.newFunction(MutatedIndex) 

	return RemoteExistance[MutatedIndex]
end

function ClientRemote.newFunction(index : string, ...)
	local ThisRemote = setmetatable({}, ClientRemote)
	ThisRemote:__Create(index, ...)
	return ThisRemote
end

function ClientRemote:__Create(RegisterIndex)
	self.Function = Signal.new()
	self.Middleware = {}

	self.RegisterIndex = RegisterIndex
	self.RemoteFunction = RemoteFolder:FindFirstChild(RegisterIndex) :: RemoteEvent 
	if not self.RemoteFunction then 
		error(`There's no server functionm by the name of "{RegisterIndex}".`)
	end

	self.RemoteFunction.OnClientInvoke = function(...)
		return self:UponInvoke(...)
	end
end

function ClientRemote:UponInvoke(...)
	for Index, Middleware in ipairs(self.Middleware) do 
		local Success , Reason = Middleware(...) 
		if Success == nil  then Success = true end
		if not Success then 
			warn(`Middleware[{Index}]'{self.RegisterIndex}': Rejection {Reason}!`)
			return 
		end
	end

	return self.OnInvoke(...)
end

function ClientRemote:Invoke(...)
	return self.RemoteFunction:InvokeServer(...)	
end

function ClientRemote:OnInvoke()
	warn("Default function invocation recieved. Are you sure you didn't mean to call Invoke()?")
end

function ClientRemote:Add(Middleware)
	if type(Middleware) ~= "function" then 
		error("ServerRemote:Add([1]) : Expected Middleware function got "..typeof(Middleware))	
	end

	table.insert(self.Middleware, Middleware)
end



return {
	Client = {GetFunction = ClientRemote.GetFunction}, 
	Server = {GetFunction = ServerRemote.GetFunction} 
} 