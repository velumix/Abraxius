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

local Players = game:GetService("Players")

local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)
local Remotes = require(game.ReplicatedStorage.SparkMod.Internal.Remotes)
local LuckTypes = require(game.ReplicatedStorage.SparkMod.Types.Luck)
local PoolTypes = require(game.ReplicatedStorage.SparkMod.Types.Pools)
local EventTypes = require(game.ReplicatedStorage.SparkMod.Types.Events)
local Events = require(script.Parent.Events)

-- ========== Constants ========== --

local SERVER_KEY = 0
local DEFAULT_STACKING: LuckTypes.Stacking = "max"
local DEFAULT_BASELINE = 1

local BUILT_IN_FORMULA_NAMES: { [string]: boolean } = {
	LinearMultiply = true,
	AdditivePerTier = true,
	ExponentialRareBoost = true,
	ChanceShift = true,
}

-- ========== State ========== --

local initialized = false
local ready = false

type ChannelEntry = { config: LuckTypes.ChannelConfig, ref: LuckTypes.ChannelRef }

local channels: { [string]: ChannelEntry } = {}
local playerMods: { [number]: { [string]: { [string]: LuckTypes.Modifier } } } = {}
local formulas: { [string]: PoolTypes.FormulaFn } = {}
local activeLuckChannels: { string } = {}

-- ========== Module ========== --

local Luck = {}

Luck.Ready = Signal.new()
Luck.ChannelChanged = Signal.new() -- (player: Player?, channel: string, effective: number)
Luck.ModifierApplied = Signal.new() -- (player: Player?, modifier: Modifier)
Luck.ModifierRemoved = Signal.new() -- (player: Player?, channel: string, source: string)

-- ========== Built-in Formulas ========== --

local function LinearMultiply(
	weights: { [any]: number },
	effective: number,
	_context: PoolTypes.RollContext
): { [any]: number }
	local maxW = 0
	for _, w in weights do
		if w > maxW then maxW = w end
	end
	if maxW <= 0 then return weights end

	local result: { [any]: number } = {}
	for k, w in weights do
		local rarity = 1 - (w / maxW)
		result[k] = w * (1 + (effective - 1) * rarity)
	end
	return result
end

local function AdditivePerTier(
	weights: { [any]: number },
	effective: number,
	_context: PoolTypes.RollContext
): { [any]: number }
	local maxW = 0
	local total = 0
	local count = 0
	for _, w in weights do
		if w > maxW then maxW = w end
		total += w
		count += 1
	end
	if maxW <= 0 or count == 0 then return weights end

	local avg = total / count
	local result: { [any]: number } = {}
	for k, w in weights do
		local rarity = 1 - (w / maxW)
		local bonus = (effective - 1) * avg * rarity
		result[k] = w + bonus
	end
	return result
end

local function ExponentialRareBoost(
	weights: { [any]: number },
	effective: number,
	_context: PoolTypes.RollContext
): { [any]: number }
	local maxW = 0
	for _, w in weights do
		if w > maxW then maxW = w end
	end
	if maxW <= 0 then return weights end

	local exponent = effective - 1
	local result: { [any]: number } = {}
	for k, w in weights do
		local rarity = 1 - (w / maxW)
		result[k] = w * (2 ^ (exponent * rarity))
	end
	return result
end

local function ChanceShift(
	weights: { [any]: number },
	effective: number,
	_context: PoolTypes.RollContext
): { [any]: number }
	local maxW = 0
	for _, w in weights do
		if w > maxW then maxW = w end
	end
	if maxW <= 0 then return weights end

	local shift = effective - 1
	local result: { [any]: number } = {}
	for k, w in weights do
		local rarity = 1 - (w / maxW)
		result[k] = w + shift * w * rarity
	end
	return result
end

formulas.LinearMultiply = LinearMultiply
formulas.AdditivePerTier = AdditivePerTier
formulas.ExponentialRareBoost = ExponentialRareBoost
formulas.ChanceShift = ChanceShift

