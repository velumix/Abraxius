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

local DEFAULT_MAX_ATTEMPTS = 3
local DEFAULT_BASE_DELAY = 1
local DEFAULT_MAX_DELAY = 16
local DEFAULT_JITTER_RATIO = 0.5

-- ========== Types ========== --

export type RetryOptions = {
	maxAttempts: number?,
	baseDelay: number?,
	maxDelay: number?,
	jitterRatio: number?,
	shouldRetry: ((attempt: number, err: string) -> boolean)?,
}

-- ========== Module ========== --

local module = {}

function module.Execute<T>(operation: () -> T, options: RetryOptions?): (boolean, T?)
	local maxAttempts = (options and options.maxAttempts) or DEFAULT_MAX_ATTEMPTS
	local baseDelay = (options and options.baseDelay) or DEFAULT_BASE_DELAY
	local maxDelay = (options and options.maxDelay) or DEFAULT_MAX_DELAY
	local jitterRatio = (options and options.jitterRatio) or DEFAULT_JITTER_RATIO
	local shouldRetry = options and options.shouldRetry

	local delay = baseDelay
	local lastError = ""

	for attempt = 1, maxAttempts do
		local success, result = pcall(operation)

		if success then
			return true, result
		end

		lastError = tostring(result)

		if attempt == maxAttempts then
			break
		end

		if shouldRetry and not shouldRetry(attempt, lastError) then
			break
		end

		local jitter = math.random() * delay * jitterRatio
		task.wait(delay + jitter)
		delay = math.min(delay * 2, maxDelay)
	end

	warn(string.format("[SparkMod.Retry] Failed after %d attempts: %s", maxAttempts, lastError))
	return false, nil :: T?
end

function module.ExecuteAsync<T>(operation: () -> T, options: RetryOptions?): (boolean, T?)
	local result: { success: boolean, value: T? } = { success = false, value = nil }

	local thread = coroutine.running()

	task.spawn(function()
		local ok, val = module.Execute(operation, options)
		result.success = ok
		result.value = val
		task.spawn(thread)
	end)

	coroutine.yield()
	return result.success, result.value
end

return table.freeze(module)
