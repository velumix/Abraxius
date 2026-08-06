local KillEffectManager = {}

KillEffectManager.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(180, 180, 190) },
	{ name = "Uncommon", color = Color3.fromRGB(90, 200, 110) },
	{ name = "Rare", color = Color3.fromRGB(70, 130, 240) },
	{ name = "Epic", color = Color3.fromRGB(180, 90, 230) },
	{ name = "Legendary", color = Color3.fromRGB(255, 190, 60) },
	{ name = "Secret", color = Color3.fromRGB(0, 0, 0) },
}
KillEffectManager.RARITY_INFO = {}
KillEffectManager.RARITY_RANK = {}
for i, r in ipairs(KillEffectManager.RARITIES) do
	KillEffectManager.RARITY_INFO[r.name] = r
	KillEffectManager.RARITY_RANK[r.name] = i
end

function KillEffectManager.rarityRank(name)
	return KillEffectManager.RARITY_RANK[name] or 0
end

function KillEffectManager.rarityColor(name)
	local r = KillEffectManager.RARITY_INFO[name]
	return r and r.color or Color3.fromRGB(200, 200, 200)
end

KillEffectManager.EFFECTS = {
	{
		id = "confetti",
		name = "Confetti",
		rarity = "Common",
		effectType = "ragdoll",
		vfx = "Confetti",
		icon = "rbxassetid://74787570948015",
		soundId = "rbxassetid://81198639091746",
	},
	
	{
		id = "beam",
		name = "Beam",
		rarity = "Uncommon",
		effectType = "ragdoll",
		vfx = "Beam",
		icon = "rbxassetid://91619270628587",
		soundId = "rbxassetid://123004601809111",
	},
	
	{
		id = "frozen",
		name = "Frozen",
		rarity = "Rare",
		effectType = "freeze",
		vfx = "Frozen",
		icon = "rbxassetid://73192131479460",
		soundId = "rbxassetid://122367764452825",
	},
	
	{
		id = "balloons",
		name = "Balloons",
		rarity = "Epic",
		effectType = "ragdoll",
		vfx = "Balloons",
		icon = "rbxassetid://82000752882389",
		soundId = "rbxassetid://95379252747812",
	},
	
	{
		id = "electrocute",
		name = "Electrocute",
		rarity = "Legendary",
		effectType = "ragdoll",
		vfx = "Electrocute",
		icon = "rbxassetid://128234531687967",
		soundId = "rbxassetid://89792067279828",
	},
	
	{
		id = "targetbeam",
		name = "Target Beam",
		rarity = "Secret",
		effectType = "ragdoll",
		vfx = "TargetBeam",
		icon = "rbxassetid://113682034886612",
		soundId = "rbxassetid://112040959630782",
	},
	
	{
		id = "heartbeat",
		name = "Heartbeat",
		rarity = "Common",
		effectType = "ragdoll",
		vfx = "Heartbeat",
		icon = "rbxassetid://84142424718229",
	},
	
	{
		id = "hacked",
		name = "Hacked",
		rarity = "Uncommon",
		effectType = "ragdoll",
		vfx = "Hacked",
		icon = "rbxassetid://135834042953176",
		soundId = "rbxassetid://119892521653549",
	},
	
	{
		id = "petrified",
		name = "Petrified",
		rarity = "Rare",
		effectType = "freeze",
		vfx = "Petrified",
		icon = "rbxassetid://76310305308133",
		soundId = "rbxassetid://138665231635027",
	},
	
	{
		id = "cartoonbrawl",
		name = "Cartoon Brawl",
		rarity = "Epic",
		effectType = "ragdoll",
		vfx = "CartoonBrawl",
		icon = "rbxassetid://93863068514702",
		soundId = "rbxassetid://102735626751703",
	},
	
	{
		id = "ignited",
		name = "Ignited",
		rarity = "Legendary",
		effectType = "ragdoll",
		vfx = "Ignited",
		icon = "rbxassetid://77919450617167",
		soundId = "rbxassetid://113223859470506",
	},
	
	{
		id = "thunderstorm",
		name = "Thunderstorm",
		rarity = "Secret",
		effectType = "ragdoll",
		vfx = "Thunderstorm",
		icon = "rbxassetid://129884030274471",
		soundId = "rbxassetid://109289244301517",
	},

	{
		id = "glowingpulse",
		name = "Glowing Pulse",
		rarity = "Uncommon",
		effectType = "ragdoll",
		vfx = "GlowingPulse",
		icon = "rbxassetid://133445787249914",
		soundId = "rbxassetid://72990727999075",
	},
	{
		id = "firework",
		name = "Firework",
		rarity = "Legendary",
		effectType = "ragdoll",
		vfx = "Firework",
		icon = "rbxassetid://75718321531300",
		soundId = "rbxassetid://118567190406364",
	},
	{
		id = "sparklerexplosion",
		name = "Sparkler Explosion",
		rarity = "Legendary",
		effectType = "ragdoll",
		vfx = "SparklerExplosion",
		icon = "rbxassetid://77993971642744",
		soundId = "rbxassetid://80094287929095",
	},
	{
		id = "haunteddoor",
		name = "Haunted Door",
		rarity = "Legendary",
		effectType = "ragdoll",
		vfx = "HauntedDoor",
		custom = true,
		icon = "rbxassetid://87016401629143",
		soundId = "rbxassetid://99196274220598",
	},
	{
		id = "crushedbuilding",
		name = "Crushed Building",
		rarity = "Rare",
		effectType = "ragdoll",
		vfx = "CrushedBuilding",
		custom = true,
		icon = "rbxassetid://116051469247725",
		soundId = "rbxassetid://87483115147718",
	},
}

