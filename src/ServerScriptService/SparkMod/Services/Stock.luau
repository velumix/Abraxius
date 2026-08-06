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

-- ========== Dependencies ========== --

local HttpService = game:GetService("HttpService")
local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)
local Http = require(script.Parent.Parent.Internal.Http)
local Session = require(script.Parent.Parent.Internal.Session)
local MessageRouter = require(script.Parent.Parent.Internal.MessageRouter)
local Remotes = require(game.ReplicatedStorage.SparkMod.Internal.Remotes)
local StockTypes = require(game.ReplicatedStorage.SparkMod.Types.Stock)

-- ========== Types ========== --

type StockItemCache = {
	eventId: string,
	itemId: string?,
	rewardType: string?,
	rewardId: string?,
	current: number,
	total: number,
	depleted: boolean,
	depletedAt: number?,
	infinite: boolean,
	poolId: string?,
	metadata: { [string]: any }?,
	label: string?,
	expiresAt: number?,
}

type PoolSlot = {
	itemId: string,
	eventId: string,
	slotIndex: number,
	injected: boolean?,
}

type PoolCache = {
	poolId: string,
	slots: number,
	strategy: string,
	currentItems: { PoolSlot },
	rotationNumber: number,
	nextRotationAt: number?,
}

-- ========== State ========== --

local handlers: { [string]: StockTypes.StockHandler } = {}
local stockItems: { [string]: StockItemCache } = {}
local pools: { [string]: PoolCache } = {}
local configHash: string? = nil

-- HasClaimed cache — positive results only (a claim can never un-happen)
local claimedChecks: { [string]: StockTypes.ClaimCheck } = {}

local ready = false
local initialized = false

-- ========== Helpers ========== --

local function urlEncode(s: string): string
	return (HttpService:UrlEncode(s))
end

local function seedClaimCheck(eventId: string, userId: number, claimNumber: number?)
	local key = eventId .. ":" .. userId
	local prior = claimedChecks[key]
	claimedChecks[key] = {
		claimed = true,
		claimCount = (if prior then prior.claimCount else 0) + 1,
		claimNumber = if prior then prior.claimNumber else claimNumber,
		claimedAt = if prior then prior.claimedAt else os.time(),
	}
end

-- ========== Signals ========== --

local Stock = {}

Stock.Ready = Signal.new()

Stock.Updated = Signal.new()
Stock.Depleted = Signal.new()
Stock.Rotated = Signal.new()
Stock.RegistrationChanged = Signal.new()
Stock.Removed = Signal.new()

-- ========== Ready ========== --

function Stock:IsReady(): boolean
	return ready
end

function Stock:WaitForReady()
	if ready then return end
	Stock.Ready:Wait()
end

-- ========== Registration ========== --

function Stock:RegisterHandler(rewardType: string, handler: StockTypes.StockHandler)
	handlers[rewardType] = handler
end

function Stock:UnregisterHandler(rewardType: string)
	handlers[rewardType] = nil
end

-- ========== ConfigService Integration ========== --

