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

-- ========== Dependencies ========== --

local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)
local Http = require(script.Parent.Parent.Internal.Http)
local Session = require(script.Parent.Parent.Internal.Session)
local MessageRouter = require(script.Parent.Parent.Internal.MessageRouter)
local ActionTypes = require(game.ReplicatedStorage.SparkMod.Types.Actions)

-- ========== State ========== --

local handlers: { [string]: ActionTypes.ActionHandler } = {}
local initialized = false

-- ========== Signals ========== --

local Actions = {}

Actions.Executed = Signal.new()
Actions.BroadcastSent = Signal.new()

-- ========== Registration ========== --

function Actions:Register(actionName: string, handler: ActionTypes.ActionHandler)
	if handlers[actionName] then
		warn(`[SparkMod.Actions] Overwriting handler for '{actionName}'`)
	end
	handlers[actionName] = handler
end

function Actions:Unregister(actionName: string)
	handlers[actionName] = nil
end

function Actions:IsRegistered(actionName: string): boolean
	return handlers[actionName] ~= nil
end

function Actions:GetRegisteredNames(): { string }
	local names = {}
	for name in handlers do
		table.insert(names, name)
	end
	return names
end

-- ========== Internal ========== --

function Actions._Execute(actionName: string, params: { [string]: any })
	local handler = handlers[actionName]
	if not handler then
		warn(`[SparkMod.Actions] No handler registered for '{actionName}'`)
		return
	end

	local ok, err = pcall(handler.execute, params)
	if not ok then
		warn(`[SparkMod.Actions] Execute error for '{actionName}': {err}`)
	end

	Actions.Executed:FireAsync(actionName, params)
end

-- ========== Public API ========== --

function Actions:Broadcast(actionName: string, params: { [string]: any }?): ActionTypes.BroadcastResult
	if not handlers[actionName] then
		return { ok = false, error = "Unknown action: " .. actionName }
	end

	local response = Http.Post("/game/actions/broadcast", {
		actionName = actionName,
		params = params or {},
		sourceJobId = Session.Get(),
	})

	if response.ok and response.body then
		Actions.BroadcastSent:FireAsync(actionName, response.body.broadcastId, false)
		return {
			ok = true,
			broadcastId = response.body.broadcastId,
		}
	end

	return { ok = false, error = response.error or "Broadcast failed" }
end

function Actions:BroadcastToServer(
	targetJobId: string,
	actionName: string,
	params: { [string]: any }?
): ActionTypes.BroadcastResult
	local response = Http.Post("/game/actions/target", {
		targetJobId = targetJobId,
		actionName = actionName,
		params = params or {},
		sourceJobId = Session.Get(),
	})

	if response.ok and response.body then
		Actions.BroadcastSent:FireAsync(actionName, response.body.broadcastId, false)
		return {
			ok = true,
			broadcastId = response.body.broadcastId,
		}
	end

	return { ok = false, error = response.error or "Targeted broadcast failed" }
end

function Actions:BroadcastLimited(actionName: string, params: { [string]: any }?, serverLimit: number): ActionTypes.BroadcastResult
	if not handlers[actionName] then
		return { ok = false, error = "Unknown action: " .. actionName }
	end

	local response = Http.Post("/game/actions/broadcast", {
		actionName = actionName,
		params = params or {},
		serverLimit = serverLimit,
		sourceJobId = Session.Get(),
	})

	if response.ok and response.body then
		Actions.BroadcastSent:FireAsync(actionName, response.body.broadcastId, true)
		return {
			ok = true,
			broadcastId = response.body.broadcastId,
			selectedServers = response.body.selectedServers,
		}
	end

	return { ok = false, error = response.error or "Broadcast failed" }
end

function Actions:ExecuteLocal(actionName: string, params: { [string]: any }?): (boolean, string?)
	local handler = handlers[actionName]
	if not handler then
		return false, "Unknown action: " .. actionName
	end

	local ok, err = pcall(handler.execute, params or {})
	if not ok then
		return false, err
	end

	Actions.Executed:FireAsync(actionName, params or {})
	return true, nil
end

-- ========== Message Handler ========== --

local function onActionMessage(action: string, data: { [string]: any })
	local actionName = data.actionName
	if not actionName then return end

	if action == "exec" then
		Actions._Execute(actionName, data.params or {})

	elseif action == "claim" then
		if not handlers[actionName] then return end
		if data.sourceJobId and data.sourceJobId == Session.Get() then return end

		local broadcastId = data.broadcastId
		if not broadcastId then return end

		task.spawn(function()
			task.wait(math.random() * 2)

			local ok, claimResponse = pcall(function()
				return Http.Post("/game/actions/claim", {
					broadcastId = broadcastId,
					jobId = Session.Get(),
				})
			end)

			if ok and claimResponse and claimResponse.ok and claimResponse.body and claimResponse.body.granted then
				Actions._Execute(actionName, data.params or {})
			end
		end)
	end
end

-- ========== Initialization ========== --

function Actions._Init()
	if initialized then return end
	initialized = true

	MessageRouter.Register("action", onActionMessage)
end

return Actions
