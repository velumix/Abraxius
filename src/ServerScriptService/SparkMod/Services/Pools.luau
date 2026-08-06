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

local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)
local PoolTypes = require(game.ReplicatedStorage.SparkMod.Types.Pools)
local LuckTypes = require(game.ReplicatedStorage.SparkMod.Types.Luck)

-- ========== Constants ========== --

local WEIGHT_KEYS = { "weight", "Weight", "chance", "Chance", "w", "W" }
local VALUE_KEYS = { "value", "Value", "name", "Name", "id", "Id", "item", "Item" }
local ITEMS_KEYS = { "items", "Items" }

local WEIGHT_KEY_SET: { [string]: boolean } = {}
for _, k in WEIGHT_KEYS do
	WEIGHT_KEY_SET[k] = true
end

-- ========== Shape Helpers ========== --

local function extractWeight(entry: any): number?
	if type(entry) == "number" then
		return entry
	end
	if type(entry) ~= "table" then
		return nil
	end
	for _, key in WEIGHT_KEYS do
		local v = entry[key]
		if type(v) == "number" then
			return v
		end
	end
	return nil
end

local function extractValue(entry: any, fallback: any): any
	if type(entry) ~= "table" then
		return entry
	end
	for _, key in VALUE_KEYS do
		if entry[key] ~= nil then
			return entry[key]
		end
	end
	return fallback
end

