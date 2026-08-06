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

local EVENT_ID = "st_claim_item"
local WINDOW_SEC = 12
local USERID_BASE = 1_000_000_000_000

local function restock(ctx, publicStock: number, hidden: number)
	ctx.post("/game/stock/register", {
		items = {
			[EVENT_ID] = {
				rewardType = "item",
				rewardId = "st_claim_reward",
				publicStock = publicStock,
				hiddenStock = hidden,
			},
		},
		pools = {},
	})
end

local function run(ctx)
	local hidden = ctx.multiplier * 10
	local windows, claims, granted, rejected = 0, 0, 0, 0

	while ctx.isActive() do
		restock(ctx, windows + 1, hidden)
		windows += 1
		local grantedThisWindow = 0

		local windowStart = os.clock()
		while ctx.isActive() and (os.clock() - windowStart) < WINDOW_SEC do
			local resp = ctx.post("/game/stock/claim", {
				eventId = EVENT_ID,
				userId = USERID_BASE + math.random(1, 1_000_000),
				serverId = "st_claim_srv",
			})
			
			claims += 1
			
			if resp.ok and resp.body and resp.body.ok == true then
				granted += 1
				grantedThisWindow += 1
			else
				rejected += 1
			end
		end

		print(
			`[SparkMod.StockClaimFlood] window={windows} hidden={hidden} grantedThisWindow={grantedThisWindow} (MUST be <= hidden = no oversell) claims={claims} totalGranted={granted} rejected={rejected}`
		)
	end

	print(`[SparkMod.StockClaimFlood] stopped (windows={windows}, claims={claims}, granted={granted}, rejected={rejected})`)
end

return {
	name = "stock-claim-flood",
	run = run,
}
