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

-- ========== Constants ========== --

local PROTOCOL_VERSION = 1
local MAX_MESSAGE_LENGTH = 1024

-- ========== Key Maps ========== --

-- Compact → Expanded (for decoding inbound messages from backend)
local EVENT_KEY_MAP = {
	n = "eventName",
	ea = "endsAt",
	ds = "durationSeconds",
	tb = "triggeredBy",
	cfg = "config",
	st = "state",
	rs = "remainingSeconds",
	su = "stateUpdates",
	ck = "changedKeys",
}

local STOCK_KEY_MAP = {
	id = "eventId",
	dc = "displayCount",
	ps = "publicStock",
	tc = "totalClaims",
	dp = "depleted",
	da = "depletedAt",
	rm = "removed",
	bl = "baseline",
	c = "claims",
	pd = "publicDisplay",
	hs = "hiddenStock",
	ts = "timestamp",
	pi = "poolId",
	rn = "rotationNumber",
	nr = "nextRotationAt",
}
local ACTION_KEY_MAP = {
	an = "actionName",
	p = "params",
	bid = "broadcastId",
	sj = "sourceJobId",
	sl = "serverLimit",
}

local SHOP_KEY_MAP = {
	di = "dayIndex",
}

local CMD_KEY_MAP = {
	target = "target",
	cmd = "command",
}

local POLL_KEY_MAP = {
	pi = "pollId",
	q = "question",
	op = "options",
	du = "duration",
	ea = "endsAt",
	ta = "tallies",
	tr = "totalResponses",
	pc = "playerCount",
}

local TEST_KEY_MAP = {
	s = "suite",
	p = "params",
	sa = "startedAt",
}

-- ========== Helpers ========== --

local function expandKeys(data: { [string]: any }, keyMap: { [string]: string }): { [string]: any }
	local expanded: { [string]: any } = {}
	for key, value in data do
		local expandedKey = keyMap[key] or key
		expanded[expandedKey] = value
	end
	return expanded
end

local function expandStockBatch(batch: { any }): { any }
	local expanded = {}
	for _, entry in batch do
		if typeof(entry) == "table" then
			table.insert(expanded, expandKeys(entry, STOCK_KEY_MAP))
		elseif typeof(entry) == "string" then
			table.insert(expanded, entry)
		end
	end
	return expanded
end

-- ========== Module ========== --

local module = {}

export type DecodedMessage = {
	version: number,
	messageType: string,
	action: string,
	data: { [string]: any },
}

function module.Decode(raw: string): DecodedMessage?
	local success, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
	if not success or typeof(parsed) ~= "table" then return nil end

	local version = parsed.v
	local messageType = parsed.t
	local action = parsed.a
	local data = parsed.d

	if version ~= PROTOCOL_VERSION then return nil end
	if not messageType or not action or typeof(data) ~= "table" then return nil end

	-- Expand compact keys based on message type
	local expandedData: { [string]: any }
	if messageType == "event" then
		expandedData = expandKeys(data, EVENT_KEY_MAP)
	elseif messageType == "stock" then
		expandedData = expandKeys(data, STOCK_KEY_MAP)
		-- Expand batch entries if present
		if expandedData.b and typeof(expandedData.b) == "table" then
			expandedData.batch = expandStockBatch(expandedData.b)
			expandedData.b = nil
		end
	elseif messageType == "action" then
		expandedData = expandKeys(data, ACTION_KEY_MAP)
	elseif messageType == "shop" then
		expandedData = expandKeys(data, SHOP_KEY_MAP)
	elseif messageType == "cmd" then
		expandedData = expandKeys(data, CMD_KEY_MAP)
	elseif messageType == "poll" then
		expandedData = expandKeys(data, POLL_KEY_MAP)
	elseif messageType == "test" then
		expandedData = expandKeys(data, TEST_KEY_MAP)
	else
		expandedData = data
	end

	return {
		version = version,
		messageType = messageType,
		action = action,
		data = expandedData,
	}
end

function module.Encode(messageType: string, action: string, data: { [string]: any }): string
	local message = {
		v = PROTOCOL_VERSION,
		t = messageType,
		a = action,
		d = data,
	}

	local encoded = HttpService:JSONEncode(message)

	if #encoded > MAX_MESSAGE_LENGTH then
		warn(string.format(
			"[SparkMod.MessageCodec] Encode: Message exceeds %d char limit (%d chars). Type: %s, Action: %s",
			MAX_MESSAGE_LENGTH, #encoded, messageType, action
		))
	end

	return encoded
end

module.PROTOCOL_VERSION = PROTOCOL_VERSION
module.MAX_MESSAGE_LENGTH = MAX_MESSAGE_LENGTH

return table.freeze(module)