-- ========== Stacking ========== --

local function applyStacking(stacking: LuckTypes.Stacking, amounts: { number }, baseline: number): number
	if stacking == "max" then
		local m = baseline
		for _, v in amounts do
			if v > m then m = v end
		end
		return m
	elseif stacking == "sum" then
		local s = baseline
		for _, v in amounts do
			s += (v - baseline)
		end
		return s
	elseif stacking == "multiply" then
		local p = baseline
		for _, v in amounts do
			p *= v
		end
		return p
	end
	return baseline
end

-- ========== Helpers ========== --

local modTimers: { [any]: thread } = {}

local function getUserId(player: Player?): number
	return if player then player.UserId else SERVER_KEY
end

local function userIdToPlayer(userId: number): Player?
	if userId == SERVER_KEY then return nil end
	return Players:GetPlayerByUserId(userId)
end

local function getBucket(userId: number, channel: string): { [string]: LuckTypes.Modifier }
	if not playerMods[userId] then playerMods[userId] = {} end
	if not playerMods[userId][channel] then playerMods[userId][channel] = {} end
	return playerMods[userId][channel]
end

local function cleanExpired(bucket: { [string]: LuckTypes.Modifier })
	local now = os.time()
	for source, mod in bucket do
		if mod.expiresAt and mod.expiresAt <= now then
			bucket[source] = nil
		end
	end
end

local function fireChannelChanged(player: Player?, channel: string)
	local effective = Luck:GetEffective(player, channel)
	Luck.ChannelChanged:FireAsync(player, channel, effective)
end

local function cancelExpiry(mod: LuckTypes.Modifier)
	local thread = modTimers[mod]
	if thread then
		modTimers[mod] = nil
		pcall(task.cancel, thread)
	end
end

local reevaluateBucket

local function scheduleExpiry(userId: number, channel: string, mod: LuckTypes.Modifier, duration: number)
	cancelExpiry(mod)
	modTimers[mod] = task.delay(duration, function()
		modTimers[mod] = nil
		local bucket = playerMods[userId] and playerMods[userId][channel]
		if not bucket or bucket[mod.source] ~= mod then return end
		if mod.pausedAt then return end
		bucket[mod.source] = nil
		local player = userIdToPlayer(userId)
		Luck.ModifierRemoved:FireAsync(player, channel, mod.source)
		reevaluateBucket(userId, channel)
		fireChannelChanged(player, channel)
	end)
end

function reevaluateBucket(userId: number, channel: string)
	local bucket = playerMods[userId] and playerMods[userId][channel]
	if not bucket then return end

	local trueMax = 0
	for _, mod in bucket do
		if mod.amount > trueMax then trueMax = mod.amount end
	end

	local now = os.time()
	local player = userIdToPlayer(userId)

	for _, mod in bucket do
		local shouldPause = (mod.amount < trueMax) and (mod.pausable ~= false)

		if shouldPause and not mod.pausedAt then
			mod.remainingAtPause = if mod.expiresAt then math.max(0, mod.expiresAt - now) else nil
			mod.pausedAt = now
			mod.expiresAt = nil
			cancelExpiry(mod)
			Luck.ModifierApplied:FireAsync(player, mod)
		elseif not shouldPause and mod.pausedAt then
			local remaining = mod.remainingAtPause
			mod.pausedAt = nil
			mod.remainingAtPause = nil
			if remaining then
				mod.expiresAt = now + remaining
				scheduleExpiry(userId, channel, mod, remaining)
			end
			Luck.ModifierApplied:FireAsync(player, mod)
		end
	end
end

-- ========== Public API ========== --

function Luck:RegisterChannel(name: string, config: LuckTypes.ChannelConfig?): LuckTypes.ChannelRef
	local existing = channels[name]
	if existing then
		return existing.ref
	end

	local cfg: LuckTypes.ChannelConfig = {
		stacking = if config and config.stacking then config.stacking else DEFAULT_STACKING,
		default = if config and config.default then config.default else DEFAULT_BASELINE,
	}

	local ref: LuckTypes.ChannelRef = { Name = name }
	channels[name] = { config = cfg, ref = ref }
	return ref
