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

local ACTION_NAME = "st_action"
local WINDOW_SEC = 6

local function run(ctx)
	local jobBase = if game.JobId ~= "" then string.sub(game.JobId, 1, 12) else "studio"
	local windows, broadcasts, claims, granted, overLimit = 0, 0, 0, 0, 0

	while ctx.isActive() do
		local serverLimit = ctx.multiplier * 2
		local claimers = ctx.multiplier * 5 -- more claimers than slots

		local bresp = ctx.post("/game/actions/broadcast", {
			actionName = ACTION_NAME,
			params = {},
			serverLimit = serverLimit,
			sourceJobId = `st_{jobBase}`,
		})
		broadcasts += 1
		local broadcastId = if bresp.ok and bresp.body then bresp.body.broadcastId else nil

		if broadcastId then
			local grantedThisBcast = 0
			for i = 1, claimers do
				if not ctx.isActive() then break end
				local cresp = ctx.post("/game/actions/claim", {
					broadcastId = broadcastId,
					jobId = `st_{jobBase}_{i}`,
				})
				claims += 1
				if cresp.ok and cresp.body and cresp.body.granted == true then
					granted += 1
					grantedThisBcast += 1
				end
			end
			if grantedThisBcast > serverLimit then
				overLimit += 1
			end
			print(
				`[SparkMod.ActionBroadcastStorm] window={windows} serverLimit={serverLimit} claimers={claimers} grantedThisBcast={grantedThisBcast} (MUST be <= serverLimit) overLimitEvents={overLimit}`
			)
		end

		windows += 1
		task.wait(WINDOW_SEC)
	end

	print(
		`[SparkMod.ActionBroadcastStorm] stopped (windows={windows}, broadcasts={broadcasts}, claims={claims}, granted={granted}, overLimitEvents={overLimit})`
	)
end

return {
	name = "action-broadcast-storm",
	run = run,
}