KillEffectManager.EFFECT_BY_ID = {}
for _, e in ipairs(KillEffectManager.EFFECTS) do
	KillEffectManager.EFFECT_BY_ID[e.id] = e
end

function KillEffectManager.getEffect(id)
	return KillEffectManager.EFFECT_BY_ID[id]
end

function KillEffectManager.effectName(id)
	local e = KillEffectManager.EFFECT_BY_ID[id]
	return e and e.name or tostring(id)
end

function KillEffectManager.effectType(id)
	local e = KillEffectManager.EFFECT_BY_ID[id]
	return e and e.effectType or "ragdoll"
end

function KillEffectManager.effectIcon(id)
	local e = KillEffectManager.EFFECT_BY_ID[id]
	return e and e.icon or nil
end

KillEffectManager.CRATES = {
	["Novice Crate"] = {
		"confetti",
		"beam",
		"frozen",
		"balloons",
		"electrocute",
		"targetbeam",
	},
	["Emotional Crate"] = {
		"heartbeat",
		"hacked",
		"petrified",
		"cartoonbrawl",
		"ignited",
		"thunderstorm",
	},
}
KillEffectManager.CRATE_PRICES = {
	["Novice Crate"] = 1500,
	["Emotional Crate"] = 3500,
}

function KillEffectManager.getCratePool(crateName)
	return KillEffectManager.CRATES[crateName]
end

function KillEffectManager.cratePrice(crateName)
	return KillEffectManager.CRATE_PRICES[crateName]
end

KillEffectManager.RARITY_ODDS = {
	Common = 45,
	Uncommon = 27,
	Rare = 15,
	Epic = 8,
	Legendary = 4,
	Secret = 1,
}
local SECRET_RARITY = "Secret"

local function groupByRarity(crateName)
	local pool = KillEffectManager.CRATES[crateName]
	if not pool then
		return nil
	end
	
	local byRarity = {}
	for _, id in ipairs(pool) do
		local def = KillEffectManager.EFFECT_BY_ID[id]
		local rar = def and def.rarity or "Common"
		byRarity[rar] = byRarity[rar] or {}
		table.insert(byRarity[rar], id)
	end
	return byRarity
end

