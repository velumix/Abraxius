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

local PoolTypes = require(script.Parent.Types.Pools)

export type PoolObject = PoolTypes.PoolObject
export type PoolConfig = PoolTypes.PoolConfig
export type RollContext = PoolTypes.RollContext
export type RollResult = PoolTypes.RollResult
export type Strategy = PoolTypes.Strategy
export type FormulaFn = PoolTypes.FormulaFn
export type FormulaName = PoolTypes.FormulaName
export type PityConfig = PoolTypes.PityConfig
export type StrategyImpl = PoolTypes.StrategyImpl

local Pools = {}

return Pools
