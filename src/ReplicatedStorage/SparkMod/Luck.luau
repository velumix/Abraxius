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
local Players = game:GetService("Players")

local Remotes = require(script.Parent.Internal.Remotes)
local Signal = require(script.Parent.Internal.Signal)
local LuckTypes = require(script.Parent.Types.Luck)

export type Stacking = LuckTypes.Stacking
export type ChannelConfig = LuckTypes.ChannelConfig
export type ChannelRef = LuckTypes.ChannelRef
export type Modifier = LuckTypes.Modifier

-- ========== State ========== --

local initialized = false
local synced = false
local effectiveCache: { [string]: number } = {}
local modifiersCache: { [string]: { [string]: LuckTypes.Modifier } } = {}
local channelsCache: { string }? = nil

-- ========== Module ========== --

local Luck = {}

Luck.Ready = Signal.new()
Luck.ChannelChanged = Signal.new() -- (channel: string, effective: number)
Luck.ModifierApplied = Signal.new() -- (modifier: Modifier)
Luck.ModifierRemoved = Signal.new() -- (channel: string, source: string)

-- ========== Queries ========== --

function Luck:GetEffective(channel: string): number
	return effectiveCache[channel] or 1
end

function Luck:GetEffectiveAsync(channel: string): number
	if not synced then Luck.Ready:Wait() end
	local cached = effectiveCache[channel]
	if cached ~= nil then return cached end

	local result = Remotes:InvokeServer("SparkMod.Luck.GetEffective", channel)
	if type(result) == "number" then
		effectiveCache[channel] = result
		return result
	end
	return 1
end

function Luck:GetModifiers(channel: string?): { LuckTypes.Modifier }
	local results: { LuckTypes.Modifier } = {}
	if channel then
		local bucket = modifiersCache[channel]
		if bucket then
			for _, mod in bucket do
				table.insert(results, mod)
			end
		end
	else
		for _, bucket in modifiersCache do
			for _, mod in bucket do
				table.insert(results, mod)
			end
		end
	end
	return results
end

function Luck:ListModifiersAsync(channel: string?): { LuckTypes.Modifier }
	if not synced then Luck.Ready:Wait() end

	local result = Remotes:InvokeServer("SparkMod.Luck.ListModifiers", channel)
	if type(result) ~= "table" then
		return {}
	end

	for _, modifier in result do
		modifiersCache[modifier.channel] = modifiersCache[modifier.channel] or {}
		modifiersCache[modifier.channel][modifier.source] = modifier
	end

	return Luck:GetModifiers(channel)
end

function Luck:GetChannels(): { string }
	return channelsCache or {}
end

function Luck:ListChannelsAsync(): { string }
	if channelsCache then return channelsCache end
	if not synced then Luck.Ready:Wait() end

	local result = Remotes:InvokeServer("SparkMod.Luck.ListChannels")
	if type(result) == "table" then
		channelsCache = result
		return result
	end
	return {}
end

-- ========== Initialization ========== --

function Luck:Init()
	if initialized then return end
	initialized = true

	Remotes:Init()

	if RunService:IsServer() then
		return
	end

	Remotes:OnClient("SparkMod.Luck.ChannelChanged", function(channel: string, effective: number)
		effectiveCache[channel] = effective
		Luck.ChannelChanged:Fire(channel, effective)
	end)

	Remotes:OnClient("SparkMod.Luck.ModifierApplied", function(modifier: LuckTypes.Modifier)
		modifiersCache[modifier.channel] = modifiersCache[modifier.channel] or {}
		modifiersCache[modifier.channel][modifier.source] = modifier
		Luck.ModifierApplied:Fire(modifier)
	end)

	Remotes:OnClient("SparkMod.Luck.ModifierRemoved", function(channel: string, source: string)
		local bucket = modifiersCache[channel]
		if bucket then
			bucket[source] = nil
		end
		Luck.ModifierRemoved:Fire(channel, source)
	end)

	if not synced then
		synced = true
		Luck.Ready:Fire()
	end
end

return Luck
