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
local LuckTypes = require(script.Parent.Luck)

export type Strategy = "Flat" | "Tiered" | "Nested" | "Pity" | string

export type FormulaName =
	"LinearMultiply"
	| "AdditivePerTier"
	| "ExponentialRareBoost"
	| "ChanceShift"
	| string

export type RollContext = {
	player: Player?,
	tags: { string }?,
	excludeTags: { string }?,
	seed: number?,
	extra: { [string]: any }?,
}

export type RollResult = {
	value: any,
	tier: string?,
	path: { string }?,
	effectiveLuck: number?,
	weight: number,
}

export type PoolEntry = {
	value: any,
	weight: number,
	Chance: number,
	tier: string?,
	path: { string }?,
}

export type FormulaFn = (
	weights: { [any]: number },
	effective: number,
	context: RollContext
) -> { [any]: number }

export type PityConfig = {
	guarantee: (result: RollResult) -> boolean,
	after: number,
	pityItem: (player: Player?, context: RollContext) -> any,
}

export type PoolConfig = {
	strategy: Strategy?,
	channel: LuckTypes.ChannelRef?,
	formula: (FormulaName | FormulaFn)?,
	pity: PityConfig?,
	tags: { string }?,
}

export type PoolObject = {
	Rolled: Signal.Type,
	Roll: (self: PoolObject, player: Player?, context: RollContext?) -> RollResult,
	RollMany: (self: PoolObject, n: number, player: Player?, context: RollContext?) -> { RollResult },
	GetEntries: (self: PoolObject, player: Player?, context: RollContext?) -> { PoolEntry },
	GetChannel: (self: PoolObject) -> LuckTypes.ChannelRef?,
	SetChannel: (self: PoolObject, channel: LuckTypes.ChannelRef?) -> (),
	GetStrategy: (self: PoolObject) -> Strategy,
	Destroy: (self: PoolObject) -> (),
}

export type StrategyImpl = {
	detect: (data: any) -> boolean,
	build: (data: any, config: PoolConfig) -> any,
	roll: (state: any, effective: number, context: RollContext) -> RollResult,
}

return {}
