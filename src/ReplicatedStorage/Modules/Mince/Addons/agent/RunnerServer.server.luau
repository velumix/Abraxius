local RunService = game:GetService("RunService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local Actor = script:GetActor()

local ResponseEvent = Actor:WaitForChild("Response")
local SourceModule = Actor:WaitForChild("SourceModule").Value

local LoadSuccess, AgentDef = pcall(require, SourceModule)

if not LoadSuccess then
	task.wait()
	ResponseEvent:Fire("AgentStarted", false, "Failed to require Source Module: " .. tostring(AgentDef))
	return
end

local SharedTableId = Actor:FindFirstChild("SharedTableId")
if SharedTableId then
	AgentDef.Shared = SharedTableRegistry:GetSharedTable(SharedTableId.Value)
end

local AgentInstance = setmetatable({
	Instances = {},
}, { __index = AgentDef })

local IsConstructed = false
local HeartbeatConn

Actor:BindToMessage("Construct", function(...)
	if IsConstructed then
		return
	end
	IsConstructed = true

	local Args = { ... }
	local Success, Err

	if AgentInstance.OnNew then
		Success, Err = pcall(function()
			AgentInstance:OnNew(unpack(Args))
		end)
	else
		Success = true
	end

	if Success then
		ResponseEvent:Fire("AgentStarted", true)
	else
		ResponseEvent:Fire("AgentStarted", false, Err)
	end
end)

Actor:BindToMessage("UpdateInstance", function(Key, RefValue)
	if RefValue and RefValue:IsA("ObjectValue") then
		AgentInstance.Instances[Key] = RefValue.Value

		RefValue.Changed:Connect(function()
			AgentInstance.Instances[Key] = RefValue.Value
		end)
	else
		AgentInstance.Instances[Key] = nil
	end
end)

Actor:BindToMessage("Execute", function(RequestId, Method, ...)
	local Success, Result

	if type(AgentInstance[Method]) ~= "function" then
		Success = false
		Result = `Method '{Method}' not found on Agent.`
	else
		local Args = { ... }
		Success, Result = pcall(function()
			return table.pack(AgentInstance[Method](AgentInstance, unpack(Args)))
		end)
	end

	task.synchronize()

	ResponseEvent:Fire(RequestId, Success, Success and unpack(Result) or Result)
end)

ResponseEvent:Fire("ReadyToLoad")

Actor.Destroying:Connect(function()
	if AgentInstance.OnDestroy then
		pcall(AgentInstance.OnDestroy, AgentInstance)
	end
end)
