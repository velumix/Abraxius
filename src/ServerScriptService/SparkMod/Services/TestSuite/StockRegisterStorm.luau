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

local ITEM_COUNT = 3
local WINDOW_SEC = 5

local function makeConfig(window: number)
	local items = {}
	for i = 0, ITEM_COUNT - 1 do
		items[`st_stock_{i}`] = {
			rewardType = "item",
			rewardId = `st_reward_{i}`,
			publicStock = window,
			hiddenStock = 100,
		}
	end
	
	return { items = items, pools = {} }
end

local function run(ctx)
	local N = ctx.multiplier
	local rounds, sent, changed, throttled = 0, 0, 0, 0

	while ctx.isActive() do
		local window = math.floor(os.time() / WINDOW_SEC)
		local config = makeConfig(window)

		for _ = 1, N do
			if not ctx.isActive() then break end
			local resp = ctx.post("/game/stock/register", config)
			sent += 1
			if not resp.ok then
				throttled += 1
			elseif resp.body and resp.body.changed == true then
				changed += 1
			end
		end
		rounds += 1

		if rounds % 4 == 0 then
			print(
				`[SparkMod.StockRegisterStorm] rounds={rounds} sent={sent} wrote={changed} throttled={throttled} (wrote should track ~1 per window, NOT per report)`
			)
		end

		task.wait(WINDOW_SEC)
	end

	print(`[SparkMod.StockRegisterStorm] stopped (rounds={rounds}, sent={sent}, wrote={changed}, throttled={throttled})`)
end

return {
	name = "stock-register-storm",
	run = run,
}
