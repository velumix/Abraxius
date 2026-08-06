type ActorCommScript = BaseScript & {
    CommEvent : BindableEvent,
    CommFunction : BindableFunction
}

local function InitActorComm(script : ActorCommScript)
    local CommEvent : BindableEvent = script.CommEvent
    local CommFunction : BindableFunction = script.CommFunction

	local Actor = script:GetActor()
	
    local Module
    local SymbolsTable = {}

    local UIDGen = 0
    local function NewUID()
        UIDGen += 1
        return UIDGen
    end

    local function BuildSymbol(id)
        local Symbol = {}
        SymbolsTable[id] = Symbol
        return Symbol
    end

    local Commands; Commands = {
        LoadModule = function(targetModule)
            Module = require(targetModule)
            if typeof(Module) ~= "table" then
                assert(typeof(Module) == "function","Attempt to return function from ModuleScript loaded in parallel")
                return "NoInterface",Module
            end
		
			Module.Actor = Actor 

            return "Interface"
        end,
        SetIndex = function(index,value)
            local UnserializedIndex = index
            if typeof(index) == "table" and index._type == "symbol" then
                UnserializedIndex = SymbolsTable[index._id] or BuildSymbol(index._id)
            end

            Module[UnserializedIndex] = value
        end,
		GetIndex = function(index)
            local UnserializedIndex = index
            if typeof(index) == "table" and index._type == "symbol" then
                UnserializedIndex = SymbolsTable[index._id] or BuildSymbol(index._id)
            end
            local value = Module[UnserializedIndex]

            if typeof(value) == "function" then
                
                local functionPath = index
                if typeof(index) == "table" and index._type == "symbol" then
                    functionPath = {path = index._id,_type = "function"}
                end

                value = {
                    module = Module,
                    path = functionPath,
                    _type = "function"
                }
            end

            return value
        end,
        CallFunction = function(functionPath,...)
            if typeof(functionPath) == "table" and functionPath._type == "function" then
                functionPath = SymbolsTable[functionPath.path]
            end
            return Module[functionPath](...)
        end,
        CallMethod = function(functionPath,...)
            Commands.CallFunction(functionPath,Module,...)
        end
    }

    CommEvent:Fire("Initialized")

    CommEvent.Event:Connect(function(Command,...)
        Commands[Command](...)
    end)


    function CommFunction.OnInvoke(Command,...) : any
        return Commands[Command](...)
    end
end

return InitActorComm