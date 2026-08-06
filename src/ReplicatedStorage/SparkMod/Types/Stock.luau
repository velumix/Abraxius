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

export type StockStatus = {
	current: number,
	total: number,
	depleted: boolean,
	infinite: boolean?,
}

export type StockItemState = {
	eventId: string,
	itemId: string?,
	rewardType: string?,
	rewardId: string?,
	current: number,
	total: number,
	depleted: boolean,
	infinite: boolean?,
	poolId: string?,
}

export type PoolState = {
	poolId: string,
	slots: number,
	strategy: string,
	currentItems: { { itemId: string, eventId: string, slotIndex: number, injected: boolean? } },
	rotationNumber: number,
	nextRotationAt: number?,
}

export type ClaimResult = {
	ok: boolean,
	claimNumber: number?,
	displayStock: number?,
	depleted: boolean?,
	error: string?,
}

export type StockHandler = {
	CanGrant: ((player: Player, rewardId: string) -> (boolean, string?))?,
	OnGranted: ((player: Player, rewardId: string, claimNumber: number) -> ())?,
	OnDepleted: ((eventId: string) -> ())?,
}

-- ========== Programmatic Operations ========== --

export type StockOverride = {
	publicStock: number?,
	hiddenStock: number?,
}

export type EntryOptions = {
	eventId: string,
	rewardType: string,
	rewardId: string,
	publicStock: number,
	hiddenStock: number,
	expiresAt: number?,
	holdReservations: boolean?,
	label: string?,
	metadata: { [string]: any }?,
}

export type InlineSlotOptions = {
	rewardType: string,
	rewardId: string,
	publicStock: number,
	hiddenStock: number,
	metadata: { [string]: any }?,
	label: string?,
	expiresAt: number?,
	itemIdHint: string?,
	holdReservations: boolean?,
}

export type PushOptions = {
	addPublic: number?,
	addHidden: number?,
	expiresAt: number?,
	note: string?,
}

export type DecrementOptions = {
	decreasePublic: number?,
	decreaseHidden: number?,
}

export type PushRecord = {
	id: string,
	stockEventId: string,
	eventId: string,
	addedPublic: number,
	addedHidden: number,
	expiresAt: string?,
	note: string?,
	createdBy: string,
	createdAt: string,
}

export type InjectOptions = {
	itemId: string,
	mode: ("current" | "next")?,
	weight: number?,
	stockOverride: StockOverride?,
	expiresAt: number?,
	note: string?,
	metadata: { [string]: any }?,
}

export type InjectionRecord = {
	id: string,
	poolId: string,
	itemId: string,
	rewardType: string,
	rewardId: string,
	weight: number,
	stockOverride: StockOverride?,
	mode: string,
	stockEventId: string?,
	expiresAt: string?,
	createdBy: string,
	createdAt: string,
	note: string?,
}

export type InjectResult = {
	injection: InjectionRecord,
	stockEvent: { [string]: any }?,
}

-- ========== Reservations ========== --

export type ReserveOptions = {
	ttlSeconds: number,
}

export type ReservationRecord = {
	id: string,
	expiresAt: number?,
	displayStock: number?,
	reused: boolean?,
	depleted: boolean?,
}

return {}