end

function Luck:GetChannel(name: string): LuckTypes.ChannelRef?
	local entry = channels[name]
	return if entry then entry.ref else nil
end

function Luck:GetChannels(): { string }
	local names: { string } = {}
	for name in channels do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Luck:Apply(player: Player?, channel: string, source: string, amount: number, duration: number?, pausable: boolean?): LuckTypes.Modifier
	if not channels[channel] then
		error(`[SparkMod.Luck] Channel '{channel}' not registered`)
	end

	local userId = getUserId(player)
	local bucket = getBucket(userId, channel)

	local existing = bucket[source]
	if existing then
		cancelExpiry(existing)
	end

	local now = os.time()
	local mod: LuckTypes.Modifier = {
		channel = channel,
		source = source,
		amount = amount,
		startedAt = now,
		expiresAt = if duration then now + duration else nil,
		pausable = pausable,
	}

	bucket[source] = mod

	if duration then
		scheduleExpiry(userId, channel, mod, duration)
	end

	Luck.ModifierApplied:FireAsync(player, mod)
	reevaluateBucket(userId, channel)
	fireChannelChanged(player, channel)
	return mod
end

function Luck:Remove(player: Player?, channel: string, source: string)
	local userId = getUserId(player)
	local byChannel = playerMods[userId]
	if not byChannel then return end
	local bucket = byChannel[channel]
	if not bucket then return end
	local mod = bucket[source]
	if mod then
		cancelExpiry(mod)
		bucket[source] = nil
		Luck.ModifierRemoved:FireAsync(player, channel, source)
		reevaluateBucket(userId, channel)
		fireChannelChanged(player, channel)
	end
end

function Luck:GetEffective(player: Player?, channel: string): number
	local entry = channels[channel]
	if not entry then
		error(`[SparkMod.Luck] Channel '{channel}' not registered`)
	end

	local baseline = entry.config.default or DEFAULT_BASELINE
	local stacking = entry.config.stacking or DEFAULT_STACKING

	local amounts: { number } = {}

	local serverBucket = if playerMods[SERVER_KEY] then playerMods[SERVER_KEY][channel] else nil
	if serverBucket then
		cleanExpired(serverBucket)
		for _, mod in serverBucket do
			if not mod.pausedAt then
				table.insert(amounts, mod.amount)
			end
		end
	end

	local userId = getUserId(player)
	if userId ~= SERVER_KEY then
		local byChannel = playerMods[userId]
		local playerBucket = if byChannel then byChannel[channel] else nil
		if playerBucket then
			cleanExpired(playerBucket)
			for _, mod in playerBucket do
				if not mod.pausedAt then
					table.insert(amounts, mod.amount)
				end
			end
		end
	end

	return applyStacking(stacking, amounts, baseline)
end

function Luck:ListModifiers(player: Player?, channel: string?): { LuckTypes.Modifier }
	local userId = getUserId(player)
	local results: { LuckTypes.Modifier } = {}

	local byChannel = playerMods[userId]
	if not byChannel then return results end

	if channel then
		local bucket = byChannel[channel]
		if bucket then
			cleanExpired(bucket)
			for _, mod in bucket do
				table.insert(results, mod)
			end
		end
	else
		for _, bucket in byChannel do
			cleanExpired(bucket)
			for _, mod in bucket do
				table.insert(results, mod)
			end
		end
	end

	return results
end

function Luck:RegisterFormula(name: string, impl: PoolTypes.FormulaFn)
	if BUILT_IN_FORMULA_NAMES[name] then
		error(`[SparkMod.Luck] Cannot overwrite built-in formula '{name}'`)
	end
	formulas[name] = impl
end

function Luck:GetFormula(name: string): PoolTypes.FormulaFn
	local f = formulas[name]
	if not f then
		error(`[SparkMod.Luck] Formula '{name}' not registered`)
	end
	return f
end