local function isDictShape(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	local count = 0
	for _ in data do
		count += 1
	end
	if count == 0 then
		return false
	end
	for i = 1, count do
		if data[i] == nil then
			return true
		end
	end
	return false
end

local function findSubGroup(t: any): any?
	if type(t) ~= "table" then
		return nil
	end
	for _, key in ITEMS_KEYS do
		if type(t[key]) == "table" then
			return t[key]
		end
	end
	for k, v in t do
		if not WEIGHT_KEY_SET[k] and type(v) == "table" then
			return v
		end
	end
	return nil
end

local function looksLikeTiered(data: any): boolean
	if not isDictShape(data) then
		return false
	end
	for _, v in data do
		if type(v) ~= "table" then
			return false
		end
		if extractWeight(v) == nil then
			return false
		end
		if findSubGroup(v) == nil then
			return false
		end
	end
	return true
end

local function looksLikeNested(data: any): boolean
	if not looksLikeTiered(data) then
		return false
	end
	for _, v in data do
		local subPool = findSubGroup(v)
		if subPool and looksLikeTiered(subPool) then
			return true
		end
	end
	return false
end

local function inferStrategy(data: any): string
	if looksLikeNested(data) then
		return "Nested"
	end
	if looksLikeTiered(data) then
		return "Tiered"
	end
	return "Flat"
end

-- ========== Flat Strategy ========== --

type FlatEntry = { value: any, weight: number }
type FlatState = { strategy: string, entries: { FlatEntry } }

local FlatStrategy = {}

function FlatStrategy.build(data: any): FlatState
	if type(data) ~= "table" then
		error(`[SparkMod.Pools] Flat data must be a table, got {typeof(data)}`)
	end

	local entries: { FlatEntry } = {}

	if isDictShape(data) then
		for key, value in data do
			local w = extractWeight(value)
			if w == nil then
				w = if type(value) == "number" then value else 1
			end
			table.insert(entries, { value = extractValue(value, key), weight = w :: number })
		end
	else
		for _, entry in data do
			local w = extractWeight(entry) or 1
			table.insert(entries, { value = extractValue(entry, entry), weight = w })
		end
	end

	if #entries == 0 then
		error("[SparkMod.Pools] Flat pool has no entries")
	end

	return { strategy = "Flat", entries = entries }
end

function FlatStrategy.entries(state: FlatState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): { PoolTypes.PoolEntry }
	local weights: { number } = {}
	for i, e in state.entries do
		weights[i] = e.weight
	end

	if formula and effective then
		weights = formula(weights, effective, context)
	end

	local total = 0
	for _, w in weights do
		total += w
	end

	local result: { PoolTypes.PoolEntry } = {}
	for i, e in state.entries do
		local w = weights[i]
		table.insert(result, {
			value = e.value,
			weight = w,
			Chance = if total > 0 then (w / total) * 100 else 0,
		})
	end
	return result
end

function FlatStrategy.roll(state: FlatState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): PoolTypes.RollResult
	local entries = state.entries
	local weights: { number } = {}
	for i, e in entries do
		weights[i] = e.weight
	end

	if formula and effective then
		weights = formula(weights, effective, context)
	end

	local total = 0
	for _, w in weights do
		total += w
	end
	if total <= 0 then
		error("[SparkMod.Pools] Total weight is zero or negative after formula")
	end

	local roll = math.random() * total
	local cumulative = 0
	for i, w in weights do
		cumulative += w
		if roll <= cumulative then
			return {
				value = entries[i].value,
				weight = w,
				effectiveLuck = effective,
			}
		end
	end

	local lastIdx = #entries
	return {
		value = entries[lastIdx].value,
		weight = weights[lastIdx],
		effectiveLuck = effective,
	}
end

-- ========== Tiered Strategy ========== --

type TieredTier = { weight: number, inner: FlatState }
type TieredState = { strategy: string, tiers: { [string]: TieredTier }, tierNames: { string } }

local TieredStrategy = {}

function TieredStrategy.build(data: any): TieredState
	if not isDictShape(data) then
		error("[SparkMod.Pools] Tiered data must be a dictionary")
	end

	local tiers: { [string]: TieredTier } = {}
	local tierNames: { string } = {}

	for name, tierData in data do
		local w = extractWeight(tierData)
		if w == nil then
			error(`[SparkMod.Pools] Tier '{name}' missing weight`)
		end

		local subPool = findSubGroup(tierData)
		if not subPool then
			error(`[SparkMod.Pools] Tier '{name}' has no sub-pool`)
		end

		tiers[name] = { weight = w, inner = FlatStrategy.build(subPool) }
		table.insert(tierNames, name)
	end

	if #tierNames == 0 then
		error("[SparkMod.Pools] Tiered pool has no tiers")
	end

	return { strategy = "Tiered", tiers = tiers, tierNames = tierNames }
end

function TieredStrategy.entries(state: TieredState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): { PoolTypes.PoolEntry }
	local tiers = state.tiers
	local names = state.tierNames

	local tierWeights: { number } = {}
	for i, name in names do
		tierWeights[i] = tiers[name].weight
	end

	if formula and effective then
		tierWeights = formula(tierWeights, effective, context)
	end

	local tierTotal = 0
	for _, w in tierWeights do
		tierTotal += w
	end

	local result: { PoolTypes.PoolEntry } = {}
	for i, name in names do
		local tier = tiers[name]
		local tierChance = if tierTotal > 0 then tierWeights[i] / tierTotal else 0

		local innerTotal = 0
		for _, e in tier.inner.entries do
			innerTotal += e.weight
		end

		for _, e in tier.inner.entries do
			local itemChance = if innerTotal > 0 then e.weight / innerTotal else 0
			table.insert(result, {
				value = e.value,
				weight = tierWeights[i] * itemChance,
				Chance = tierChance * itemChance * 100,
				tier = name,
			})
		end
	end
	return result
end

function TieredStrategy.roll(state: TieredState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): PoolTypes.RollResult
	local tiers = state.tiers
	local names = state.tierNames

	local weights: { number } = {}
	for i, name in names do
		weights[i] = tiers[name].weight
	end

	if formula and effective then
		weights = formula(weights, effective, context)
	end

	local total = 0
	for _, w in weights do
		total += w
	end
	if total <= 0 then
		error("[SparkMod.Pools] Tiered total weight is zero or negative after formula")
	end

	local roll = math.random() * total
	local cumulative = 0
	local chosenIdx = #names
	for i, w in weights do
		cumulative += w
		if roll <= cumulative then
			chosenIdx = i
			break
		end
	end

	local chosenName = names[chosenIdx]
	local innerResult = FlatStrategy.roll(tiers[chosenName].inner, nil, nil, context)

	return {
		value = innerResult.value,
		tier = chosenName,
		weight = weights[chosenIdx],
		effectiveLuck = effective,
	}
end

-- ========== Nested Strategy ========== --

type NestedNode = {
	weight: number,
	leaf: FlatState?,
	children: { [string]: NestedNode }?,
	childNames: { string }?,
}

type NestedState = {
	strategy: string,
	children: { [string]: NestedNode },
	childNames: { string },
}

local NestedStrategy = {}

local function buildNestedNode(data: any, weight: number): NestedNode
	if isDictShape(data) and looksLikeTiered(data) then
		local children: { [string]: NestedNode } = {}
		local childNames: { string } = {}
		for name, sub in data do
			local subWeight = extractWeight(sub) :: number
			local subPool = findSubGroup(sub)
			children[name] = buildNestedNode(subPool, subWeight)
			table.insert(childNames, name)
		end
		return { weight = weight, children = children, childNames = childNames }
	end
	return { weight = weight, leaf = FlatStrategy.build(data) }
end

function NestedStrategy.build(data: any): NestedState
	if not isDictShape(data) then
		error("[SparkMod.Pools] Nested data must be a dictionary")
	end

	local children: { [string]: NestedNode } = {}
	local childNames: { string } = {}

	for name, sub in data do
		local w = extractWeight(sub)
		if w == nil then
			error(`[SparkMod.Pools] Nested group '{name}' missing weight`)
		end
		local subPool = findSubGroup(sub)
		if not subPool then
			error(`[SparkMod.Pools] Nested group '{name}' has no sub-pool`)
		end
		children[name] = buildNestedNode(subPool, w)
		table.insert(childNames, name)
	end

	if #childNames == 0 then
		error("[SparkMod.Pools] Nested pool has no groups")
	end

	return { strategy = "Nested", children = children, childNames = childNames }
end

local function pickWeightedIndex(weights: { number }): number
	local total = 0
	for _, w in weights do
		total += w
	end
	if total <= 0 then
		error("[SparkMod.Pools] Nested group has zero total weight after formula")
	end
	local roll = math.random() * total
	local cumulative = 0
	for i, w in weights do
		cumulative += w
		if roll <= cumulative then
			return i
		end
	end
	return #weights
end

function NestedStrategy.roll(state: NestedState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): PoolTypes.RollResult
	local path: { string } = {}
	local children = state.children
	local childNames = state.childNames
	local chosenWeight = 0

	while true do
		local weights: { number } = {}
		for i, name in childNames do
			weights[i] = children[name].weight
		end

		if formula and effective then
			weights = formula(weights, effective, context)
		end

		local chosenIdx = pickWeightedIndex(weights)
		local chosenName = childNames[chosenIdx]
		chosenWeight = weights[chosenIdx]
		table.insert(path, chosenName)

		local node = children[chosenName]
		if node.leaf then
			local innerResult = FlatStrategy.roll(node.leaf, nil, nil, context)
			return {
				value = innerResult.value,
				tier = path[1],
				path = path,
				weight = chosenWeight,
				effectiveLuck = effective,
			}
		end

		children = node.children :: any
		childNames = node.childNames :: any
	end
end

function NestedStrategy.entries(state: NestedState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): { PoolTypes.PoolEntry }
	local result: { PoolTypes.PoolEntry } = {}

	local function traverse(children: { [string]: NestedNode }, childNames: { string }, pathSoFar: { string }, chanceSoFar: number)
		local weights: { number } = {}
		for i, name in childNames do
			weights[i] = children[name].weight
		end
		if formula and effective then
			weights = formula(weights, effective, context)
		end
		local total = 0
		for _, w in weights do
			total += w
		end

		for i, name in childNames do
			local nodeChance = if total > 0 then weights[i] / total else 0
			local newPath = table.clone(pathSoFar)
			table.insert(newPath, name)

			local node = children[name]
			if node.leaf then
				local leaf = node.leaf :: FlatState
				local innerTotal = 0
				for _, e in leaf.entries do
					innerTotal += e.weight
				end
				for _, e in leaf.entries do
					local itemChance = if innerTotal > 0 then e.weight / innerTotal else 0
					table.insert(result, {
						value = e.value,
						weight = e.weight,
						Chance = chanceSoFar * nodeChance * itemChance * 100,
						tier = newPath[1],
						path = newPath,
					})
				end
			else
				traverse(node.children :: any, node.childNames :: any, newPath, chanceSoFar * nodeChance)
			end
		end
	end

	traverse(state.children, state.childNames, {}, 1)
	return result
end

-- ========== Pity Strategy ========== --

type PityState = {
	strategy: string,
	innerName: string,
	innerState: any,
	config: PoolTypes.PityConfig,
	missCounts: { [number]: number },
}

local PityStrategy = {}

function PityStrategy.build(data: any, config: PoolTypes.PoolConfig?): PityState
	local cfg = config or ({} :: PoolTypes.PoolConfig)
	if not cfg.pity then
		error("[SparkMod.Pools] Pity strategy requires config.pity")
	end

	local inferred = inferStrategy(data)
	local innerImpl = strategies[inferred]
	if not innerImpl then
		error(`[SparkMod.Pools] Pity's inferred inner strategy '{inferred}' is not built-in`)
	end

	return {
		strategy = "Pity",
		innerName = inferred,
		innerState = innerImpl.build(data),
		config = cfg.pity,
		missCounts = {},
	}
end

function PityStrategy.roll(state: PityState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): PoolTypes.RollResult
	local player = context.player
	local userId = if player then player.UserId else 0
	local count = state.missCounts[userId] or 0

	if count >= state.config.after then
		state.missCounts[userId] = 0
		return {
			value = state.config.pityItem(player, context),
			weight = 0,
			effectiveLuck = effective,
		}
	end

	local innerImpl = strategies[state.innerName]
	local result = innerImpl.roll(state.innerState, effective, formula, context)

	if state.config.guarantee(result) then
		state.missCounts[userId] = 0
	else
		state.missCounts[userId] = count + 1
	end

	return result
end

function PityStrategy.entries(state: PityState, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext): { PoolTypes.PoolEntry }
	local innerImpl = strategies[state.innerName]
	return innerImpl.entries(state.innerState, effective, formula, context)
end

-- ========== Strategy Registry ========== --

type StrategyImpl = {
	build: (data: any, config: PoolTypes.PoolConfig?) -> any,
	roll: (state: any, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext) -> PoolTypes.RollResult,
	entries: (state: any, effective: number?, formula: PoolTypes.FormulaFn?, context: PoolTypes.RollContext) -> { PoolTypes.PoolEntry },
}

strategies = {
	Flat = FlatStrategy :: any,
	Tiered = TieredStrategy :: any,
	Nested = NestedStrategy :: any,
	Pity = PityStrategy :: any,
}

local customStrategies: { [string]: StrategyImpl } = {}

local function resolveStrategy(name: string): StrategyImpl?
	return strategies[name] or customStrategies[name]
end

-- ========== Lazy Luck Access ========== --

local function getLuck(): any
	return require(script.Parent.Luck)
end

local function resolveFormula(f: any): PoolTypes.FormulaFn
	if type(f) == "function" then
		return f
	end
	if type(f) == "string" then
		return getLuck():GetFormula(f)
	end
	error(`[SparkMod.Pools] Invalid formula specification: {typeof(f)}`)
end

-- ========== Pool Object ========== --

local function createPoolObject(state: any, config: PoolTypes.PoolConfig): PoolTypes.PoolObject
	local strategyName: string = state.strategy
	local impl = resolveStrategy(strategyName)
	if not impl then
		error(`[SparkMod.Pools] Unknown strategy '{strategyName}'`)
	end

	local pool: any = {}
	pool.Rolled = Signal.new()

	local currentChannel: LuckTypes.ChannelRef? = config.channel

	function pool:Roll(player: Player?, context: PoolTypes.RollContext?): PoolTypes.RollResult
		local ctx: PoolTypes.RollContext = context or {}
		if player and not ctx.player then
			ctx.player = player
		end

		local effective: number? = nil
		local formulaFn: PoolTypes.FormulaFn? = nil

		if currentChannel then
			local Luck = getLuck()
			effective = Luck:GetEffective(player, currentChannel.Name)
			local formulaSpec = config.formula or "LinearMultiply"
			formulaFn = resolveFormula(formulaSpec)
		end

		local result = impl.roll(state, effective, formulaFn, ctx)
		pool.Rolled:FireAsync(player, result)
		return result
	end

	function pool:RollMany(n: number, player: Player?, context: PoolTypes.RollContext?): { PoolTypes.RollResult }
		local results = table.create(n)
		for i = 1, n do
			results[i] = pool:Roll(player, context)
		end
		return results
	end

	function pool:GetEntries(player: Player?, context: PoolTypes.RollContext?): { PoolTypes.PoolEntry }
		local ctx: PoolTypes.RollContext = context or {}
		if player and not ctx.player then
			ctx.player = player
		end

		local effective: number? = nil
		local formulaFn: PoolTypes.FormulaFn? = nil

		if currentChannel then
			local Luck = getLuck()
			effective = Luck:GetEffective(player, currentChannel.Name)
			local formulaSpec = config.formula or "LinearMultiply"
			formulaFn = resolveFormula(formulaSpec)
		end

		return impl.entries(state, effective, formulaFn, ctx)
	end

	function pool:GetChannel(): LuckTypes.ChannelRef?
		return currentChannel
	end

	function pool:SetChannel(ch: LuckTypes.ChannelRef?)
		currentChannel = ch
	end

	function pool:GetStrategy(): string
		return strategyName
	end

	function pool:Destroy()
		pool.Rolled:Destroy()
	end

	return pool :: PoolTypes.PoolObject
end

-- ========== Service Module ========== --

local Pools = {}

Pools.Ready = Signal.new()
Pools.StrategyRegistered = Signal.new()

function Pools:Register(data: any, config: PoolTypes.PoolConfig?): PoolTypes.PoolObject
	local cfg: PoolTypes.PoolConfig = config or {}

	local inferred = inferStrategy(data)
	local strategyName = cfg.strategy or inferred

	if cfg.strategy and cfg.strategy ~= inferred and cfg.strategy ~= "Pity" and not customStrategies[cfg.strategy] then
		warn(`[SparkMod.Pools] Explicit strategy '{cfg.strategy}' differs from inferred '{inferred}' — using explicit`)
	end

	local impl = resolveStrategy(strategyName)
	if not impl then
		error(`[SparkMod.Pools] Unknown strategy '{strategyName}'`)
	end

	local state = impl.build(data, cfg)

	return createPoolObject(state, cfg)
end

function Pools:RegisterStrategy(name: string, impl: StrategyImpl)
	if strategies[name] then
		error(`[SparkMod.Pools] Cannot overwrite built-in strategy '{name}'`)
	end
	customStrategies[name] = impl
	Pools.StrategyRegistered:Fire(name)
end

-- ========== Initialization ========== --

function Pools._Init()
	-- No coordinator wiring; pools are pure in-memory server-side state
end

function Pools._Hydrate(_syncData: { [string]: any })
	Pools.Ready:Fire()
end

return Pools
