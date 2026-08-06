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

local Retry = require(script.Parent.Retry)
local RateBudget = require(script.Parent.RateBudget)
local Encryption = require(script.Parent.Encryption)
local Session = require(script.Parent.Session)
local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)

-- ========== Types ========== --

local HttpTypes = require(script.Parent.Parent.Types.Http)
type RequestOptions = HttpTypes.RequestOptions
type Response = HttpTypes.Response
type HttpMethod = HttpTypes.HttpMethod

-- ========== State ========== --

local budget = RateBudget.new()
local apiKey: string = ""
local requestTimeout: number = 10
local maxRetries: number = 3
local enableEncryption: boolean = true

local offboarded: boolean = false
local offboardedResponse: any = nil

-- ========== Helpers ========== --

local function buildUrl(path: string): string
	local base = Session.GetBaseUrl()
	if path:sub(1, 1) ~= "/" then
		path = "/" .. path
	end
	return base .. path
end

local function buildHeaders(method: string, path: string, bodyString: string?): { [string]: string }
	local headers: { [string]: string } = {
		["x-api-key"] = apiKey,
	}

	if bodyString and #bodyString > 0 then
		headers["Content-Type"] = "application/json"
	end

	if enableEncryption then
		local signed = Encryption.BuildSignedHeaders(apiKey, method, path, bodyString)
		for key, value in signed do
			headers[key] = value
		end
	end

	return headers
end

local function parseResponse(httpResponse: any): Response
	local statusCode = httpResponse.StatusCode or 0
	local ok = statusCode >= 200 and statusCode < 300

	local body: { [string]: any }? = nil
	if httpResponse.Body and #httpResponse.Body > 0 then
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, httpResponse.Body)
		if decodeOk and typeof(decoded) == "table" then
			body = decoded
		end
	end

	local responseHeaders: { [string]: string } = {}
	if httpResponse.Headers then
		for key, value in httpResponse.Headers do
			responseHeaders[key] = tostring(value)
		end
	end

	return {
		ok = ok,
		statusCode = statusCode,
		body = body,
		headers = responseHeaders,
		error = if not ok then (body and body.error) or `HTTP {statusCode}` else nil,
	}
end

local function shouldRetryStatus(statusCode: number): boolean
	return statusCode == 429 or statusCode >= 500
end

-- ========== Module ========== --

local module = {}

module.Offboarded = Signal.new()

function module.IsOffboarded(): boolean
	return offboarded
end

function module.Configure(config: {
	apiKey: string,
	requestTimeout: number?,
	maxRetries: number?,
	enableEncryption: boolean?,
})
	apiKey = config.apiKey
	requestTimeout = config.requestTimeout or 10
	maxRetries = config.maxRetries or 3
	enableEncryption = if config.enableEncryption ~= nil then config.enableEncryption else true
end

function module.Request(options: RequestOptions): Response
	if offboarded then
		return offboardedResponse :: Response
	end

	local method = options.method
	local path = options.path
	local url = buildUrl(path)

	local bodyString: string? = nil
	if options.body then
		bodyString = HttpService:JSONEncode(options.body)
	end

	-- Wait for rate budget
	budget:WaitForBudget()

	local response: Response = {
		ok = false,
		statusCode = 0,
		error = "Request not sent",
	}

	local success, _ = Retry.Execute(function(): nil
		if not budget:Consume() then
			error("[SparkMod.Http] Rate budget exhausted")
		end

		-- Regenerate headers on each attempt so nonce is fresh
		local headers = buildHeaders(method, path, bodyString)
		if options.headers then
			for key, value in options.headers do
				headers[key] = value
			end
		end

		local httpResponse = HttpService:RequestAsync({
			Url = url,
			Method = method,
			Headers = headers,
			Body = bodyString,
		})

		response = parseResponse(httpResponse)

		-- Handle 429 with Retry-After
		if response.statusCode == 429 then
			local retryAfter = tonumber(response.headers and response.headers["retry-after"]) or 5
			task.wait(retryAfter)
			error(`Rate limited (429), retry after {retryAfter}s`)
		end

		if not response.ok and shouldRetryStatus(response.statusCode) then
			error(`Server error ({response.statusCode})`)
		end

		return nil
	end, {
		maxAttempts = maxRetries,
		baseDelay = 1,
		maxDelay = 10,
		shouldRetry = function(attempt: number, _err: string): boolean
			return attempt < maxRetries
		end,
	} :: Retry.RetryOptions)

	if not success and response.statusCode == 0 then
		response.error = "Request failed after retries"
	end

	if not offboarded
		and response.statusCode == 410
		and response.body
		and response.body.code == "GAME_OFFBOARDED"
	then
		offboarded = true
		offboardedResponse = response
		module.Offboarded:Fire(response)
	end

	-- Feed the shard-fallback detector: a reachable, non-5xx response means the
	-- shard host is healthy; a network failure (status 0) or 5xx counts against it.
	Session.NoteShardOutcome(response.statusCode > 0 and response.statusCode < 500)

	return response
end

function module.Get(path: string): Response
	return module.Request({
		method = "GET",
		path = path,
	})
end

function module.Post(path: string, body: { [string]: any }?): Response
	return module.Request({
		method = "POST",
		path = path,
		body = body or {},
	})
end

function module.Patch(path: string, body: { [string]: any }): Response
	return module.Request({
		method = "PATCH",
		path = path,
		body = body,
	})
end

function module.Delete(path: string): Response
	return module.Request({
		method = "DELETE",
		path = path,
	})
end

function module.GetBudget(): typeof(budget)
	return budget
end

return table.freeze(module)
