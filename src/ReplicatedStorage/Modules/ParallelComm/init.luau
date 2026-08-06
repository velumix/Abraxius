local Players = game:GetService("Players")
type ActorCommScript = BaseScript & {
    CommEvent : BindableEvent,
    CommFunction : BindableFunction
}

--[=[
	@type ParallelInterface {[any] : any} | any
	.[any] any
	@within ParallelComm
	This is the generic return interface type for any module loaded through ParallelComm. The exact value will depend on the value returned by the module loaded through the [LoadParallel](http://localhost:3000/ParallelComm/api/ParallelComm#LoadParallel) function.
]=]
type ParallelInterface = {
	[any] : any
}

--[=[
	@class ParallelComm
]=]
local ParallelComm = {}


local ParallelCommScript = script.ParallelComm

local ActorsFolder = script.ActorFolder

local AcceptableTypes = { "string", "number", "boolean", "Enum" }
local UIDGen = 0

local function NewUID()
	UIDGen += 1
	return UIDGen
end

--[=[
	@function LoadParallel
	@param Module ModuleScript
	@return ParallelInterface
	@within ParallelComm
	A function for creating a parallel actor which will load the provided [ModuleScript](https://create.roblox.com/docs/reference/engine/classes/ModuleScript) within said actor's execution environment. The return value of this function is generalized as a [ParallelInterface](http://localhost:3000/ParallelComm/api/ParallelComm#ParallelInterface),
	but the exact value depends on the return type of the loaded module.

	For modules which return a table, as is common practice with most Knit-based service/controller driven designs, the returned interface will act as an intermediate to call functions, edit properties, or read
	data from your module's returned table. You can, for all intents and purposes, treat this as the returned table from your module. There are no limitations to what objects can be used as indicies for the
	table, anything except ``nil`` is accepted (passing nil as an index will erorr). Values passed when setting the value of an index are subject to the limitations of arguments passed through [BindableEvents](https://create.roblox.com/docs/reference/engine/classes/BindableEvent).
	If the value passed when assigning a value is of type [Function](https://create.roblox.com/docs/scripting/luau/functions), your script will error. Functions cannot be passed through BindableEvents.

	As an example, lets say we have the following ModuleScript:
	```lua
	local MyModule = {
		Name = "Johnny"
	}

	function MyModule:PrintName()
		print(self.Name)
	end

	return MyModule
	```

	With our interface implementation, we can then crate a parallel actor and perform actions like calling functions and indexing values like so:
	```lua
	local ParallelComm = require(Packages.ParallelComm)
	local ParallelCommServer = ParallelComm.Server

	local Module = ReplicatedStorage.MyModule
	local ModuleInterface = ParallelCommServer.LoadParallel(Module)

	ModuleInterface:PrintName()
	ModuleInterface.PrintName{Name = "Howard"}

	ModuleInterface.Name = "Frank"

	print(ModuleInterface.Name)
	```

	For modules which return a value other than a table, but not a function, the value returned is also subject to the limitations of arguments passed through [BindableEvents](https://create.roblox.com/docs/reference/engine/classes/BindableEvent).

	This function will yield execution to allow time for the new Actor instance to finish its initialization.

	@error Attempt to return function from ModuleScript loaded in parallel -- Modules which attempt to return a function as a value will erorr, since functions cannot be passed between seperate execution environments.

	@yields
]=]
local function LoadParallel(ActorCommScript : ActorCommScript,Module : ModuleScript) : ParallelInterface
	local StarterPlayerScripts = Players.LocalPlayer.PlayerScripts
	local ClientActorsFolder = StarterPlayerScripts:FindFirstChild("ActorsFolder") or Instance.new("Folder")
	ClientActorsFolder.Name = "ActorsFolder"
	ClientActorsFolder.Parent = StarterPlayerScripts

	

	local SymbolsTable = {}
	
	local function BuildSymbol(value)
		local ID = NewUID()
		SymbolsTable[value] = ID
		return {_id = ID, _type = "symbol", value = value }
	end

	
	local ActorCommEvent = ActorCommScript.CommEvent

	local ActorCommFunction = ActorCommScript.CommFunction

	local Actor = Instance.new("Actor")

	local newParallelCommScript = ParallelCommScript:Clone()
	newParallelCommScript.Parent = Actor
	ActorCommScript.Parent = newParallelCommScript


	local Interface; Interface = setmetatable({},{
		__index = function(_,index : any)
			if index == nil then error("Attempt to index table with nil value", 3) end
				
			local SerializedIndex = index
			if not table.find(AcceptableTypes, typeof(index)) then SerializedIndex = SymbolsTable[index] or BuildSymbol(index) end

			local IndexValue = ActorCommFunction:Invoke("GetIndex",SerializedIndex)
			
			if typeof(IndexValue) == "table" and IndexValue._type == "function" then
				return function(Self,...)
					if Self == Interface then
						return ActorCommFunction:Invoke("CallMethod",IndexValue.path,...)
					else
						return ActorCommFunction:Invoke("CallFunction",IndexValue.path,Self,...)
					end
				end
			elseif typeof(IndexValue) == "table" and IndexValue._type == "symbol" then
				return IndexValue.value
			else
				return IndexValue
			end
		end,
		__newindex = function(_,index : any, value : any)
			if index == nil then error("Attempt to index table with nil value", 3) end
			if typeof(value) == "function" then error("Attempt to assign value of type function to an index of a Module loaded in parallel",3) end

			local SerializedIndex = index
			if not table.find(AcceptableTypes, typeof(index)) then SerializedIndex = SymbolsTable[index] or BuildSymbol(index) end
			if value == nil then SymbolsTable[index] = nil end
			
			--//TODO: Add function serialization using the below API:
			--[[
				if it's a module
				Actor.Start = Actor:SerializeFunction(module, "Run")
				
				{
					module = ModuleScript,
					path = "Start",
					_type = "function"
				}
			]]
			ActorCommEvent:Fire("SetIndex",SerializedIndex,value)
		end	
	})

	Actor.Parent = ClientActorsFolder
	ActorCommScript.Enabled = true

	--ActorCommEvent.Event:Wait() --// Utilizing this as an initializer yield, the ActorScript will fire this after it's finished loading
	local Response, ReturnValue = ActorCommFunction:Invoke("LoadModule", Module)

	if Response == "Interface" then
		return Interface :: ParallelInterface
	elseif Response == "NoInterface" then
		return ReturnValue
	end
end

local function LoadParallelClient(Module : ModuleScript) : ParallelInterface
	local ActorCommScript : ActorCommScript = script.ClientComm:Clone() :: ActorCommScript
	return LoadParallel(ActorCommScript,Module)
end

local function LoadParallelServer()
	
end


--[=[
	@interface Server
	.LoadParallel (ModuleScript : ModuleScript) -> ParallelInterface
	@within ParallelComm
	@tag Server-Only

	The available interface for ParallelComm on the server. Accessible like so:
	```lua
	local ParallelComm = require(Packages.ParallelComm)

	local Server = ParallelComm.Server
	```
]=]
ParallelComm.Server = {
	LoadParallel = LoadParallelServer
}
--[=[
	@interface Client
	.LoadParallel (ModuleScript : ModuleScript) -> ParallelInterface
	@within ParallelComm
	@tag Client-Only

	The available interface for ParallelComm on the client. Accessible like so:
	```lua
	local ParallelComm = require(Packages.ParallelComm)

	local Client = ParallelComm.Client
	```
]=]
ParallelComm.Client = {
	LoadParallel = LoadParallelClient
}

return ParallelComm