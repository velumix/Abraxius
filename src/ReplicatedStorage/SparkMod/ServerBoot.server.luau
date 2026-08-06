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
local Remotes = require(script.Parent.Internal.Remotes)
local Events = require(script.Parent.Events)
local Stock = require(script.Parent.Stock)
local Pools = require(script.Parent.Pools)
local Luck = require(script.Parent.Luck)

Remotes:Init()
Events:Init()
Stock:Init()
Luck:Init()
