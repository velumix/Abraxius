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
local Remotes = require(script.Parent.Internal.Remotes)
local StockTypes = require(script.Parent.Types.Stock)
local Signal = require(script.Parent.Internal.Signal)

-- ========== State ========== --

local stockItems: { [string]: StockTypes.StockItemState } = {}
local poolStates: { [string]: StockTypes.PoolState } = {}
local initialized = false
local synced = false

-- ========== Module ========== --

local Stock = {}

Stock.Updated = Signal.new()
Stock.Depleted = Signal.new()
Stock.Rotated = Signal.new()
Stock.Ready = Signal.new()

-- ========== Queries ========== --

function Stock:GetItem(eventId: string): StockTypes.StockItemState?
	return stockItems[eventId]
end

function Stock:GetAllItems(): { [string]: StockTypes.StockItemState }
	return stockItems
end

function Stock:IsAvailable(eventId: string): boolean
	local item = stockItems[eventId]
	return item ~= nil and not item.depleted
end

function Stock:GetPool(poolId: string): StockTypes.PoolState?
	return poolStates[poolId]
end

function Stock:GetAllPools(): { [string]: StockTypes.PoolState }
	return poolStates
end

-- ========== Async Queries ========== --

function Stock:GetItemAsync(eventId: string): StockTypes.StockItemState?
	if not synced then Stock.Ready:Wait() end
	return Stock:GetItem(eventId)
end

function Stock:GetAllItemsAsync(): { [string]: StockTypes.StockItemState }
	if not synced then Stock.Ready:Wait() end
	return Stock:GetAllItems()
end

function Stock:IsAvailableAsync(eventId: string): boolean
	if not synced then Stock.Ready:Wait() end
	return Stock:IsAvailable(eventId)
end

function Stock:GetPoolAsync(poolId: string): StockTypes.PoolState?
	if not synced then Stock.Ready:Wait() end
	return Stock:GetPool(poolId)
end

function Stock:GetAllPoolsAsync(): { [string]: StockTypes.PoolState }
	if not synced then Stock.Ready:Wait() end
	return Stock:GetAllPools()
end

-- ========== Initialization ========== --

function Stock:Init()
	if initialized then return end
	initialized = true

	Remotes:Init()

	if RunService:IsServer() then
		return
	end

	-- Client: listen for server pushes
	Remotes:OnClient("SparkMod.Stock.Updated", function(eventId: string, data: StockTypes.StockItemState)
		stockItems[eventId] = data
		Stock.Updated:Fire(eventId, data)
	end)

	Remotes:OnClient("SparkMod.Stock.Removed", function(eventId: string)
		stockItems[eventId] = nil
		Stock.Updated:Fire(eventId, nil)
	end)

	Remotes:OnClient("SparkMod.Stock.Depleted", function(eventId: string)
		local item = stockItems[eventId]
		if item then
			item.depleted = true
		end
		Stock.Depleted:Fire(eventId)
	end)

	Remotes:OnClient("SparkMod.Stock.Rotated", function(poolId: string, poolState: StockTypes.PoolState)
		poolStates[poolId] = poolState
		Stock.Rotated:Fire(poolId, poolState)
	end)

	Remotes:OnClient("SparkMod.Stock.Sync", function(data: { items: { [string]: StockTypes.StockItemState }, pools: { [string]: StockTypes.PoolState } })
		stockItems = data.items or {}
		poolStates = data.pools or {}
		if not synced then synced = true; Stock.Ready:Fire() end
	end)

	-- Request initial state. Retry transient failures so Ready ALWAYS eventually fires:
	-- a throwing/failed GetState used to strand synced=false -> Ready never fires -> consumers hang.
	task.spawn(function()
		for attempt = 1, 4 do
			if synced then return end -- a "Sync" push already beat us to it
			local ok, result = pcall(function()
				return Remotes:InvokeServer("SparkMod.Stock.GetState")
			end)
			if ok and typeof(result) == "table" then
				stockItems = result.items or {}
				poolStates = result.pools or {}
				break
			end
			if attempt < 4 then task.wait(attempt) end -- 1s, 2s, 3s backoff
		end
		if not synced then synced = true; Stock.Ready:Fire() end
	end)
end

return Stock
