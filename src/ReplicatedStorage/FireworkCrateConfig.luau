local FireworkCrateConfig = {}

FireworkCrateConfig.COST = 75                 -- Fireworks per roll
FireworkCrateConfig.DUPLICATE_REFUND_PCT = 0.15 -- refund on owned-once duplicates (kill effect / title)

FireworkCrateConfig.ITEMS = {
	{ itemType = "coins",      amount = 200,             rarity = "Rare",      chance = 30.9, name = "$200 Coins" },
	{ itemType = "knife",      id = "battlebanner",      rarity = "Epic",      chance = 29,   name = "Battle Banner" },
	{ itemType = "title",      id = "patriot",           rarity = "Legendary", chance = 20,   name = "Patriot" },
	{ itemType = "killeffect", id = "sparklerexplosion", rarity = "Legendary", chance = 20,   name = "Sparkler Explosion" },
	{ itemType = "knife",      id = "patrioticphantom",  rarity = "Secret",    chance = 0.1,  name = "Patriotic Phantom" },
}

function FireworkCrateConfig.roll()
	local total = 0
	for _, it in ipairs(FireworkCrateConfig.ITEMS) do total += it.chance end
	if total <= 0 then return FireworkCrateConfig.ITEMS[1] end

	local r = math.random() * total
	local acc = 0
	for _, it in ipairs(FireworkCrateConfig.ITEMS) do
		acc += it.chance
		if r <= acc then return it end
	end
	return FireworkCrateConfig.ITEMS[#FireworkCrateConfig.ITEMS]
end

-- ===== Studio config audit =====
-- Warn (Studio only) if a crate item references an id that isn't registered in its manager, and if the
-- item chances don't sum to 100. Catches typo'd/unregistered ids and mis-tuned odds at boot. Server-side
-- only, never in live games. ("coins" items carry no id, so they're always considered valid.)
do
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() and RunService:IsServer() then
		task.defer(function()
			local RS = game:GetService("ReplicatedStorage")
			local function tryReq(name)
				local ok, m = pcall(function() return require(RS:WaitForChild(name, 10)) end)
				return ok and m or nil
			end
			local Knives, Effects, Titles = tryReq("KnifeSkinManager"), tryReq("KillEffectManager"), tryReq("TitleManager")
			local function resolves(itemType, id)
				if itemType == "coins" then return true
				elseif itemType == "knife" then return Knives ~= nil and Knives.getSkin(id) ~= nil
				elseif itemType == "killeffect" then return Effects ~= nil and Effects.getEffect(id) ~= nil
				elseif itemType == "title" then return Titles ~= nil and Titles.getTitle(id) ~= nil
				end
				return false
			end
			local total = 0
			for _, it in ipairs(FireworkCrateConfig.ITEMS) do
				total += it.chance or 0
				if not resolves(it.itemType, it.id) then
					warn(string.format("[FireworkCrateConfig] Crate item '%s' (type '%s', id '%s') does not resolve to a registered item",
						tostring(it.name), tostring(it.itemType), tostring(it.id)))
				end
			end
			if math.abs(total - 100) > 0.001 then
				warn(string.format("[FireworkCrateConfig] audit: item chances sum to %.3f, expected 100", total))
			end
		end)
	end
end

return FireworkCrateConfig
