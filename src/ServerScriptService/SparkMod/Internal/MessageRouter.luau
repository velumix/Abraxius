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
--!strict


local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local MessageCodec = require(script.Parent.MessageCodec)
local Session = require(script.Parent.Session)
local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)

-- ========== Constants ========== --

local SHARED_TOPICS = {
	"coord:event",
	"coord:stock",
	"coord:action",
	"coord:shop",
	"coord:cmd",
	"coord:polls",
	"coord:test",
}

local SERVER_TOPIC_PREFIX = "coord:srv:"

-- ========== Types ========== --

type HandlerCallback = (action: string, data: { [string]: any }) -> ()

-- ========== State ========== --

local RECONNECT_DELAY = 2

local subscribed = false
local reconnectScheduled = false
local stopped = false

local handlers: { [string]: { HandlerCallback } } = {}
local wsClient: any = nil
local hasConnected = false

-- ========== Module ========== --

local module = {}

module.MessageReceived = Signal.new()
module.Reconnected = Signal.new()

function module.Register(messageType: string, handler: HandlerCallback)
	if not handlers[messageType] then
		handlers[messageType] = {}
	end
	table.insert(handlers[messageType], handler)
end

function module.Unregister(messageType: string, handler: HandlerCallback)
	local list = handlers[messageType]
	if not list then return end
	local index = table.find(list, handler)
	if index then
		table.remove(list, index)
	end
end

function module.UnregisterAll(messageType: string?)
	if messageType then
		handlers[messageType] = nil
	else
		table.clear(handlers)
	end
end

local function dispatchDecoded(decoded: MessageCodec.DecodedMessage)
	module.MessageReceived:Fire(decoded)

	local typeHandlers = handlers[decoded.messageType]
	if not typeHandlers then return end

	for _, handler in typeHandlers do
		task.spawn(handler, decoded.action, decoded.data)
	end
end

local function onMessagingServiceMessage(rawMessage: any)
	local data = rawMessage.Data
	if typeof(data) ~= "string" then return end

	local decoded = MessageCodec.Decode(data)
	if not decoded then return end

	dispatchDecoded(decoded)
end

local function onWebSocketMessage(raw: string)
	local parseOk, envelope = pcall(HttpService.JSONDecode, HttpService, raw)
	if not parseOk or typeof(envelope) ~= "table" then return end

	local topic = envelope.topic
	if typeof(topic) == "string" and topic:sub(1, #SERVER_TOPIC_PREFIX) == SERVER_TOPIC_PREFIX then
		if topic:sub(#SERVER_TOPIC_PREFIX + 1) ~= Session.Get() then return end
	end

	local messageData = envelope.data
	if typeof(messageData) ~= "string" then return end

	local decoded = MessageCodec.Decode(messageData)
	if not decoded then return end

	dispatchDecoded(decoded)
end

-- ========== Subscribe ========== --

local function subscribeViaMessagingService(sessionJobId: string?)
	for _, topic in SHARED_TOPICS do
		local success, err = pcall(function()
			MessagingService:SubscribeAsync(topic, onMessagingServiceMessage)
		end)
		if not success then
			warn(`[SparkMod.MessageRouter] Failed to subscribe to {topic}: {err}`)
		end
	end

	if sessionJobId and sessionJobId ~= "" then
		local serverTopic = SERVER_TOPIC_PREFIX .. sessionJobId
		local success, err = pcall(function()
			MessagingService:SubscribeAsync(serverTopic, onMessagingServiceMessage)
		end)
		if not success then
			warn(`[SparkMod.MessageRouter] Failed to subscribe to server topic: {err}`)
		end
	end
end

local subscribeViaWebSocket: (apiKey: string) -> ()

local function scheduleReconnect(apiKey: string)
	if stopped then return end
	if reconnectScheduled then return end
	reconnectScheduled = true
	task.delay(RECONNECT_DELAY, function()
		reconnectScheduled = false
		wsClient = nil
		if stopped then return end
		subscribeViaWebSocket(apiKey)
	end)
end

function subscribeViaWebSocket(apiKey: string)
	if stopped then return end
	local baseUrl = Session.GetBaseUrl()
	local wsUrl = baseUrl:gsub("^https://", "wss://"):gsub("^http://", "ws://")
	wsUrl = wsUrl .. "/game/ws?key=" .. apiKey

	local ok, client = pcall(function()
		return HttpService:CreateWebStreamClient(
			Enum.WebStreamClientType.WebSocket,
			{ Url = wsUrl }
		)
	end)

	if not ok or not client then
		warn("[SparkMod.MessageRouter] WebSocket connection failed, falling back to MessagingService")
		subscribeViaMessagingService()
		return
	end

	wsClient = client
	if hasConnected then
		module.Reconnected:Fire()
	end
	hasConnected = true
	client.MessageReceived:Connect(onWebSocketMessage)
	client.Closed:Connect(function()
		scheduleReconnect(apiKey)
	end)
	client.Error:Connect(function()
		scheduleReconnect(apiKey)
	end)
end

function module.Subscribe(apiKey: string, sessionJobId: string?)
	if subscribed then return end
	subscribed = true

	if RunService:IsStudio() then
		subscribeViaWebSocket(apiKey)
	else
		subscribeViaMessagingService(sessionJobId)
	end
end

function module.GetTopics(): { string }
	return table.clone(SHARED_TOPICS)
end

function module.Stop()
	if stopped then return end
	stopped = true
	local client = wsClient
	wsClient = nil
	if client then
		pcall(function()
			client:Close()
		end)
	end
end

return table.freeze(module)
