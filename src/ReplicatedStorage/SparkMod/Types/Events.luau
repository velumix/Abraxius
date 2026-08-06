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

export type EventState = {
	eventName: string,
	status: string,
	endsAt: number,
	duration: number,
	paused: boolean,
	remainingAtPause: number?,
	config: { [string]: any }?,
	state: { [string]: any }?,
	triggeredBy: string?,
}

export type EventManifestEntry = {
	name: string,
	duration: number,
	override: string,
	builtIn: boolean?,
}

export type HandlerOptions = {
	builtIn: boolean?,
}

export type Context = {
	EventName: string,
	Duration: number,
	Remaining: number,
	Config: { [string]: any },
	State: { [string]: any },
	StartTime: number,
	Signal: (action: string, ...any) -> (),
}

export type Handler = {
	Duration: number?,
	Override: ("queue" | "stack" | "replace")?,

	Activate: ((context: Context) -> ())?,
	Deactivate: (() -> ())?,
	CanActivate: (() -> (boolean, string?))?,
	StateChanged: ((state: { [string]: any }, changedKeys: { string }) -> ())?,
}

return {}