local function djb2Hash(str: string): string
	local hash = 5381
	for i = 1, #str do
		hash = ((hash * 33) + string.byte(str, i)) % 2 ^ 32
	end
	return tostring(#str) .. ":" .. tostring(hash)
end

local function loadAndRegister()
	local ConfigService = game:GetService("ConfigService")

	local ok, snapshot = pcall(ConfigService.GetConfigAsync, ConfigService)
	if not ok or not snapshot then
		warn("[SparkMod.Stock] Failed to load ConfigService snapshot")
		return
	end

	local itemsRaw = snapshot:GetValue("stock_items")
	local poolsRaw = snapshot:GetValue("stock_pools")

	if not itemsRaw and not poolsRaw then return end

	local itemsDef: { [string]: any }? = nil
	local poolsDef: { [string]: any }? = nil

	if itemsRaw then
		if typeof(itemsRaw) == "string" then
			local parseOk, parsed = pcall(HttpService.JSONDecode, HttpService, itemsRaw)
			if parseOk then itemsDef = parsed end
		elseif typeof(itemsRaw) == "table" then
			itemsDef = itemsRaw
		end
	end

	if poolsRaw then
		if typeof(poolsRaw) == "string" then
			local parseOk, parsed = pcall(HttpService.JSONDecode, HttpService, poolsRaw)
			if parseOk then poolsDef = parsed end
		elseif typeof(poolsRaw) == "table" then
			poolsDef = poolsRaw
		end
	end

	if not itemsDef and not poolsDef then return end

	local combined = HttpService:JSONEncode({ items = itemsDef, pools = poolsDef })
	local newHash = djb2Hash(combined)

	if newHash == configHash then return end
	configHash = newHash

	local response = Http.Post("/game/stock/register", {
		items = itemsDef or {},
		pools = poolsDef or {},
		configHash = newHash,
	})

	if response.ok then
		if response.body and response.body.stockEvents and typeof(response.body.stockEvents) == "table" then
			for eventId, status in response.body.stockEvents do
				if typeof(status) == "table" then
					local isInfinite = status.current == -1 or status.total == -1 or status.infinite == true
					local existing = stockItems[eventId]
					local depleted = if isInfinite then false else (status.depleted or false)

					stockItems[eventId] = {
						eventId = eventId,
						rewardType = status.rewardType or (existing and existing.rewardType),
						rewardId = status.rewardId or (existing and existing.rewardId),
						current = status.current or 0,
						total = status.total or 0,
						depleted = depleted,
						depletedAt = if depleted then (status.depletedAt or (existing and existing.depletedAt) or os.time()) else nil,
						infinite = isInfinite,
						metadata = status.metadata or (existing and existing.metadata),
						label = status.label or (existing and existing.label),
						expiresAt = status.expiresAt or (existing and existing.expiresAt),
					}

					Stock.Updated:Fire(eventId, stockItems[eventId])
				end
			end
		end

		Stock.RegistrationChanged:Fire()
	else
		warn("[SparkMod.Stock] Registration failed:", response.error or "unknown error")
	end

	pcall(function()
		snapshot.UpdateAvailable:Connect(function()
			pcall(snapshot.Refresh, snapshot)
			loadAndRegister()
		end)
	end)
end

-- ========== Claims ========== --

function Stock:Claim(eventId: string, player: Player): (boolean, string?)
	local item = stockItems[eventId]
	if not item then
		return false, "Stock item not found"
	end

	if not item.infinite and item.depleted then
		return false, "Stock depleted"
	end

	-- Check handler eligibility
	if item.rewardType then
		local handler = handlers[item.rewardType]
		if handler and handler.CanGrant then
			local canGrant, reason = handler.CanGrant(player, item.rewardId or eventId)
			if not canGrant then
				return false, reason or "Cannot grant reward"
			end
		end
	end

	-- Call backend for atomic claim
	local response = Http.Post("/game/stock/claim", {
		eventId = eventId,
		userId = player.UserId,
		serverId = Session.Get(),
	})

	if not response.ok or not response.body then
		return false, response.body and response.body.error or "Claim failed"
	end

	local body = response.body

	if body.ok == false then
		if body.depleted then
			item.depleted = true
			Stock.Updated:FireAsync(eventId, item)
			Stock.Depleted:FireAsync(eventId)
		end
		return false, body.error or "Claim denied"
	end

	if body.displayStock ~= nil then
		item.current = body.displayStock
	end
	if body.depleted then
		item.depleted = true
	end

	seedClaimCheck(eventId, player.UserId, body.claimNumber)

	Stock.Updated:FireAsync(eventId, item)

	if body.depleted then
		Stock.Depleted:FireAsync(eventId)

		if item.rewardType then
			local handler = handlers[item.rewardType]
			if handler and handler.OnDepleted then
				task.spawn(handler.OnDepleted, eventId)
			end
		end
	end

	if item.rewardType then
		local handler = handlers[item.rewardType]
		if handler and handler.OnGranted then
			local grantOk, grantErr = pcall(handler.OnGranted, player, item.rewardId or eventId, body.claimNumber or 0)
			if not grantOk then
				warn(`[SparkMod.Stock] OnGranted error for '{eventId}': {grantErr}`)
			end
		end
	end

	return true, nil
end

-- ========== Reservations ========== --

function Stock:Reserve(
	eventId: string,
	player: Player,
	options: StockTypes.ReserveOptions
): (boolean, any)
	if typeof(eventId) ~= "string" or eventId == "" then
		return false, "eventId is required"
	end
	if typeof(options) ~= "table" then
		return false, "options is required (with ttlSeconds)"
	end
	if typeof(options.ttlSeconds) ~= "number" or options.ttlSeconds <= 0 then
		return false, "options.ttlSeconds must be a positive number"
	end

	local item = stockItems[eventId]
	if item and not item.infinite and item.depleted then
		return false, "Stock depleted"
	end

	if item and item.rewardType then
		local handler = handlers[item.rewardType]
		if handler and handler.CanGrant then
			local canGrant, reason = handler.CanGrant(player, item.rewardId or eventId)
			if not canGrant then
				return false, reason or "Cannot grant reward"
			end
		end
	end

	local response = Http.Post("/game/stock/reserve", {
		eventId = eventId,
		userId = player.UserId,
		serverId = Session.Get(),
		ttlSeconds = options.ttlSeconds,
	})

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "Reserve failed"
	end

	local body = response.body
	if item and body.displayStock ~= nil then
		item.current = body.displayStock
		Stock.Updated:FireAsync(eventId, item)
	end

	return true, {
		id = body.reservationId,
		expiresAt = body.expiresAt,
		displayStock = body.displayStock,
		reused = body.reused == true,
		depleted = body.depleted == true,
	}
end

function Stock:CommitReservation(
	reservationId: string,
	player: Player?
): (boolean, any)
	if typeof(reservationId) ~= "string" or reservationId == "" then
		return false, "reservationId is required"
	end

	local response = Http.Post(
		"/game/stock/reservations/" .. urlEncode(reservationId) .. "/commit",
		{}
	)

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "Commit failed"
	end

	local body = response.body
	if player and body.depleted then
		task.spawn(function()
			Stock:RefreshActive()
		end)
	end

	return true, {
		claimNumber = body.claimNumber,
		displayStock = body.displayStock,
		depleted = body.depleted == true,
	}
end

function Stock:CancelReservation(reservationId: string): (boolean, string?)
	if typeof(reservationId) ~= "string" or reservationId == "" then
		return false, "reservationId is required"
	end

	local response = Http.Post(
		"/game/stock/reservations/" .. urlEncode(reservationId) .. "/cancel",
		{}
	)

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "Cancel failed"
	end

	return true, nil
end

function Stock:ClaimWithReservation(
	eventId: string,
	player: Player,
	options: StockTypes.ReserveOptions,
	callback: () -> any
): (boolean, any)
	local ok, reservation = Stock:Reserve(eventId, player, options)
	if not ok then
		return false, reservation
	end

	local reservationId = (reservation :: any).id
	if typeof(reservationId) ~= "string" then
		return false, "Reserve returned no reservationId"
	end

	local callOk, callResult = pcall(callback)
	if not callOk then
		Stock:CancelReservation(reservationId)
		error(callResult, 2)
	end

	if not callResult then
		Stock:CancelReservation(reservationId)
		return false, "Purchase callback returned falsy"
	end

	local committed, commitInfo = Stock:CommitReservation(reservationId, player)
	if not committed then
		return false, commitInfo
	end

	seedClaimCheck(eventId, player.UserId, (commitInfo :: any).claimNumber)

	local item = stockItems[eventId]
	if item and item.rewardType then
		local handler = handlers[item.rewardType]
		if handler and handler.OnGranted then
			local grantOk, grantErr = pcall(
				handler.OnGranted,
				player,
				item.rewardId or eventId,
				(commitInfo :: any).claimNumber or 0
			)
			if not grantOk then
				warn(`[SparkMod.Stock] OnGranted error for '{eventId}': {grantErr}`)
			end
		end
	end

	return true, commitInfo
end

-- ========== Claim Lookup ========== --

function Stock:HasClaimed(eventId: string, playerOrUserId: Player | number): (boolean, any)
	if typeof(eventId) ~= "string" or eventId == "" then
		return false, "eventId is required"
	end

	local userId: number
	if typeof(playerOrUserId) == "number" then
		userId = playerOrUserId
	elseif typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		userId = (playerOrUserId :: Player).UserId
	else
		return false, "player or userId is required"
	end

	local key = eventId .. ":" .. userId
	local cached = claimedChecks[key]
	if cached then
		return true, cached
	end

	local response = Http.Get(
		"/game/stock/claims/check?eventId=" .. urlEncode(eventId) .. "&userId=" .. userId
	)
	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "HasClaimed failed"
	end

	local body = response.body
	local result: StockTypes.ClaimCheck = {
		claimed = body.claimed == true,
		claimCount = body.claimCount or 0,
		claimNumber = body.claimNumber,
		claimedAt = body.claimedAt,
	}
	if result.claimed then
		claimedChecks[key] = result
	end
	return true, result
end

-- ========== Queries ========== --

function Stock:GetStatus(eventId: string): StockItemCache?
	return stockItems[eventId]
end

function Stock:GetAllActive(): { [string]: StockItemCache }
	return stockItems
end

function Stock:IsAvailable(eventId: string): boolean
	local item = stockItems[eventId]
	if not item then return false end
	if item.infinite then return true end
	return not item.depleted
end

function Stock:GetRotation(poolId: string): PoolCache?
	return pools[poolId]
end

function Stock:GetAllPools(): { [string]: PoolCache }
	return pools
end

-- ========== Async Queries ========== --

function Stock:GetStatusAsync(eventId: string): StockItemCache?
	local cached = Stock:GetStatus(eventId)
	if cached then return cached end
	self:WaitForReady()
	return Stock:GetStatus(eventId)
end

function Stock:GetAllActiveAsync(): { [string]: StockItemCache }
	if ready or next(stockItems) ~= nil then
		return Stock:GetAllActive()
	end
	self:WaitForReady()
	return Stock:GetAllActive()
end

function Stock:IsAvailableAsync(eventId: string): boolean
	if Stock:GetStatus(eventId) then
		return Stock:IsAvailable(eventId)
	end
	self:WaitForReady()
	return Stock:IsAvailable(eventId)
end

function Stock:GetRotationAsync(poolId: string): PoolCache?
	local cached = Stock:GetRotation(poolId)
	if cached then return cached end
	self:WaitForReady()
	return Stock:GetRotation(poolId)
end

function Stock:GetAllPoolsAsync(): { [string]: PoolCache }
	if ready or next(pools) ~= nil then
		return Stock:GetAllPools()
	end
	self:WaitForReady()
	return Stock:GetAllPools()
end

-- ========== Programmatic Operations ========== --

function Stock:CreateEntry(options: StockTypes.EntryOptions): (boolean, any)
	if typeof(options) ~= "table" then
		return false, "options must be a table"
	end
	if typeof(options.eventId) ~= "string" or options.eventId == "" then
		return false, "eventId is required"
	end
	if typeof(options.rewardType) ~= "string" or options.rewardType == "" then
		return false, "rewardType is required"
	end
	if typeof(options.rewardId) ~= "string" or options.rewardId == "" then
		return false, "rewardId is required"
	end
	if typeof(options.publicStock) ~= "number" then
		return false, "publicStock is required"
	end
	if typeof(options.hiddenStock) ~= "number" then
		return false, "hiddenStock is required"
	end
	if options.metadata ~= nil and typeof(options.metadata) ~= "table" then
		return false, "metadata must be a table or nil"
	end

	local response = Http.Post("/game/stock/entries", {
		eventId = options.eventId,
		rewardType = options.rewardType,
		rewardId = options.rewardId,
		publicStock = options.publicStock,
		hiddenStock = options.hiddenStock,
		expiresAt = options.expiresAt,
		holdReservations = options.holdReservations,
		label = options.label,
		metadata = options.metadata,
	})

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "CreateEntry failed"
	end

	local row = response.body.stockEvent
	if typeof(row) == "table" and typeof(row.eventId) == "string" then
		local hidden = row.hiddenStock or options.hiddenStock
		local public = row.publicStock or options.publicStock
		local isInfinite = hidden == -1
		stockItems[row.eventId] = {
			eventId = row.eventId,
			rewardType = row.rewardType,
			rewardId = row.rewardId,
			current = if isInfinite then -1 else public,
			total = if isInfinite then -1 else public,
			depleted = false,
			infinite = isInfinite,
			metadata = row.metadata or options.metadata,
			label = row.label or options.label,
			expiresAt = options.expiresAt,
		}
		Stock.Updated:FireAsync(row.eventId, stockItems[row.eventId])
	end

	return true, row
end

function Stock:RefreshStatus(eventIds: { string } | string): (boolean, any)
	local idsList: { string }
	if typeof(eventIds) == "string" then
		idsList = { eventIds }
	elseif typeof(eventIds) == "table" then
		idsList = eventIds
	else
		return false, "eventIds must be a string or array of strings"
	end

	if #idsList == 0 then
		return true, {}
	end

	local encoded = {}
	for _, id in idsList do
		if typeof(id) == "string" and id ~= "" then
			table.insert(encoded, urlEncode(id))
		end
	end

	local response = Http.Get("/game/stock/status?eventIds=" .. table.concat(encoded, ","))
	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "RefreshStatus failed"
	end

	local refreshed: { [string]: any } = {}
	if typeof(response.body.stockEvents) == "table" then
		for eventId, status in response.body.stockEvents do
			if typeof(status) == "table" then
				local isInfinite = status.current == -1 or status.total == -1 or status.infinite == true
				local existing = stockItems[eventId]
				local depleted = if isInfinite then false else (status.depleted or false)
				stockItems[eventId] = {
					eventId = eventId,
					rewardType = status.rewardType or (existing and existing.rewardType),
					rewardId = status.rewardId or (existing and existing.rewardId),
					current = status.current or (existing and existing.current) or 0,
					total = status.total or (existing and existing.total) or 0,
					depleted = depleted,
					depletedAt = if depleted then (status.depletedAt or (existing and existing.depletedAt) or os.time()) else nil,
					infinite = isInfinite,
					metadata = status.metadata or (existing and existing.metadata),
					label = status.label or (existing and existing.label),
					expiresAt = status.expiresAt or (existing and existing.expiresAt),
				}
				refreshed[eventId] = stockItems[eventId]
				Stock.Updated:FireAsync(eventId, stockItems[eventId])
			end
		end
	end

	return true, refreshed
end

function Stock:RemoveEntry(eventId: string): (boolean, string?)
	if typeof(eventId) ~= "string" or eventId == "" then
		return false, "eventId is required"
	end

	local response = Http.Delete("/game/stock/entries/" .. urlEncode(eventId))

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "RemoveEntry failed"
	end

	if stockItems[eventId] then
		stockItems[eventId] = nil
		Stock.Updated:FireAsync(eventId, nil)
	end

	return true, nil
end

function Stock:InjectInline(poolId: string, options: StockTypes.InlineSlotOptions): (boolean, any)
	if typeof(poolId) ~= "string" or poolId == "" then
		return false, "poolId is required"
	end
	if typeof(options) ~= "table" then
		return false, "options must be a table"
	end
	if typeof(options.rewardType) ~= "string" or options.rewardType == "" then
		return false, "rewardType is required"
	end
	if typeof(options.rewardId) ~= "string" or options.rewardId == "" then
		return false, "rewardId is required"
	end
	if typeof(options.publicStock) ~= "number" then
		return false, "publicStock is required"
	end
	if typeof(options.hiddenStock) ~= "number" then
		return false, "hiddenStock is required"
	end

	local response = Http.Post("/game/stock/pools/" .. urlEncode(poolId) .. "/inject-inline", {
		rewardType = options.rewardType,
		rewardId = options.rewardId,
		publicStock = options.publicStock,
		hiddenStock = options.hiddenStock,
		metadata = options.metadata,
		label = options.label,
		expiresAt = options.expiresAt,
		itemIdHint = options.itemIdHint,
		holdReservations = options.holdReservations,
	})

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "InjectInline failed"
	end

	local eventId = response.body.eventId
	if typeof(eventId) == "string" then
		local hidden = options.hiddenStock
		local isInfinite = hidden == -1
		stockItems[eventId] = {
			eventId = eventId,
			rewardType = options.rewardType,
			rewardId = options.rewardId,
			current = if isInfinite then -1 else options.publicStock,
			total = if isInfinite then -1 else options.publicStock,
			depleted = false,
			infinite = isInfinite,
			metadata = options.metadata,
			label = options.label,
			expiresAt = options.expiresAt,
		}
		Stock.Updated:FireAsync(eventId, stockItems[eventId])
	end

	return true, {
		eventId = eventId,
		stockEventId = response.body.stockEventId,
		slotIndex = response.body.slotIndex,
		rotationNumber = response.body.rotationNumber,
	}
end

function Stock:RemoveInline(eventId: string): (boolean, string?)
	if typeof(eventId) ~= "string" or eventId == "" then
		return false, "eventId is required"
	end

	local response = Http.Delete("/game/stock/inject-inline/" .. urlEncode(eventId))

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "RemoveInline failed"
	end

	if stockItems[eventId] then
		stockItems[eventId] = nil
		Stock.Updated:FireAsync(eventId, nil)
	end

	return true, nil
end

function Stock:PushStock(eventId: string, options: StockTypes.PushOptions?): (boolean, any)
	if typeof(eventId) ~= "string" or eventId == "" then
		return false, "eventId is required"
	end

	local opts: StockTypes.PushOptions = options or ({} :: any)
	local addPublic = opts.addPublic or 0
	local addHidden = opts.addHidden or 0
	if addPublic <= 0 and addHidden <= 0 then
		return false, "Push must add at least one stock unit"
	end

	local response = Http.Post("/game/stock/pushes", {
		eventId = eventId,
		addPublic = addPublic,
		addHidden = addHidden,
		expiresAt = opts.expiresAt,
		note = opts.note,
	})

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "PushStock failed"
	end

	return true, response.body.push
end

function Stock:DecrementStock(eventId: string, options: StockTypes.DecrementOptions?): (boolean, any)
	if typeof(eventId) ~= "string" or eventId == "" then
		return false, "eventId is required"
	end

	local opts: StockTypes.DecrementOptions = options or ({} :: any)
	local decreasePublic = opts.decreasePublic or 0
	local decreaseHidden = opts.decreaseHidden or 0
	if decreasePublic <= 0 and decreaseHidden <= 0 then
		return false, "Decrement must reduce at least one stock unit"
	end

	local response = Http.Post("/game/stock/entries/" .. urlEncode(eventId) .. "/decrement", {
		decreasePublic = decreasePublic,
		decreaseHidden = decreaseHidden,
	})

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "DecrementStock failed"
	end

	return true, response.body.stockEvent
end

function Stock:RevokePush(pushId: string): (boolean, string?)
	if typeof(pushId) ~= "string" or pushId == "" then
		return false, "pushId is required"
	end

	local response = Http.Delete("/game/stock/pushes/" .. urlEncode(pushId))

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "RevokePush failed"
	end

	return true, nil
end

function Stock:ListPushes(): (boolean, any)
	local response = Http.Get("/game/stock/pushes")

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "ListPushes failed"
	end

	return true, response.body.pushes or {}
end

function Stock:InjectPoolItem(poolId: string, options: StockTypes.InjectOptions): (boolean, any)
	if typeof(poolId) ~= "string" or poolId == "" then
		return false, "poolId is required"
	end
	if typeof(options) ~= "table" then
		return false, "options must be a table"
	end
	if typeof(options.itemId) ~= "string" or options.itemId == "" then
		return false, "options.itemId is required"
	end

	local response = Http.Post("/game/stock/pools/" .. urlEncode(poolId) .. "/injections", {
		itemId = options.itemId,
		mode = options.mode or "current",
		weight = options.weight,
		stockOverride = options.stockOverride,
		expiresAt = options.expiresAt,
		note = options.note,
	})

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "InjectPoolItem failed"
	end

	return true, {
		injection = response.body.injection,
		stockEvent = response.body.stockEvent,
	}
end

function Stock:RemoveInjection(injectionId: string): (boolean, string?)
	if typeof(injectionId) ~= "string" or injectionId == "" then
		return false, "injectionId is required"
	end

	local response = Http.Delete("/game/stock/injections/" .. urlEncode(injectionId))

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "RemoveInjection failed"
	end

	task.spawn(function()
		Stock:RefreshActive()
	end)

	return true, nil
end

function Stock:RefreshActive(): (boolean, any)
	local response = Http.Get("/game/stock/all-active")
	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "RefreshActive failed"
	end

	local fresh: { [string]: any } = {}
	if typeof(response.body.stockEvents) == "table" then
		for eventId, status in response.body.stockEvents do
			if typeof(status) == "table" then
				local isInfinite = status.current == -1 or status.total == -1 or status.infinite == true
				local existing = stockItems[eventId]
				local depleted = if isInfinite then false else (status.depleted or false)
				fresh[eventId] = {
					eventId = eventId,
					rewardType = status.rewardType or (existing and existing.rewardType),
					rewardId = status.rewardId or (existing and existing.rewardId),
					current = status.current or 0,
					total = status.total or 0,
					depleted = depleted,
					depletedAt = if depleted then (status.depletedAt or (existing and existing.depletedAt) or os.time()) else nil,
					infinite = isInfinite,
					metadata = status.metadata or (existing and existing.metadata),
					label = status.label or (existing and existing.label),
					expiresAt = status.expiresAt or (existing and existing.expiresAt),
				}
			end
		end
	end

	for eventId in stockItems do
		if not fresh[eventId] then
			Stock.Updated:FireAsync(eventId, nil)
		end
	end

	stockItems = fresh
	return true, fresh
end

-- Refresh a single pool's state (currentItems + per-slot stock statuses) from
-- the coordinator. Used by the rotate handler to pull state on demand without
-- bloating the broadcast payload.
function Stock:RefreshPool(poolId: string): (boolean, any)
	if typeof(poolId) ~= "string" or poolId == "" then
		return false, "poolId is required"
	end

	local response = Http.Get("/game/stock/pools/" .. urlEncode(poolId) .. "/state")
	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "RefreshPool failed"
	end

	local pool = response.body.pool
	local poolStockEvents = response.body.stockEvents

	if typeof(poolStockEvents) == "table" then
		for eventId, status in poolStockEvents do
			if typeof(status) == "table" then
				local isInfinite = status.current == -1 or status.total == -1 or status.infinite == true
				local existing = stockItems[eventId]
				local depleted = if isInfinite then false else (status.depleted or false)
				stockItems[eventId] = {
					eventId = eventId,
					itemId = (existing and existing.itemId),
					rewardType = status.rewardType or (existing and existing.rewardType),
					rewardId = status.rewardId or (existing and existing.rewardId),
					current = status.current or 0,
					total = status.total or 0,
					depleted = depleted,
					depletedAt = if depleted then (status.depletedAt or (existing and existing.depletedAt) or os.time()) else nil,
					infinite = isInfinite,
					poolId = poolId,
					metadata = status.metadata or (existing and existing.metadata),
					label = status.label or (existing and existing.label),
					expiresAt = status.expiresAt or (existing and existing.expiresAt),
				}
				Stock.Updated:FireAsync(eventId, stockItems[eventId])
			end
		end
	end

	if typeof(pool) == "table" then
		local currentItems: { PoolSlot } = {}
		if typeof(pool.currentItems) == "table" then
			for _, slot in pool.currentItems do
				if typeof(slot) == "table" then
					table.insert(currentItems, {
						itemId = slot.itemId or "",
						eventId = slot.eventId or "",
						slotIndex = slot.slotIndex or 0,
						injected = slot.injected == true,
					})
				end
			end
		end

		pools[poolId] = {
			poolId = poolId,
			slots = pool.slots or #currentItems,
			strategy = pool.strategy or "",
			currentItems = currentItems,
			rotationNumber = pool.rotationNumber or 0,
			nextRotationAt = pool.nextRotationAt,
		}

		Stock.Rotated:FireAsync(poolId, pools[poolId])
	end

	return true, pools[poolId]
end

-- List currently-active injections. Optional poolId filter scopes results
-- to a single pool.
function Stock:ListInjections(poolId: string?): (boolean, any)
	local path = "/game/stock/injections"
	if poolId and poolId ~= "" then
		path = path .. "?poolId=" .. urlEncode(poolId)
	end

	local response = Http.Get(path)

	if not response.ok or not response.body or response.body.ok == false then
		return false, response.body and response.body.error or response.error or "ListInjections failed"
	end

	return true, response.body.injections or {}
end

-- ========== Coordinator Message Handler ========== --

local function evictEvent(eventId: string, reason: string)
	if stockItems[eventId] == nil then return end
	stockItems[eventId] = nil
	Stock.Updated:FireAsync(eventId, nil)
	Stock.Removed:FireAsync(eventId, reason)
end

local function onStockMessage(action: string, data: { [string]: any })
	if action == "update" then

		local batch = data.batch

		if batch and typeof(batch) == "table" then
			for _, entry in batch do
				local eventId = entry.eventId

				if eventId then
					if entry.removed == true then
						evictEvent(eventId, "invalidated")
						continue
					end

					local item = stockItems[eventId]
					local isInfinite = entry.displayCount == -1
					local newDepleted = if isInfinite then false else (entry.depleted or false)

					if item then
						item.current = entry.displayCount or item.current

						if entry.publicStock ~= nil then
							item.total = entry.publicStock
						end

						item.infinite = isInfinite
						item.depleted = newDepleted
						if newDepleted then
							item.depletedAt = entry.depletedAt or item.depletedAt or os.time()
						else
							item.depletedAt = nil
						end

						Stock.Updated:FireAsync(eventId, item)

						if not isInfinite and entry.depleted then
							Stock.Depleted:FireAsync(eventId)

							if item.rewardType then
								local handler = handlers[item.rewardType]
								if handler and handler.OnDepleted then
									task.spawn(handler.OnDepleted, eventId)
								end
							end
						end
					else
						stockItems[eventId] = {
							eventId = eventId,
							current = entry.displayCount or 0,
							total = entry.publicStock or entry.displayCount or 0,
							depleted = newDepleted,
							depletedAt = if newDepleted then (entry.depletedAt or os.time()) else nil,
							infinite = isInfinite,
						}

						Stock.Updated:FireAsync(eventId, stockItems[eventId])
					end
				end
			end
		end

	elseif action == "invalidate" then

		local batch = data.batch
		if typeof(batch) == "table" then
			for _, eventId in batch do
				if typeof(eventId) == "string" and eventId ~= "" then
					evictEvent(eventId, "invalidated")
				end
			end
		end

	elseif action == "rotate" then

		local poolId = data.poolId
		if not poolId then return end

		task.spawn(function()
			task.wait(math.random() * 2)
			Stock:RefreshPool(poolId)
		end)

	elseif action == "baseline" then
		
		local eventId = data.eventId
		if eventId then
			local item = stockItems[eventId]
			if item then
				if data.displayCount ~= nil then
					item.current = data.displayCount
				end
				Stock.Updated:FireAsync(eventId, item)
			end
		end
		
	end
end

-- ========== Initialization ========== --

function Stock._Init()
	if initialized then return end
	initialized = true

	MessageRouter.Register("stock", onStockMessage)
	Remotes:Init()

	Stock.Updated:Connect(function(eventId, item)
		if item == nil then
			Remotes:FireAllClients("SparkMod.Stock.Removed", eventId)
			return
		end
		Remotes:FireAllClients("SparkMod.Stock.Updated", eventId, {
			eventId = item.eventId,
			itemId = item.itemId,
			current = item.current,
			total = item.total,
			depleted = item.depleted,
			poolId = item.poolId,
		})
	end)

	Stock.Depleted:Connect(function(eventId)
		Remotes:FireAllClients("SparkMod.Stock.Depleted", eventId)
	end)

	Stock.Rotated:Connect(function(poolId, poolState)
		Remotes:FireAllClients("SparkMod.Stock.Rotated", poolId, poolState)
	end)

	Remotes:OnInvoke("SparkMod.Stock.GetState", function(player)
		return {
			items = stockItems,
			pools = pools,
		}
	end)
end

function Stock._Hydrate(syncData: { [string]: any })
	local cachedStock = syncData.stockEvents
	if cachedStock and typeof(cachedStock) == "table" then
		for eventId, status in cachedStock do
			if typeof(status) == "table" then
				local isInfinite = status.current == -1 or status.total == -1 or status.infinite == true
				local depleted = if isInfinite then false else (status.depleted or false)
				stockItems[eventId] = {
					eventId = eventId,
					rewardType = status.rewardType,
					rewardId = status.rewardId,
					current = status.current or 0,
					total = status.total or 0,
					depleted = depleted,
					depletedAt = if depleted then (status.depletedAt or os.time()) else nil,
					infinite = isInfinite,
					metadata = status.metadata,
					label = status.label,
					expiresAt = status.expiresAt,
				}
			end
		end
	end

	local cachedPools = syncData.pools
	if cachedPools and typeof(cachedPools) == "table" then
		for poolId, poolData in cachedPools do
			if typeof(poolData) == "table" then
				pools[poolId] = {
					poolId = poolData.poolId or poolId,
					slots = poolData.slots or 0,
					strategy = poolData.strategy or "",
					currentItems = poolData.currentItems or {},
					rotationNumber = poolData.rotationNumber or 0,
					nextRotationAt = poolData.nextRotationAt,
				}
			end
		end
	end

	loadAndRegister()

	Remotes:FireAllClients("SparkMod.Stock.Sync", {
		items = stockItems,
		pools = pools,
	})

	ready = true
	Stock.Ready:Fire()
end

return Stock
