local SharedTableRegistry = game:GetService("SharedTableRegistry")
local Actor = script:GetActor()

local SourceModuleValue = Actor:WaitForChild("SourceModule")
local ResponseBindableValue = Actor:WaitForChild("ResponseBindable")
local SharedIdValue = Actor:FindFirstChild("SharedTableId") 

local SourceModule = SourceModuleValue.Value
local ResponseBindable = ResponseBindableValue.Value

local LoadedModule = require(SourceModule)

if SharedIdValue then
	LoadedModule.Shared = SharedTableRegistry:GetSharedTable(SharedIdValue.Value)
end

Actor:BindToMessageParallel("Task", function(RequestId, MethodName, ...)
	local Success, Result

	if type(LoadedModule[MethodName]) ~= "function" then
		Success = false
		Result = "Method '" .. tostring(MethodName) .. "' not found in Worker Module."
	else
		local Args = {...}
		
		Success, Result = pcall(function()
			return LoadedModule[MethodName](LoadedModule, unpack(Args))
		end)
	end

	task.synchronize()

	ResponseBindable:Fire(Actor, RequestId, Success, Result)
end)

ResponseBindable:Fire(Actor, "WorkerReady")