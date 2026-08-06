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

-- ========== Types ========== --

type SignalCallback = (...any) -> ()

type ConnectionData = {
	callback: SignalCallback,
	connected: boolean,
}

type PrivateFields<self> = {
	_listeners: { ConnectionData },
}

type PrivateMethods<self> = {}

type PublicFields<self> = {}

type PublicMethods<self> = {
	Connect: (self, callback: SignalCallback) -> Connection,
	Fire: (self, ...any) -> (),
	FireAsync: (self, ...any) -> (),
	Once: (self, callback: SignalCallback) -> Connection,
	Wait: (self) -> ...any,
	DisconnectAll: (self) -> (),
	Destroy: (self) -> (),
}

type PrivateType = PublicFields<PrivateType> & PublicMethods<PrivateType>
	& PrivateFields<PrivateType> & PrivateMethods<PrivateType>
type PublicType = PublicFields<PublicType> & PublicMethods<PublicType>

export type Type = PublicType

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

-- ========== Prototype ========== --

local prototype = {} :: (PublicMethods<PrivateType> & PrivateMethods<PrivateType>)

function prototype:Connect(callback: SignalCallback): Connection
	local data: ConnectionData = {
		callback = callback,
		connected = true,
	}
	table.insert(self._listeners, data)

	local connection = {
		Connected = true,
		Disconnect = function(conn: Connection)
			if not data.connected then return end
			data.connected = false
			conn.Connected = false
			local index = table.find(self._listeners, data)
			if index then
				table.remove(self._listeners, index)
			end
		end,
	}

	return connection
end

function prototype:Fire(...: any)
	-- Iterate a snapshot: a listener that disconnects itself during dispatch (Wait/Once both do)
	-- mutates _listeners mid-iteration, which shifts and SKIPS later listeners on a live array.
	for _, listener in table.clone(self._listeners) do
		if listener.connected then
			listener.callback(...)
		end
	end
end

function prototype:FireAsync(...: any)
	for _, listener in table.clone(self._listeners) do
		if listener.connected then
			task.spawn(listener.callback, ...)
		end
	end
end

function prototype:Once(callback: SignalCallback): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function prototype:Wait(): ...any
	local thread = coroutine.running()
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function prototype:DisconnectAll()
	for _, listener in self._listeners do
		listener.connected = false
	end
	table.clear(self._listeners)
end

function prototype:Destroy()
	self:DisconnectAll()
end

-- ========== Module ========== --

local module = {}
local metatable = table.freeze({ __index = table.freeze(prototype) })

function module.new(): PublicType
	local self: PublicFields<PrivateType> & PrivateFields<PrivateType> = {
		_listeners = {},
	}
	return setmetatable(self :: any, metatable) :: any
end

function module.IsA(v: any): boolean
	return typeof(v) == "table" and getmetatable(v :: any) == metatable
end

return table.freeze(module)
