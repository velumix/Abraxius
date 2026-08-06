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


-- ========== Constants ========== --

local WINDOW_SECONDS = 60
local MAX_REQUESTS_PER_WINDOW = 500
local SAFETY_MARGIN = 50

-- ========== Types ========== --

export type Type = {
	_timestamps: { number },
	_reservedBudget: number,
	CanSend: (self: Type) -> boolean,
	Consume: (self: Type) -> boolean,
	Reserve: (self: Type, count: number) -> boolean,
	Release: (self: Type, count: number) -> (),
	GetRemaining: (self: Type) -> number,
	GetUsed: (self: Type) -> number,
	WaitForBudget: (self: Type) -> (),
}

-- ========== Helpers ========== --

local function pruneExpired(timestamps: { number })
	local cutoff = os.clock() - WINDOW_SECONDS
	while #timestamps > 0 and timestamps[1] < cutoff do
		table.remove(timestamps, 1)
	end
end

-- ========== Prototype ========== --

local prototype = {} :: Type

function prototype:CanSend(): boolean
	pruneExpired(self._timestamps)
	local effectiveLimit = MAX_REQUESTS_PER_WINDOW - SAFETY_MARGIN - self._reservedBudget
	return #self._timestamps < effectiveLimit
end

function prototype:Consume(): boolean
	if not self:CanSend() then
		return false
	end
	table.insert(self._timestamps, os.clock())
	return true
end

function prototype:Reserve(count: number): boolean
	pruneExpired(self._timestamps)
	local effectiveLimit = MAX_REQUESTS_PER_WINDOW - SAFETY_MARGIN
	local available = effectiveLimit - #self._timestamps - self._reservedBudget
	if count > available then
		return false
	end
	self._reservedBudget += count
	return true
end

function prototype:Release(count: number)
	self._reservedBudget = math.max(0, self._reservedBudget - count)
end

function prototype:GetRemaining(): number
	pruneExpired(self._timestamps)
	local effectiveLimit = MAX_REQUESTS_PER_WINDOW - SAFETY_MARGIN - self._reservedBudget
	return math.max(0, effectiveLimit - #self._timestamps)
end

function prototype:GetUsed(): number
	pruneExpired(self._timestamps)
	return #self._timestamps
end

function prototype:WaitForBudget()
	while not self:CanSend() do
		task.wait(1)
	end
end

-- ========== Module ========== --

local module = {}
local metatable = table.freeze({ __index = table.freeze(prototype) })

function module.new(): Type
	local self = {
		_timestamps = {},
		_reservedBudget = 0,
	}
	return setmetatable(self :: any, metatable) :: any
end

return table.freeze(module)
