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


local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)
local Http = require(script.Parent.Http)

-- ========== Types ========== --

local HttpTypes = require(script.Parent.Parent.Types.Http)
type RequestOptions = HttpTypes.RequestOptions
type Response = HttpTypes.Response

type QueueEntry = {
	id: string,
	options: RequestOptions,
	priority: number,
	createdAt: number,
	dedupKey: string?,
	callbacks: { (Response) -> () },
}

-- ========== Constants ========== --

local DEFAULT_CONCURRENCY = 3

-- ========== State ========== --

local entries: { QueueEntry } = {}
local processing = 0
local maxConcurrency = DEFAULT_CONCURRENCY
local running = false
local idCounter = 0

-- ========== Helpers ========== --

local function generateId(): string
	idCounter += 1
	return `q_{idCounter}_{os.clock()}`
end

local function sortByPriority()
	table.sort(entries, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.createdAt < b.createdAt
	end)
end

local function findByDedupKey(key: string): QueueEntry?
	for _, entry in entries do
		if entry.dedupKey == key then
			return entry
		end
	end
	return nil
end

local function processNext()
	if #entries == 0 or processing >= maxConcurrency then
		return
	end

	local entry = table.remove(entries, 1)
	if not entry then return end

	processing += 1

	task.spawn(function()
		local response = Http.Request(entry.options)

		for _, callback in entry.callbacks do
			task.spawn(callback, response)
		end

		processing -= 1
		processNext()
	end)

	-- Try to fill remaining concurrency slots
	if processing < maxConcurrency and #entries > 0 then
		processNext()
	end
end

-- ========== Module ========== --

local module = {}

module.Processed = Signal.new()

function module.SetConcurrency(concurrency: number)
	maxConcurrency = math.clamp(concurrency, 1, 10)
end

function module.Enqueue(options: RequestOptions, callback: ((Response) -> ())?, dedupKey: string?): string
	local priority = options.priority or 5

	-- Deduplication: if a request with the same dedupKey is already queued, collapse
	if dedupKey then
		local existing = findByDedupKey(dedupKey)
		if existing then
			if callback then
				table.insert(existing.callbacks, callback)
			end
			-- Update to higher priority if the new request is more urgent
			if priority < existing.priority then
				existing.priority = priority
				sortByPriority()
			end
			return existing.id
		end
	end

	local id = generateId()
	local callbacks: { (Response) -> () } = {}
	if callback then
		table.insert(callbacks, callback)
	end

	table.insert(entries, {
		id = id,
		options = options,
		priority = priority,
		createdAt = os.clock(),
		dedupKey = dedupKey,
		callbacks = callbacks,
	})

	sortByPriority()

	if running then
		processNext()
	end

	return id
end

function module.Cancel(id: string): boolean
	for i, entry in entries do
		if entry.id == id then
			table.remove(entries, i)
			return true
		end
	end
	return false
end

function module.Clear()
	table.clear(entries)
end

function module.GetPendingCount(): number
	return #entries
end

function module.GetActiveCount(): number
	return processing
end

function module.Start()
	if running then return end
	running = true
	processNext()
end

function module.Stop()
	running = false
end

return table.freeze(module)
