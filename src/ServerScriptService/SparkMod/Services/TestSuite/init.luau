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

local HttpService = game:GetService("HttpService")
local Http = require(script.Parent.Parent.Internal.Http)
local MessageRouter = require(script.Parent.Parent.Internal.MessageRouter)
local Session = require(script.Parent.Parent.Internal.Session)

local TestSuite = {}

local MAX_RPS = 6

local suites: { [string]: (ctx: any) -> () } = {}
local generation = 0
local activeUntil = 0
local currentRunKey: string? = nil

function TestSuite.Register(name: string, run: (ctx: any) -> ())
	suites[name] = run
end

local lastPost = 0
local function pacedPost(path: string, body: { [string]: any })
	local minInterval = 1 / MAX_RPS
	local dt = os.clock() - lastPost
	if dt < minInterval then
		task.wait(minInterval - dt)
	end
	lastPost = os.clock()
	return Http.Post(path, body)
end

local function pacedRawPost(path: string, body: { [string]: any })
	local minInterval = 1 / MAX_RPS
	local dt = os.clock() - lastPost
	if dt < minInterval then
		task.wait(minInterval - dt)
	end
	lastPost = os.clock()
	local ok, resp = pcall(function()
		return HttpService:RequestAsync({
			Url = Session.GetBaseUrl() .. path,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(body),
		})
	end)
	if not ok then
		return { ok = false, statusCode = 0 }
	end
	local decoded: any = nil
	pcall(function()
		decoded = HttpService:JSONDecode(resp.Body)
	end)
	return { ok = resp.StatusCode >= 200 and resp.StatusCode < 300, statusCode = resp.StatusCode, body = decoded }
end

local function makeCtx(params: { [string]: any }, gen: number)
	return {
		multiplier = math.clamp(tonumber(params.multiplier) or 5, 1, 20),
		batchSize = math.clamp(tonumber(params.batchSize) or 200, 1, 1000),
		durationSec = math.clamp(tonumber(params.durationSec) or 300, 1, 86400),
		rampSec = math.max(0, tonumber(params.rampSec) or 0),
		split = math.clamp(tonumber(params.split) or 0.7, 0.05, 0.95),
		
		isActive = function()
			return gen == generation and os.clock() < activeUntil
		end,
		
		post = pacedPost,
		rawPost = pacedRawPost,
	}
end

function TestSuite._Start(name: string, params: { [string]: any }?, startedAt: any)
	params = params or {}
	local runKey = tostring(name) .. ":" .. tostring(startedAt)
	if runKey == currentRunKey and os.clock() < activeUntil then
		return
	end

	local run = suites[name]
	if not run then
		warn(`[SparkMod.TestSuite] Unknown suite '{name}' — ignoring`)
		return
	end

	generation += 1
	local gen = generation
	currentRunKey = runKey
	local ctx = makeCtx(params, gen)
	activeUntil = os.clock() + ctx.durationSec

	print(`[SparkMod.TestSuite] START '{name}' x{ctx.multiplier} for {math.floor(ctx.durationSec)}s`)
	task.spawn(function()
		local ok, err = pcall(run, ctx)
		if not ok then
			warn(`[SparkMod.TestSuite] '{name}' errored: {err}`)
		end
		if gen == generation then
			print(`[SparkMod.TestSuite] '{name}' finished`)
			currentRunKey = nil
		end
	end)
end

function TestSuite._Stop()
	generation += 1
	activeUntil = 0
	currentRunKey = nil
	print("[SparkMod.TestSuite] STOP")
end

function TestSuite._Hydrate(syncResponse: any)
	local test = syncResponse and syncResponse.test
	if typeof(test) ~= "table" or typeof(test.suite) ~= "string" then
		return
	end
	
	local params = if typeof(test.params) == "table" then table.clone(test.params) else {}
	if typeof(test.expiresAt) == "number" then
		params.durationSec = math.max(1, test.expiresAt / 1000 - os.time())
	end
	
	TestSuite._Start(test.suite, params, test.startedAt)
end

function TestSuite._Init()
	for _, child in script:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, suite = pcall(require, child)
			if ok and typeof(suite) == "table" and typeof(suite.name) == "string" and typeof(suite.run) == "function" then
				TestSuite.Register(suite.name, suite.run)
			else
				warn(`[SparkMod.TestSuite] Failed to load suite '{child.Name}': {suite}`)
			end
		end
	end

	MessageRouter.Register("test", function(action, data)
		if action == "start" then
			TestSuite._Start(data.suite, data.params, data.startedAt)
		elseif action == "stop" then
			TestSuite._Stop()
		end
	end)
end

return TestSuite
