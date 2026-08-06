--!strict

--[[
	SparkMod — Centralized Coordinator for Roblox Game Servers

	Copyright 2026 Nicholas Rice

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
]]

local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local REMOTE_NAME = "_SparkModBridge"
local INVOKE_NAME = "_SparkModInvoke"

-- ========== State ========== --

local serverHandlers: { [string]: { (...any) -> () } } = {}
local clientHandlers: { [string]: { (...any) -> () } } = {}
local invokeHandlers: { [string]: (Player, ...any) -> ...any } = {}

local bridgeEvent: RemoteEvent? = nil
local invokeFunc: RemoteFunction? = nil
local initialized = false

-- ========== Internal ========== --

local function getBridge(): RemoteEvent
	if bridgeEvent then return bridgeEvent end

	if IS_SERVER then
		local existing = script:FindFirstChild(REMOTE_NAME)
		if existing and existing:IsA("RemoteEvent") then
			bridgeEvent = existing
		else
			local remote = Instance.new("RemoteEvent")
			remote.Name = REMOTE_NAME
			remote.Parent = script
			bridgeEvent = remote
		end
	else
		bridgeEvent = script:WaitForChild(REMOTE_NAME, 30) :: RemoteEvent
		if not bridgeEvent then
			warn("[SparkMod.Remotes] Failed to find bridge RemoteEvent")
		end
	end

	return bridgeEvent :: RemoteEvent
end

local function getInvoke(): RemoteFunction
	if invokeFunc then return invokeFunc end

	if IS_SERVER then
		local existing = script:FindFirstChild(INVOKE_NAME)
		if existing and existing:IsA("RemoteFunction") then
			invokeFunc = existing
		else
			local remote = Instance.new("RemoteFunction")
			remote.Name = INVOKE_NAME
			remote.Parent = script
			invokeFunc = remote
		end
	else
		invokeFunc = script:WaitForChild(INVOKE_NAME, 30) :: RemoteFunction
		if not invokeFunc then
			warn("[SparkMod.Remotes] Failed to find bridge RemoteFunction")
		end
	end

	return invokeFunc :: RemoteFunction
end

local function dispatch(handlers: { [string]: { (...any) -> () } }, channel: string, ...: any)
	local list = handlers[channel]
	if not list then return end
	for _, callback in list do
		task.spawn(callback, ...)
	end
end

-- ========== Module ========== --

local Remotes = {}

function Remotes:Init()
	if initialized then return end
	initialized = true

	local bridge = getBridge()
	local invoke = getInvoke()

	if IS_SERVER then
		bridge.OnServerEvent:Connect(function(player: Player, channel: string, ...: any)
			if typeof(channel) ~= "string" then return end
			dispatch(serverHandlers, channel, player, ...)
		end)

		invoke.OnServerInvoke = function(player: Player, channel: string, ...: any): ...any
			if typeof(channel) ~= "string" then return nil end
			local handler = invokeHandlers[channel]
			if handler then
				return handler(player, ...)
			end
			return nil
		end
	else
		bridge.OnClientEvent:Connect(function(channel: string, ...: any)
			if typeof(channel) ~= "string" then return end
			dispatch(clientHandlers, channel, ...)
		end)
	end
end

-- ========== Server API ========== --

function Remotes:FireClient(player: Player, channel: string, ...: any)
	getBridge():FireClient(player, channel, ...)
end

function Remotes:FireAllClients(channel: string, ...: any)
	getBridge():FireAllClients(channel, ...)
end

function Remotes:OnServer(channel: string, callback: (Player, ...any) -> ())
	if not serverHandlers[channel] then
		serverHandlers[channel] = {}
	end
	table.insert(serverHandlers[channel], callback)
end

function Remotes:OnInvoke(channel: string, callback: (Player, ...any) -> ...any)
	invokeHandlers[channel] = callback
end

-- ========== Client API ========== --

function Remotes:OnClient(channel: string, callback: (...any) -> ())
	if not clientHandlers[channel] then
		clientHandlers[channel] = {}
	end
	table.insert(clientHandlers[channel], callback)
end

function Remotes:FireServer(channel: string, ...: any)
	getBridge():FireServer(channel, ...)
end

function Remotes:InvokeServer(channel: string, ...: any): ...any
	return getInvoke():InvokeServer(channel, ...)
end

-- ========== Utilities ========== --

function Remotes:Disconnect(channel: string)
	serverHandlers[channel] = nil
	clientHandlers[channel] = nil
	invokeHandlers[channel] = nil
end

function Remotes:IsServer(): boolean
	return IS_SERVER
end

return Remotes
