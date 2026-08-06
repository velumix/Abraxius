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

type Entry = {
	value: any,
	expiresAt: number,
	setAt: number,
}

type PrivateFields<self> = {
	_store: { [string]: Entry },
	_defaultTtl: number,
}

type PublicMethods<self> = {
	Get: (self, key: string) -> any?,
	Set: (self, key: string, value: any, ttl: number?) -> (),
	Has: (self, key: string) -> boolean,
	IsStale: (self, key: string) -> boolean,
	Delete: (self, key: string) -> (),
	Clear: (self) -> (),
	GetAge: (self, key: string) -> number?,
	GetAll: (self) -> { [string]: any },
	Prune: (self) -> number,
	Size: (self) -> number,
}

type PrivateType = PublicMethods<PrivateType> & PrivateFields<PrivateType>
type PublicType = PublicMethods<PrivateType>

export type Type = PublicType

-- ========== Prototype ========== --

local prototype = {} :: PublicMethods<PrivateType>

function prototype:Get(key: string): any?
	local entry = self._store[key]
	if not entry then return nil end
	if os.clock() >= entry.expiresAt then
		self._store[key] = nil
		return nil
	end
	return entry.value
end

function prototype:Set(key: string, value: any, ttl: number?)
	local effectiveTtl = ttl or self._defaultTtl
	self._store[key] = {
		value = value,
		expiresAt = os.clock() + effectiveTtl,
		setAt = os.clock(),
	}
end

function prototype:Has(key: string): boolean
	return self:Get(key) ~= nil
end

function prototype:IsStale(key: string): boolean
	local entry = self._store[key]
	if not entry then return true end
	return os.clock() >= entry.expiresAt
end

function prototype:Delete(key: string)
	self._store[key] = nil
end

function prototype:Clear()
	table.clear(self._store)
end

function prototype:GetAge(key: string): number?
	local entry = self._store[key]
	if not entry then return nil end
	return os.clock() - entry.setAt
end

function prototype:GetAll(): { [string]: any }
	local result: { [string]: any } = {}
	local now = os.clock()
	for key, entry in self._store do
		if now < entry.expiresAt then
			result[key] = entry.value
		end
	end
	return result
end

function prototype:Prune(): number
	local pruned = 0
	local now = os.clock()
	for key, entry in self._store do
		if now >= entry.expiresAt then
			self._store[key] = nil
			pruned += 1
		end
	end
	return pruned
end

function prototype:Size(): number
	local count = 0
	local now = os.clock()
	for _, entry in self._store do
		if now < entry.expiresAt then
			count += 1
		end
	end
	return count
end

-- ========== Module ========== --

local module = {}
local metatable = table.freeze({ __index = table.freeze(prototype) })

function module.new(defaultTtl: number?): PublicType
	local self: PrivateFields<PrivateType> = {
		_store = {},
		_defaultTtl = defaultTtl or 60,
	}
	return setmetatable(self :: any, metatable) :: any
end

return table.freeze(module)
