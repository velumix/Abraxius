local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal) :: any

local ConfigParamController = Knit.CreateController({
	Name = "ConfigParamController",
})

local cache: { [string]: any } = {}
local signals: { [string]: any } = {}
local warming: { [string]: boolean } = {}

local configParamService
local function service()
	if not configParamService then
		configParamService = Knit.GetService("ConfigParamService")
	end
	return configParamService
end

function ConfigParamController:Get(key: string): any
	local cached = cache[key]
	if cached ~= nil then return cached end
	local value = service():GetParam(key)
	if value ~= nil then cache[key] = value end
	return value
end

function ConfigParamController:Subscribe(key: string, callback: (any) -> ())
	local signal = signals[key]
	if signal == nil then
		signal = Signal.new()
		signals[key] = signal
		local initial = service():SubscribeParam(key)
		if cache[key] == nil then cache[key] = initial end
	end

	local connection = signal:Connect(callback)
	task.spawn(callback, cache[key])
	return connection
end

-- non-yielding read
function ConfigParamController:Peek(key: string): any
	local cached = cache[key]
	if cached ~= nil then return cached end
	if not warming[key] then
		warming[key] = true
		task.spawn(function()
			local value = service():SubscribeParam(key)
			if cache[key] == nil then cache[key] = value end
		end)
	end
	return nil
end

function ConfigParamController:KnitStart()
	service().ParamChanged:Connect(function(key, value)
		cache[key] = value
		local signal = signals[key]
		if signal then
			signal:Fire(value)
		end
	end)
end

return ConfigParamController