local function effectiveRarityOdds(crateName)
	local byRarity = groupByRarity(crateName)
	if not byRarity then
		return {}
	end
	
	local secretPct = 0
	if byRarity[SECRET_RARITY] and #byRarity[SECRET_RARITY] > 0 then
		secretPct = KillEffectManager.RARITY_ODDS[SECRET_RARITY] or 0
	end
	
	local raw, total = {}, 0
	for rar, ids in pairs(byRarity) do
		if rar ~= SECRET_RARITY and #ids > 0 then
			local pct = KillEffectManager.RARITY_ODDS[rar] or 0
			if pct > 0 then
				raw[rar] = pct
				total += pct
			end
		end
	end
	
	local odds = {}
	if secretPct > 0 then
		odds[SECRET_RARITY] = secretPct
	end
	
	local remaining = 100 - secretPct
	if total > 0 then
		for rar, pct in pairs(raw) do
			odds[rar] = (pct / total) * remaining
		end
	elseif secretPct > 0 then
		odds[SECRET_RARITY] = 100
	end
	return odds
end

function KillEffectManager.getCrateOdds(crateName)
	local byRarity = groupByRarity(crateName)
	if not byRarity then
		return {}
	end
	
	local rarityPct = effectiveRarityOdds(crateName)
	local odds = {}
	for rar, ids in pairs(byRarity) do
		local tierPct = rarityPct[rar] or 0
		local perEffect = (#ids > 0) and (tierPct / #ids) or 0
		for _, id in ipairs(ids) do
			local def = KillEffectManager.EFFECT_BY_ID[id]
			odds[#odds + 1] = {
				id = id,
				name = def and def.name or id,
				rarity = def and def.rarity or "Common",
				icon = def and def.icon or nil,
				chance = perEffect / 100,
			}
		end
	end
	
	return odds
end

function KillEffectManager.rollEffect(crateName)
	local byRarity = groupByRarity(crateName)
	if not byRarity then
		return nil
	end
	
	local rarityPct = effectiveRarityOdds(crateName)
	local total = 0
	for _, pct in pairs(rarityPct) do
		total += pct
	end
	
	if total <= 0 then
		return nil
	end
	
	local r = math.random() * total
	local acc, chosen = 0, nil
	for rar, pct in pairs(rarityPct) do
		acc += pct
		if r <= acc then
			chosen = rar
			break
		end
	end
	
	if not chosen then
		for rar in pairs(rarityPct) do
			chosen = rar
			break
		end
	end
	
	local ids = byRarity[chosen]
	if not ids or #ids == 0 then
		return nil
	end
	
	return ids[math.random(1, #ids)]
end

-- ===== Studio asset audit =====
-- Warn (Studio only) about any kill effect whose VFX model isn't present yet, so "effect implemented
-- in config but its VFX isn't in place" shows up at boot. Mirrors KillEffectApplier's real resolution:
-- ReplicatedStorage.Assets.KIllEffects (note the capital-I spelling) with a KillEffects fallback,
-- matched by `vfx`, then `name`, then case-insensitively. Server-side only, never in live games.
-- Non-fatal: a missing VFX just means no on-death particles for that effect.
do
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() and RunService:IsServer() then
		task.defer(function()
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			local folder = assets and (assets:FindFirstChild("KIllEffects") or assets:FindFirstChild("KillEffects"))
			if not folder then
				warn("[KillEffectManager] audit: ReplicatedStorage.Assets.KIllEffects folder missing -- cannot verify kill-effect VFX")
				return
			end
			local function present(def)
				if folder:FindFirstChild(def.vfx or "") or folder:FindFirstChild(def.name or "") then return true end
				local want = string.lower(def.vfx or "")
				for _, c in ipairs(folder:GetChildren()) do
					if string.lower(c.Name) == want then return true end
				end
				return false
			end
			local missing = 0
			for _, def in ipairs(KillEffectManager.EFFECTS) do
				if not def.custom and not present(def) then
					missing += 1
					warn(string.format("[KillEffectManager] No template model found for kill effect '%s' (id=%s, vfx='%s')",
						tostring(def.name), tostring(def.id), tostring(def.vfx)))
				end
			end
		end)
	end
end

return KillEffectManager
