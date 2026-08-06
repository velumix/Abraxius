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

local EVENT_ID = "st_spam_item"
local USERID_BASE = 1_000_000_000_000

local function run(ctx)
	ctx.post("/game/stock/register", {
		items = {
			[EVENT_ID] = {
				rewardType = "item",
				rewardId = "st_spam_reward",
				publicStock = -1,
				hiddenStock = -1,
			},
		},
		pools = {},
	})

	local claims, granted, throttled = 0, 0, 0
	local started, lastLog = os.clock(), os.clock()

	while ctx.isActive() do
		local resp = ctx.post("/game/stock/claim", {
			eventId = EVENT_ID,
			userId = USERID_BASE + math.random(1, 1_000_000),
			serverId = "st_spam_srv",
		})
		
		claims += 1
		
		if resp.ok and resp.body and resp.body.ok == true then
			granted += 1
		elseif not resp.ok then
			throttled += 1
		end

		if os.clock() - lastLog >= 10 then
			local elapsed = math.max(0.001, os.clock() - started)
			print(
				`[SparkMod.StockClaimSpam] claims={claims} granted={granted} throttled={throttled} ~{math.floor(claims / elapsed)} claims/s (infinite item; granted should == claims)`
			)
			lastLog = os.clock()
		end
	end

	print(`[SparkMod.StockClaimSpam] stopped (claims={claims}, granted={granted}, throttled={throttled})`)
end

return {
	name = "stock-claim-spam",
	run = run,
}
