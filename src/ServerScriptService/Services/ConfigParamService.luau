local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal) :: any

local OVERRIDE_TOPIC = "ConfigParamOverride"

local REGISTRY: { [string]: { Default: any, Flag: boolean? } } = {
	sparkmod_events_fallback = { Default = false, Flag = true },
}

local ConfigParamService = Knit.CreateService({
	Name = "ConfigParamService",
	Client = {
		ParamChanged = Knit.CreateSignal(),
	},
})

local cache: { [string]: any } = {}
local signals: { [string]: any } = {}
local playerSubs: { [Player]: { [string]: true } } = {}

for key in REGISTRY do
	signals[key] = Signal.new()
end

local function pushToSubscribers(key: string, value: any)
	for player, subs in playerSubs do
		if subs[key] then
			ConfigParamService.Client.ParamChanged:Fire(player, key, value)
		end
	end
end

-- ========== Server API ========== --

function ConfigParamService:Get(key: string): any
	local entry = REGISTRY[key]
	if entry == nil then return nil end
	local cached = cache[key]
	if cached ~= nil then return cached end
	return entry.Default
end

function ConfigParamService:GetFlagKeys(): { string }
	local keys = {}
	for key, entry in REGISTRY do
		if entry.Flag then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function ConfigParamService:Subscribe(key: string, callback: (any) -> ())
	local signal = signals[key]
	if signal == nil then
		return { Disconnect = function() end, Connected = false }
	end
	return signal:Connect(callback)
end

function ConfigParamService:Set(key: string, value: any): boolean
	if REGISTRY[key] == nil then return false end
	cache[key] = value
	if signals[key] then signals[key]:Fire(value) end
	pushToSubscribers(key, value)
	return true
end

function ConfigParamService:Broadcast(key: string, value: any): boolean
	if not self:Set(key, value) then return false end
	print(`[ConfigParamService] broadcasting '{key}' = {value}`)
	pcall(function()
		MessagingService:PublishAsync(OVERRIDE_TOPIC, { key = key, value = value })
	end)
	return true
end

-- ========== Client API ========== --

function ConfigParamService.Client:GetParam(_player: Player, key: string): any
	return ConfigParamService:Get(key)
end

function ConfigParamService.Client:GetFlagKeys(_player: Player): { string }
	return ConfigParamService:GetFlagKeys()
end

function ConfigParamService.Client:SubscribeParam(player: Player, key: string): any
	if REGISTRY[key] == nil then return nil end
	local subs = playerSubs[player]
	if subs == nil then
		subs = {}
		playerSubs[player] = subs
	end
	subs[key] = true
	return ConfigParamService:Get(key)
end

-- ========== Lifecycle ========== --

function ConfigParamService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		playerSubs[player] = nil
	end)

	pcall(function()
		MessagingService:SubscribeAsync(OVERRIDE_TOPIC, function(message)
			local data = message.Data
			if type(data) == "table" and data.key ~= nil then
				print(`[ConfigParamService] received override '{data.key}' = {data.value}`)
				ConfigParamService:Set(data.key, data.value)
			end
		end)
	end)

	-- pcall guards GetService: degrade to defaults
	local ok, snapshot = pcall(function()
		return game:GetService("ConfigService"):GetConfigAsync()
	end)

	if not ok or snapshot == nil then
		print("[ConfigParamService] GetConfigAsync failed, defaults-only mode:", snapshot)
		for key, entry in REGISTRY do
			cache[key] = entry.Default
		end
		return
	end

	for key, entry in REGISTRY do
		local value = snapshot:GetValue(key)
		if value == nil then value = entry.Default end
		cache[key] = value

		snapshot:GetValueChangedSignal(key):Connect(function(newValue)
			if newValue == nil then newValue = entry.Default end
			cache[key] = newValue
			signals[key]:Fire(newValue)
			pushToSubscribers(key, newValue)
		end)
	end

	snapshot.UpdateAvailable:Connect(function()
		snapshot:Refresh()
	end)
end

return ConfigParamService