-- ========== Async Queries ==========

function Luck:GetEffectiveAsync(player: Player?, channel: string): number
	if not ready then Luck.Ready:Wait() end
	return Luck:GetEffective(player, channel)
end

function Luck:GetChannelAsync(name: string): LuckTypes.ChannelRef?
	if not ready then Luck.Ready:Wait() end
	return Luck:GetChannel(name)
end

function Luck:ListModifiersAsync(player: Player?, channel: string?): { LuckTypes.Modifier }
	if not ready then Luck.Ready:Wait() end
	return Luck:ListModifiers(player, channel)
end

-- ========== Initialization ========== --

local defaultLuckHandler: EventTypes.Handler = {
	Duration = 60,
	Override = "replace",

	Activate = function(context: EventTypes.Context)
		local cfg = context.Config or {}
		local rawMult = cfg.multiplier
		local multiplier: number = if type(rawMult) == "number" then rawMult else 2

		local rawChannels = cfg.channels
		local toApply: { [string]: number } = {}
		if type(rawChannels) == "table" then
			for k, v in rawChannels :: { [any]: any } do
				if type(k) == "number" and type(v) == "string" then
					toApply[v] = if toApply[v] ~= nil then toApply[v] else multiplier
				elseif type(k) == "string" and type(v) == "number" then
					toApply[k] = v
				end
			end
		else
			toApply = { main = multiplier }
		end

		activeLuckChannels = {}
		for channelName, amount in toApply do
			if channels[channelName] then
				Luck:Apply(nil, channelName, "event:Luck", amount, context.Remaining, true)
				table.insert(activeLuckChannels, channelName)
			else
				warn(`[SparkMod.Luck] Channel '{channelName}' not registered — skipping Luck event application`)
			end
		end
	end,

	Deactivate = function()
		for _, channelName in activeLuckChannels do
			Luck:Remove(nil, channelName, "event:Luck")
		end
		activeLuckChannels = {}
	end,
}

function Luck._Init()
	if initialized then return end
	initialized = true

	Remotes:Init()

	Luck:RegisterChannel("main")

	Events:Register("Luck", defaultLuckHandler, { builtIn = true })

	Luck.ChannelChanged:Connect(function(player: Player?, channel: string, effective: number)
		if player then
			Remotes:FireClient(player, "SparkMod.Luck.ChannelChanged", channel, effective)
		else
			Remotes:FireAllClients("SparkMod.Luck.ChannelChanged", channel, effective)
		end
	end)

	Luck.ModifierApplied:Connect(function(player: Player?, modifier: LuckTypes.Modifier)
		if player then
			Remotes:FireClient(player, "SparkMod.Luck.ModifierApplied", modifier)
		else
			Remotes:FireAllClients("SparkMod.Luck.ModifierApplied", modifier)
		end
	end)

	Luck.ModifierRemoved:Connect(function(player: Player?, channel: string, source: string)
		if player then
			Remotes:FireClient(player, "SparkMod.Luck.ModifierRemoved", channel, source)
		else
			Remotes:FireAllClients("SparkMod.Luck.ModifierRemoved", channel, source)
		end
	end)

	Remotes:OnInvoke("SparkMod.Luck.GetEffective", function(player: Player, channel: string): number
		return Luck:GetEffective(player, channel)
	end)

	Remotes:OnInvoke("SparkMod.Luck.ListModifiers", function(player: Player, channel: string?): { LuckTypes.Modifier }
		local combined: { LuckTypes.Modifier } = {}
		for _, mod in Luck:ListModifiers(nil, channel) do
			table.insert(combined, mod)
		end
		for _, mod in Luck:ListModifiers(player, channel) do
			table.insert(combined, mod)
		end
		return combined
	end)

	Remotes:OnInvoke("SparkMod.Luck.ListChannels", function(_player: Player): { string }
		return Luck:GetChannels()
	end)
end

function Luck._Hydrate(_syncData: { [string]: any })
	ready = true
	Luck.Ready:Fire()
end

return Luck
