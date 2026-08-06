--!strict
-- @author Velumix
-- @version 0.0.1
--[=[
	@class NetGuard
	@server
	Central validation and rate limiting for client-initiated Knit calls.

	NetGuard is intentionally server-only. It protects the remote boundary; game
	rules must still be validated by the service that owns them.
]=]
local Players = game:GetService("Players")

--[=[
	@interface RateLimit
	.Requests number -- Allowed requests per window.
	.Window number -- Fixed-window length in seconds.
	@within NetGuard
]=]
type RateLimit = {
	Requests: number,
	Window: number,
}

--[=[
	@interface Definition
	.RateLimit RateLimit? -- Optional per-player fixed-window limit.
	.MaxStringLength number? -- Maximum accepted string length.
	.MaxTableDepth number? -- Maximum nested table depth.
	.MaxTableEntries number? -- Maximum entries in each table.
	.AllowedTypes {[string]: boolean}? -- Explicit Roblox value types accepted before custom validation.
	.Validate ((Player, ...any) -> (boolean, string?))? -- Endpoint-specific validator.
	@within NetGuard
]=]
type Definition = {
	RateLimit: RateLimit?,
	MaxStringLength: number?,
	MaxTableDepth: number?,
	MaxTableEntries: number?,
	AllowedTypes: { [string]: boolean }?,
	Validate: ((Player, ...any) -> (boolean, string?))?,
}

type Bucket = {
	Count: number,
	ResetAt: number,
}

local DEFAULT_MAX_STRING_LENGTH = 256
local DEFAULT_MAX_TABLE_DEPTH = 4
local DEFAULT_MAX_TABLE_ENTRIES = 64

local definitions: { [string]: Definition } = {}
local buckets: { [Player]: { [string]: Bucket } } = {}
local stats: { [string]: { Accepted: number, Rejected: number } } = {}

local NetGuard = {}

local function isPositiveFinite(value: any): boolean
	return type(value) == "number" and value > 0 and value == value and value < math.huge
end

local function validatePayload(
	value: any,
	depth: number,
	seen: { [any]: boolean },
	definition: Definition
): (boolean, string?)
	local valueType = typeof(value)
	if valueType == "nil" or valueType == "boolean" then
		return true
	end

	if valueType == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return false, "INVALID_NUMBER"
		end
		return true
	end

	if valueType == "string" then
		if #value > (definition.MaxStringLength or DEFAULT_MAX_STRING_LENGTH) then
			return false, "STRING_TOO_LONG"
		end
		return true
	end

	if definition.AllowedTypes and definition.AllowedTypes[valueType] then
		return true
	end

	if valueType ~= "table" then
		return false, "UNSUPPORTED_VALUE"
	end

	if seen[value] then
		return false, "CYCLIC_TABLE"
	end
	if depth >= (definition.MaxTableDepth or DEFAULT_MAX_TABLE_DEPTH) then
		return false, "TABLE_TOO_DEEP"
	end

	seen[value] = true
	local entryCount = 0
	for key, child in pairs(value) do
		entryCount += 1
		if entryCount > (definition.MaxTableEntries or DEFAULT_MAX_TABLE_ENTRIES) then
			seen[value] = nil
			return false, "TABLE_TOO_LARGE"
		end

		local keyAllowed, keyReason = validatePayload(key, depth + 1, seen, definition)
		if not keyAllowed then
			seen[value] = nil
			return false, keyReason
		end

		local childAllowed, childReason = validatePayload(child, depth + 1, seen, definition)
		if not childAllowed then
			seen[value] = nil
			return false, childReason
		end
	end
	seen[value] = nil

	return true
end

local function reject(endpoint: string, reason: string): (boolean, string)
	stats[endpoint].Rejected += 1
	return false, reason
end

--[=[
	Registers one guarded remote endpoint. Endpoint names must be unique.

	@param endpoint string -- Stable endpoint name used for buckets and statistics.
	@param definition Definition -- Rate, payload, and custom validation policy.
]=]
function NetGuard.Define(endpoint: string, definition: Definition)
	assert(type(endpoint) == "string" and endpoint ~= "", "endpoint must be a non-empty string")
	assert(definitions[endpoint] == nil, `NetGuard endpoint already defined: {endpoint}`)

	local rateLimit = definition.RateLimit
	if rateLimit then
		assert(
			isPositiveFinite(rateLimit.Requests) and rateLimit.Requests % 1 == 0,
			"Requests must be a positive integer"
		)
		assert(isPositiveFinite(rateLimit.Window), "Window must be a positive number")
	end

	definitions[endpoint] = table.freeze(table.clone(definition))
	stats[endpoint] = {
		Accepted = 0,
		Rejected = 0,
	}
end

--[=[
	Consumes one request and evaluates its payload and custom validator.

	@param player Player -- Player that initiated the request.
	@param endpoint string -- Previously registered endpoint name.
	@param ... any -- Untrusted client arguments to inspect.
	@return boolean -- Whether the request may continue.
	@return string? -- Stable rejection code when the request is denied.
]=]
function NetGuard.Check(player: Player, endpoint: string, ...: any): (boolean, string?)
	local definition = definitions[endpoint]
	assert(definition ~= nil, `NetGuard endpoint is not defined: {endpoint}`)

	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return reject(endpoint, "INVALID_PLAYER")
	end

	local rateLimit = definition.RateLimit
	if rateLimit then
		local now = os.clock()
		local playerBuckets = buckets[player]
		if not playerBuckets then
			playerBuckets = {}
			buckets[player] = playerBuckets
		end

		local existingBucket = playerBuckets[endpoint]
		local bucket: Bucket
		if not existingBucket or now >= existingBucket.ResetAt then
			bucket = {
				Count = 0,
				ResetAt = now + rateLimit.Window,
			}
			playerBuckets[endpoint] = bucket
		else
			bucket = existingBucket
		end

		bucket.Count += 1
		if bucket.Count > rateLimit.Requests then
			return reject(endpoint, "RATE_LIMITED")
		end
	end

	local arguments = table.pack(...)
	for index = 1, arguments.n do
		local allowed, reason = validatePayload(arguments[index], 0, {}, definition)
		if not allowed then
			return reject(endpoint, reason or "INVALID_PAYLOAD")
		end
	end

	if definition.Validate then
		local callResult = table.pack(xpcall(definition.Validate, debug.traceback, player, ...))
		if not callResult[1] then
			warn(`NetGuard validator failed for {endpoint}: {callResult[2]}`)
			return reject(endpoint, "VALIDATION_FAILED")
		end
		if not callResult[2] then
			local rawReason = callResult[3]
			local rejectionReason: string = if type(rawReason) == "string" then rawReason else "INVALID_REQUEST"
			return reject(endpoint, rejectionReason)
		end
	end

	stats[endpoint].Accepted += 1
	return true
end

--[=[
	Returns a detached snapshot of accepted and rejected counts by endpoint.

	@return {[string]: {Accepted: number, Rejected: number}}
]=]
function NetGuard.GetStats(): { [string]: { Accepted: number, Rejected: number } }
	local snapshot = {}
	for endpoint, endpointStats in pairs(stats) do
		snapshot[endpoint] = table.clone(endpointStats)
	end
	return snapshot
end

--[=[
	Clears every rate-limit bucket owned by a player. NetGuard calls this
	automatically when the player leaves.

	@param player Player
]=]
function NetGuard.ClearPlayer(player: Player)
	buckets[player] = nil
end

Players.PlayerRemoving:Connect(NetGuard.ClearPlayer)

return table.freeze(NetGuard)
