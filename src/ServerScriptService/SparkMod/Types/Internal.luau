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

export type CoordinatorMessage = {
	v: number,
	t: string,
	a: string,
	d: { [string]: any },
}

export type MessageHandler = (action: string, data: { [string]: any }) -> ()

export type CacheEntry<T> = {
	value: T,
	expiresAt: number,
	setAt: number,
}

export type QueuedRequest = {
	id: string,
	options: any,
	resolve: (any) -> (),
	reject: (string) -> (),
	priority: number,
	createdAt: number,
	dedupKey: string?,
}

export type HeartbeatPayload = {
	jobId: string,
	placeId: number,
	playerCount: number,
	maxPlayers: number,
	version: string?,
}

export type HeartbeatResponse = {
	ok: boolean,
	serverTime: number,
	pendingCommands: { PendingCommand },
}

export type PendingCommand = {
	type: string,
	data: { [string]: any },
}

export type SyncResponse = {
	events: { [string]: any },
	stockEvents: { [string]: any },
	pools: { [string]: any }?,
	polls: { [string]: any }?,
}

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

return {}
