-- KnifeSkinManager: the single source of truth for knife skins, rarities, crate pools,
-- and the VFX-effect pool. Edit this when real skins are added.
-- Skin TEMPLATES live in ReplicatedStorage.KnifeSkins (one model per skin, matched by name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnifeSkinManager = {}

-- ===== Rarities =====
-- order matters (low -> high). color = frame color in UI. sellValue = flat coins when sold.
-- "Exclusive" is the TOP tier (above Secret): it is NOT obtainable from crates or the Level Up
-- Reward -- these knives are granted only through specific gamepasses / special methods. It is
-- deliberately left OUT of RARITY_ODDS and LEVELUP_RARITY_ODDS (so it has 0 roll weight everywhere),
-- and Exclusive knives are marked CRATE_INELIGIBLE, so they can never drop. Color is turquoise.
KnifeSkinManager.RARITIES = {
	{ name = "Common",    color = Color3.fromRGB(180, 180, 190), sellValue = 50 },
	{ name = "Uncommon",  color = Color3.fromRGB(90, 200, 110),  sellValue = 150 },
	{ name = "Rare",      color = Color3.fromRGB(70, 130, 240),  sellValue = 400 },
	{ name = "Epic",      color = Color3.fromRGB(180, 90, 230),  sellValue = 1000 },
	{ name = "Legendary", color = Color3.fromRGB(255, 190, 60),  sellValue = 3000 },
	{ name = "Secret",    color = Color3.fromRGB(0, 0, 0),        sellValue = 10000 },
	{ name = "Exclusive", color = Color3.fromRGB(64, 224, 208),   sellValue = 25000 },  -- turquoise; gamepass/special-only, never in crates
}

-- quick lookup: rarity name -> {color, sellValue}
KnifeSkinManager.RARITY_INFO = {}
-- rarity name -> its tier rank (1 = lowest). Order is defined by the RARITIES array above, so
-- adding a tier ABOVE Legendary later automatically gives it a higher rank with no other changes.
KnifeSkinManager.RARITY_RANK = {}
for i, r in ipairs(KnifeSkinManager.RARITIES) do
	KnifeSkinManager.RARITY_INFO[r.name] = r
	KnifeSkinManager.RARITY_RANK[r.name] = i
end

-- tier rank for a rarity name (1 = Common ... highest = top tier). 0 if unknown.
function KnifeSkinManager.rarityRank(name)
	return KnifeSkinManager.RARITY_RANK[name] or 0
end

function KnifeSkinManager.rarityColor(name)
	local r = KnifeSkinManager.RARITY_INFO[name]
	return r and r.color or Color3.fromRGB(200, 200, 200)
end

function KnifeSkinManager.sellValue(rarityName)
	local r = KnifeSkinManager.RARITY_INFO[rarityName]
	return r and r.sellValue or 0
end

-- ===== Skins =====
-- Every skin: id (stable key for saving), display name, rarity, and the template name in
-- ReplicatedStorage.KnifeSkins. Icons are added per skin later (icon = "rbxassetid://...").
KnifeSkinManager.SKINS = {
	-- ===== Common (basic / junk materials) =====
	{ id = "wooden",    name = "Wooden Knife",    rarity = "Common",    template = "WoodenKnife" },
	{ id = "scrap",     name = "Scrap Knife",     rarity = "Common",    template = "ScrapKnife" },
	{ id = "beachy",    name = "Beachy Knife",    rarity = "Common",    template = "BeachyKnife" },
	{ id = "emerald",   name = "Emerald Knife",   rarity = "Common",    template = "EmeraldKnife" },
	{ id = "bombardilo",name = "Bombardilo Knife",rarity = "Common",    template = "BombardiloKnife" },
	{ id = "tralalero", name = "Tralalero Knife", rarity = "Common", template = "TralaleroKnife", pose = { rx = -25, ry = 190, rz = 5, dist = 3.5 } },
	{ id = "lirililarila", name = "Lirili Larila Knife", rarity = "Common", template = "LiriliLarilaKnife" },
	-- ===== Uncommon (nicer single materials) =====
	{ id = "golden",    name = "Golden Knife",    rarity = "Uncommon",  template = "GoldenKnife", icon = "rbxassetid://106533988934612" },
	{ id = "lucky",     name = "Lucky Knife",     rarity = "Uncommon",  template = "LuckyKnife" },
	{ id = "frostbite", name = "Frostbite Knife", rarity = "Uncommon",  template = "FrostbiteKnife" },
	{ id = "magma",     name = "Magma Knife",     rarity = "Uncommon",  template = "MagmaKnife" },
	{ id = "assassino", name = "Assassino Knife", rarity = "Uncommon",  template = "AssassinoKnife" },
	{ id = "tungsahur", name = "Tung Sahur Knife", rarity = "Uncommon",  template = "TungSahurKnife" },
	{ id = "frigocamelo", name = "Frigo Camelo Knife", rarity = "Uncommon", template = "FrigoCameloKnife" },
	-- ===== Rare (elemental "Seer" family + cosmic dust + the cane set) =====
	{ id = "hypnoseer", name = "Hypno Seer Knife", rarity = "Rare",      template = "HypnoSeerKnife" },
	{ id = "lavaseer",  name = "Lava Seer Knife", rarity = "Rare",      template = "LavaSeerKnife" },
	{ id = "frozenseer",name = "Frozen Seer Knife",rarity = "Rare",     template = "FrozenSeerKnife" },
	{ id = "darkrose",  name = "Darkrose Blade",  rarity = "Epic", template = "DarkroseBlade", pose = { rx = -15.75, ry = 22.17, rz = -44.89, dist = 3.5 } },
	{ id = "nebula",    name = "Nebula Knife",    rarity = "Rare",      template = "NebulaKnife" },
	{ id = "purplecane",name = "Purple Cane Knife",rarity = "Rare",     template = "PurpleCaneKnife", pose = { rx = 510, ry = 135, rz = -210, dist = 4.5 } },
	{ id = "greencane", name = "Green Cane Knife", rarity = "Rare",     template = "GreenCaneKnife",  pose = { rx = 510, ry = 135, rz = -210, dist = 4.5 } },
	{ id = "bluecane",  name = "Blue Cane Knife",  rarity = "Uncommon", template = "BlueCaneKnife",   pose = { rx = 510, ry = 135, rz = -210, dist = 4.5 } },
	{ id = "orangecane",name = "Orange Cane Knife",rarity = "Rare",     template = "OrangeCaneKnife", pose = { rx = 510, ry = 135, rz = -210, dist = 4.5 } },
	{ id = "pinkcane",  name = "Pink Cane Knife",  rarity = "Rare",     template = "PinkCaneKnife",   pose = { rx = 510, ry = 135, rz = -210, dist = 4.5 } },
	{ id = "graffiti",  name = "Graffiti Knife",   rarity = "Rare",     template = "GraffitiKnife" },
	{ id = "strawberrycake", name = "Strawberry Cake Knife", rarity = "Rare", template = "StrawberryCakeKnife" },
	{ id = "pipipotatoseer", name = "Pipi Potato Seer Knife", rarity = "Rare", template = "PipiPotatoSeerKnife" },
	{ id = "chimpanziniseer", name = "Chimpanzini Seer Knife", rarity = "Rare", template = "ChimpanziniSeerKnife" },
	{ id = "brrbrrpatapim", name = "Brr Brr Patapim Knife", rarity = "Rare", template = "BrrBrrPatapimKnife" },
	{ id = "blueberrybunny", name = "Blueberry Bunny Knife", rarity = "Legendary", template = "BlueberryBunnyKnife", pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },  -- Legendary; drops from the Kawaii Kitchen Crate (kitchen pose: faces camera)
	-- ===== Epic (flashy themed sets: romance, hacked) =====
	{ id = "love",      name = "Love Knife",      rarity = "Epic",      template = "LoveKnife" },
	{ id = "roseflare", name = "Roseflare Knife", rarity = "Epic",      template = "RoseflareKnife" },
	{ id = "hackedseer",name = "Hacked Seer Knife",rarity = "Epic",     template = "HackedSeerKnife" },
	{ id = "butter",    name = "Butter Knife",    rarity = "Epic",      template = "ButterKnife" },
	{ id = "tralaritasseer", name = "Tralaritas Seer Knife", rarity = "Epic", template = "TralaritasSeerKnife" },
	{ id = "orcaleroorcala", name = "Orcalero Orcala Knife", rarity = "Epic", template = "OrcaleroOrcalaKnife", pose = { rx = -25, ry = 190, rz = 5, dist = 3.5 } },
	-- ===== Legendary (top prestige: cosmic seers, candy cane, rainbow, VIP, + Hakor) =====
	{ id = "hakor",     name = "Hakor Knife",     rarity = "Legendary", template = "HakorKnife" },
	{ id = "candyseer", name = "Candy Seer Knife", rarity = "Legendary", template = "CandySeerKnife" },
	{ id = "galaxyseer",name = "Galaxy Seer Knife",rarity = "Legendary", template = "GalaxySeerKnife" },
	{ id = "blackhole", name = "Blackhole Seer Knife",rarity = "Legendary", template = "BlackholeSeerKnife" },
	{ id = "candycane", name = "Candy Cane Knife", rarity = "Legendary", template = "CandyCaneKnife", pose = { rx = 510, ry = 135, rz = -210, dist = 4.5 } },
	{ id = "rainbow",   name = "Rainbow Knife",   rarity = "Legendary", template = "RainbowKnife" },
	{ id = "vip",       name = "VIP Knife",       rarity = "Legendary", template = "VIPKnife" },  -- VIP gamepass exclusive
	{ id = "sixtyseven", name = "67 Knife", rarity = "Legendary", template = "67Knife" },  -- was Secret; now Legendary (Brainrot only)
	{ id = "jobjobsahur", name = "Job Job Sahur Knife", rarity = "Legendary", template = "JobJobSahurKnife" },
	{ id = "guest666", name = "Guest 666 Knife", rarity = "Legendary", template = "Guest666Knife", pose = { rx = 155, ry = -20, rz = -180, dist = 3.5 } },
	-- ===== Secret (hidden top tier — do not add others here) =====
	{ id = "strawberryelephant", name = "Strawberry Elephant Knife", rarity = "Secret", template = "StrawberryElephantKnife" },
	{ id = "meowl", name = "Meowl Knife", rarity = "Secret", template = "MeowlKnife", pose = { rx = 155, ry = -20, rz = -180, dist = 3.5 } },
	{ id = "pothotspot", name = "Pot Hotspot Knife", rarity = "Secret", template = "PotHotspotKnife", pose = { rx = -20, ry = -157, rz = 8, dist = 3.5 } },
	{ id = "unicorn", name = "Unicorn Knife", rarity = "Secret", template = "UnicornKnife", pose = { rx = 95, ry = 221, rz = -240, dist = 5.5 } },
	{ id = "blackholedagger", name = "Blackhole Dagger Knife", rarity = "Secret", template = "BlackholeDaggerKnife", pose = { rx = 85, ry = 195, rz = -240, dist = 3.50 } },  -- Cosmic Crate exclusive Secret
	-- ===== Exclusive (gamepass / special-method only — NEVER in crates or the Level Up Reward) =====
	{ id = "vampirescythe", name = "Vampire Scythe Knife", rarity = "Exclusive", template = "VampireScytheKnife", pose = { rx = 3, ry = 214, rz = -322, dist = 6.40 } },
	{ id = "voidblade", name = "Void Blade Knife", rarity = "Exclusive", template = "VoidBladeKnife", pose = { rx = 95, ry = 221, rz = -240, dist = 5.5 } },
	{ id = "frozen",  name = "Frozen Knife",  rarity = "Exclusive", template = "FrozenKnife", pose = { rx = -15.75, ry = 22.17, rz = -44.89, dist = 3.5 } },
	-- ===== Kawaii Kitchen Crate knives. Templates live in ReplicatedStorage.KnifeSkins (copied from the
	-- NewKitchenSkins folder). "blueberrybunny" is registered above (Legendary) and is also a member of
	-- this crate, so it is NOT re-listed here. The "dango" knife uses the MochiKnife template (renamed).
	-- POSE: all kitchen knives carry the default icon pose but with ry flipped 180 (221 -> 41) so they
	-- face the camera in the odds-panel viewports (they imported facing away). rx/rz/dist = the defaults. =====
	{ id = "cakefork",     name = "Cake Fork Knife",     rarity = "Rare",      template = "CakeForkKnife",     pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "cheesy",       name = "Cheesy Knife",        rarity = "Epic",      template = "CheesyKnife",       pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "dango",        name = "Dango Knife",         rarity = "Legendary", template = "MochiKnife",        pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "sausagefork",  name = "Sausage Fork Knife",  rarity = "Rare",      template = "SausageForkKnife",  pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "fork",         name = "Fork Knife",          rarity = "Uncommon",  template = "ForkKnife",         pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "chipmunk",     name = "Chipmunk Knife",      rarity = "Legendary", template = "ChipmunkKnife",     pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "kitty",        name = "Kitty Knife",         rarity = "Epic",      template = "KittyKnife",        pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "bear",         name = "Bear Knife",          rarity = "Epic",      template = "BearKnife",         pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "spatula",      name = "Spatula Knife",       rarity = "Common",    template = "SpatulaKnife",      pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "eggspatula",   name = "Egg Spatula Knife",   rarity = "Rare",      template = "EggSpatulaKnife",   pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "pinkspoon",    name = "Pink Spoon Knife",    rarity = "Common",    template = "PinkSpoonKnife",    pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "greenspoon",   name = "Green Spoon Knife",   rarity = "Uncommon",  template = "GreenSpoonKnife",   pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "greenplastic", name = "Green Plastic",       rarity = "Common",    template = "GreenPlasticKnifeKnife", pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "pinkplastic",  name = "Pink Plastic",        rarity = "Uncommon",  template = "PinkPlasticKnifeKnife",  pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	{ id = "bakingspoon",  name = "Baking Spoon Knife",  rarity = "Epic",      template = "BakingSpoonKnife",  pose = { rx = 95, ry = 45, rz = -120, dist = 3.30 } },
	-- ===== Backrooms Crate knives. Templates live in ReplicatedStorage.KnifeSkins (copied from Workspace).
	-- Rarities for Hound/Hallucination/Entity Void (Legendary) and Buzzcut/Exit/Entity Whisperer (Epic)
	-- were specified; the remaining eight were assigned to round out the tiers (2 Common, 3 Uncommon,
	-- 3 Rare, 3 Epic, 3 Legendary; no Secret -- the odds engine renormalizes a crate with no Secret). =====
	{ id = "hound",          name = "Hound Knife",           rarity = "Legendary", template = "HoundKnife" },
	{ id = "hallucination",  name = "Hallucination Knife",   rarity = "Legendary", template = "HallucinationKnife" },
	{ id = "entityvoid",     name = "Entity Void Knife",     rarity = "Legendary", template = "EntityVoidKnife" },
	{ id = "buzzcut",        name = "Buzzcut Knife",         rarity = "Epic",      template = "BuzzCutKnife" },
	{ id = "exit",           name = "Exit Knife",            rarity = "Epic",      template = "ExitKnife" },
	{ id = "entitywhisperer",name = "Entity Whisperer Knife",rarity = "Epic",      template = "EntityWhispererKnife" },
	{ id = "smiler",         name = "Smiler Knife",          rarity = "Rare",      template = "SmilerKnife" },
	{ id = "signalcutter",   name = "Signal Cutter Knife",   rarity = "Rare",      template = "SignalCutterKnife" },
	{ id = "assetleak",      name = "Asset Leak Knife",      rarity = "Rare",      template = "AssetLeakKnife" },
	{ id = "thegoo",         name = "The Goo Knife",         rarity = "Uncommon",  template = "TheGooKnife" },
	{ id = "acidlevel",      name = "Acid Level Knife",      rarity = "Uncommon",  template = "AcidLevelKnife" },
	{ id = "noclip",         name = "Noclip Knife",          rarity = "Uncommon",  template = "NoclipKnife" },
	{ id = "fluorescent",    name = "Fluorescent Knife",     rarity = "Common",    template = "FluorescentKnife" },
	{ id = "wallpaper",      name = "Wallpaper Knife",       rarity = "Common",    template = "WallpaperKnife" },
	{ id = "carnotaurhorn",     name = "Carnotaur Horn Knife",     rarity = "Common",    template = "CarnotaurHornKnife" },
	{ id = "dinoeggblade",      name = "Dino Egg Blade Knife",     rarity = "Uncommon",  template = "DinoEggBladeKnife" },
	{ id = "triceraptorsguard", name = "Triceraptors Guard Knife", rarity = "Rare",      template = "TriceraptorsGuardKnife" },
	{ id = "spinosaursail",     name = "Spinosaur Sail Knife",     rarity = "Epic",      template = "SpinosaurSailKnife" },
	{ id = "dilophosaurfrill",  name = "Dilophosaur Frill Knife",  rarity = "Legendary", template = "DilophosaurFrillKnife" },
	{ id = "petrosaurwing",     name = "Petrosaur Wing Knife",     rarity = "Secret",    template = "PetrosaurWingKnife" },

	-- 4th of July Skins
	{ id = "libertywing",       name = "Liberty Wing",       rarity = "Uncommon",  template = "LibertyWing" },
	{ id = "independenceblade", name = "Independence Blade",  rarity = "Rare",      template = "IndependenceBlade" },
	{ id = "eaglesfire",        name = "Eagle's Fire",       rarity = "Epic",      template = "EaglesFire" },
	{ id = "rocketsroar",       name = "Rocket's Roar",      rarity = "Legendary", template = "RocketsRoar" },
	{ id = "battlebanner",      name = "Battle Banner",      rarity = "Epic",      template = "BattleBanner" },
	{ id = "patrioticphantom",  name = "Patriotic Phantom",  rarity = "Secret",    template = "PatrioticPhantom" },
	{ id = "fireworkfalcon",    name = "Firework Falcon",    rarity = "Uncommon",  template = "FireworkFalcon" },
	{ id = "freedomstorch",     name = "Freedom's Torch",    rarity = "Rare",      template = "FreedomsTorch" },
	{ id = "sparklingdagger",   name = "Sparkling Dagger",   rarity = "Common",    template = "SparklingDagger" },

	-- ===== Sports Crate =====
	{ id = "golf",           name = "Golf Knife",            rarity = "Common",    template = "GolfKnife" },
	{ id = "baseball",       name = "Baseball Knife",        rarity = "Uncommon",  template = "BaseballKnife" },
	{ id = "basketball",     name = "Basketball Knife",      rarity = "Rare",      template = "BasketballKnife" },
	{ id = "tennis",         name = "Tennis Knife",          rarity = "Epic",      template = "TennisKnife" },
	{ id = "football",       name = "Football Knife",        rarity = "Legendary", template = "FootballKnife" },
	{ id = "ultimatesoccer", name = "Ultimate Soccer Knife", rarity = "Secret",    template = "UltimateSoccerKnife" },

	{ id = "shopping",      name = "Shopping Knife",       rarity = "Rare",      template = "ShoppingKnife" },
	{ id = "military",      name = "Military Knife",       rarity = "Epic",      template = "MilitaryKnife" },
	{ id = "intercoolerpc", name = "Intercooler PC Knife", rarity = "Epic",      template = "IntercoolerPCKnife" },
	{ id = "pyramid",       name = "Pyramid Knife",        rarity = "Epic",      template = "PyramidKnife" },  -- Pyramids coloring-book reward
	{ id = "paintball",     name = "Paintball Knife",      rarity = "Rare",      template = "PaintballKnife" },
	{ id = "dragonblade",   name = "Dragon Blade Knife",   rarity = "Legendary", template = "DragonBladeKnife" },

	-- ===== Elemental Crate (one knife per tier) =====
	{ id = "lightenergy",  name = "Light Energy",  rarity = "Common",    template = "LightEnergy" },
	{ id = "infernoblade", name = "Inferno Blade", rarity = "Uncommon",  template = "InfernoBlade" },
	{ id = "tidaledge",    name = "Tidal Edge",    rarity = "Rare",      template = "TidalEdge" },
	{ id = "stormknife",   name = "Storm Knife",   rarity = "Epic",      template = "StormKnife" },
	{ id = "natureblade",  name = "Nature Blade",  rarity = "Legendary", template = "NatureBlade" },
	{ id = "plasmadagger", name = "Plasma Dagger", rarity = "Secret",    template = "PlasmaDagger" },
}

-- lookup: id -> skin def
KnifeSkinManager.SKIN_BY_ID = {}
for _, s in ipairs(KnifeSkinManager.SKINS) do
	KnifeSkinManager.SKIN_BY_ID[s.id] = s
end

function KnifeSkinManager.getSkin(id)
	return KnifeSkinManager.SKIN_BY_ID[id]
end

-- Display name for UI (inventory tiles, crate/unbox reveal, sell prompt): the catalog names all end
-- in " Knife" (e.g. "Vampire Scythe Knife"), but the UI shows them WITHOUT that suffix ("Vampire
-- Scythe"). Accepts either a skin id or a raw name string; strips a single trailing " Knife".
function KnifeSkinManager.displayName(idOrName)
	local name = idOrName
	local def = KnifeSkinManager.SKIN_BY_ID[idOrName]
	if def then name = def.name end
	if type(name) ~= "string" then return tostring(name) end
	-- strip a trailing " Knife" (case-insensitive on the word), leaving names like "67" untouched
	local stripped = name:gsub("%s+[Kk]nife%s*$", "")
	if stripped == "" then return name end  -- never return empty (e.g. a skin literally named "Knife")
	return stripped
end

-- get the template Model for a skin id (clone this to give/equip)
function KnifeSkinManager.getTemplate(id)
	local def = KnifeSkinManager.SKIN_BY_ID[id]
	if not def then return nil end
	local folder = ReplicatedStorage:FindFirstChild("KnifeSkins")
	return folder and folder:FindFirstChild(def.template)
end

-- The base/default knife (what a player has with no skin equipped). It's a copy of the server's
-- SeekerKnife placed in ReplicatedStorage.KnifeSkins as "DefaultKnife" so the client can render its
-- real model in the inventory viewport. It is intentionally NOT in SKINS/crates — it's not a drop.
KnifeSkinManager.DEFAULT_TEMPLATE_NAME = "DefaultKnife"
function KnifeSkinManager.getDefaultTemplate()
	local folder = ReplicatedStorage:FindFirstChild("KnifeSkins")
	return folder and folder:FindFirstChild(KnifeSkinManager.DEFAULT_TEMPLATE_NAME)
end

-- ===== Crate pools =====
-- MM2-style two-stage roll: first pick a RARITY by the base odds below, then pick one knife
-- UNIFORMLY at random within that rarity. One base odds table applies to EVERY crate (like MM2,
-- where all standard boxes share the same rarity odds). Tuned slightly more generous than MM2 so
-- the top tiers feel rewarding rather than impossible.
--
-- A knife's TRUE drop chance = (its rarity's % / 100) / (number of crate-eligible knives in that
-- rarity). getCrateOdds() computes this per knife, and the per-knife chances sum to 100% (required
-- for the shop's odds disclosure).
--
-- Notes:
--   * VIP knife is gamepass-exclusive and is EXCLUDED from crate pools (see isCrateEligible).
--   * If a crate happens to contain no knives of some rarity, that rarity's odds are redistributed
--     proportionally across the rarities the crate DOES have, so the totals always sum to 100%.
-- Rarity odds follow a standard descending loot curve (each tier markedly rarer than the one below),
-- so rarities feel meaningful. This SAME curve applies to all three crates, so no crate is better
-- than another (they're priced similarly) — the crates differ only in WHICH knives they feature.
-- Secret is pinned at a fixed 0.5% jackpot. Sums to 100. effectiveRarityOdds() re-pins Secret and
-- renormalizes the present tiers per crate.
KnifeSkinManager.RARITY_ODDS = {
	Common    = 45.5,
	Uncommon  = 27,
	Rare      = 15,
	Epic      = 8,
	Legendary = 4,
	Secret    = 0.5,
}

-- Separate, NERFED rarity odds used ONLY by the free Level Up Reward (see rollSkinWithOdds).
-- Paid crates keep RARITY_ODDS above. Here the top tiers are cut hard so leveling up rarely hands
-- out a Legendary/Secret. The top-tier chances were HALVED from their previous values
-- (Legendary 1 -> 0.5, Secret 0.25 -> 0.125) to make them rarer still; the low tiers absorb the
-- freed weight via effectiveRarityOdds' renormalization. Same descending-curve shape, just steeper.
KnifeSkinManager.CRATE_RARITY_ODDS = {
	["Jurassic Crate"] = { Common = 36.6, Uncommon = 29, Rare = 22, Epic = 10, Legendary = 1.9, Secret = 0.5 },
	["Sports Crate"] = { Common = 36.6, Uncommon = 29, Rare = 22, Epic = 10, Legendary = 1.9, Secret = 0.5 },
	-- Elemental Crate: one knife per tier, so each knife's chance equals its tier % (sums to 100).
	["Elemental Crate"] = { Common = 37, Uncommon = 29, Rare = 22, Epic = 10, Legendary = 1.9, Secret = 0.1 },
}
KnifeSkinManager.LEVELUP_RARITY_ODDS = {
	Common    = 60,
	Uncommon  = 27,
	Rare      = 8.75,
	Epic      = 3,
	Legendary = 0.5,
	Secret    = 0.125,
}

-- Knives that may NOT drop from any crate (gamepass-exclusive, event-only, etc.), keyed by id.
-- NOTE: every "Exclusive"-rarity knife is also implicitly never a crate drop (it's never listed in
-- any CRATES pool, and Exclusive has 0 base rarity odds), but we list them here too for clarity.
local CRATE_INELIGIBLE = {
	vip = true,            -- VIP knife: VIP gamepass exclusive, never a crate drop
	vampirescythe = true,  -- Vampire Scythe: Exclusive tier, gamepass/special-only
	voidblade = true,      -- Void Blade: Exclusive tier, gamepass/special-only
	darkrose = true,       -- Darkrose Blade: starter pack exclusive
	-- (blueberrybunny removed from this ineligible list: it is now a Legendary member of the Kawaii
	-- Kitchen Crate and is meant to drop, so it must NOT be crate-ineligible.)
}
function KnifeSkinManager.isCrateEligible(id)
	return not CRATE_INELIGIBLE[id]
end

-- Each crate lists the skin ids it can drop. To keep the crates EQUAL (similar prices), every crate
-- has the SAME number of knives in each tier: 3 Common, 3 Uncommon, 3 Rare, 3 Epic, 2 Legendary,
-- 2 Secret. Because the tier odds are equal and the counts match, every individual knife has
-- identical odds in every crate. The crates feature DISTINCT knives wherever the catalog allows:
-- each legendary appears in exactly one crate (6 legendaries / 2 per crate), and rares/commons/
-- uncommons are split with minimal overlap. Crate 1 (Wooden) features Butter as its unique Epic;
-- Crates 2 and 3 share Hacked Seer alongside Love + Roseflare. All three Secrets (Strawberry
-- Elephant + 67 Knife + Meowl) appear in every crate, so the pinned 1% Secret chance splits evenly
-- between them (~0.333% each).
KnifeSkinManager.CRATES = {
	-- BASIC: seer rares + legendaries Hakor & Candy Seer.
	["Wooden Crate"] = {
		"wooden", "scrap", "beachy",            -- Common (3)
		"golden", "lucky", "frostbite",         -- Uncommon (3)
		"hypnoseer", "lavaseer", "frozenseer",   -- Rare (3)
		"love", "roseflare", "butter",          -- Epic (3; Butter is unique to this crate, Hacked Seer in the others)
		"hakor", "candyseer",                   -- Legendary (2, unique to this crate)
		"strawberryelephant", "meowl", "pothotspot", "unicorn",  -- Secret (4: shared across all crates; the 1% splits evenly)
	},
	-- GRAFFITI: the Graffiti Knife + cane rares, legendaries Candy Cane & Rainbow. Blue Cane was moved
	-- DOWN to Uncommon here to make room for Graffiti in the Rare tier (so this crate has 4 Uncommons /
	-- 3 Rares). Blue Cane is now an Uncommon everywhere (its rarity is set in SKINS).
	["Silver Crate"] = {
		"scrap", "beachy", "emerald",            -- Common (3)
		"lucky", "frostbite", "magma", "bluecane",  -- Uncommon (4; Blue Cane demoted from Rare)
		"purplecane", "greencane", "graffiti",   -- Rare (3; Graffiti is this crate's themed knife)
		"love", "roseflare", "hackedseer",      -- Epic (3)
		"candycane", "rainbow",                 -- Legendary (2, unique to this crate)
		"strawberryelephant", "meowl", "pothotspot", "unicorn",  -- Secret (4: shared across all crates; the 1% splits evenly)
	},
	-- COSMIC: cosmic/cake rares + legendaries Galaxy Seer & Blackhole.
	["Golden Crate"] = {
		"wooden", "emerald", "beachy",           -- Common (3)
		"golden", "magma", "lucky",             -- Uncommon (3)
		"nebula", "lavaseer", "strawberrycake",  -- Rare (3; Lava Seer shared in from Wooden after Graffiti moved to Graffiti/Silver)
		"love", "roseflare", "hackedseer",      -- Epic (3)
		"galaxyseer", "blackhole", "blackholedagger",  -- + Blackhole Dagger (Secret tier via its SKINS rarity; this crate only)              -- Legendary (2, unique to this crate)
		"strawberryelephant", "meowl", "pothotspot", "unicorn",  -- Secret (4: shared across all crates; the 1% splits evenly)
	},
}
KnifeSkinManager.CRATES["Gold Crate"] = KnifeSkinManager.CRATES["Golden Crate"]  -- accept either spelling

-- BRAINROT: a themed crate. Contains Bombardilo, Tralalero & Lirili Larila (Common, 3) + Assassino,
-- Tung Sahur & Frigo Camelo (Uncommon, 3) + Pipi Potato Seer, Chimpanzini Seer & Brr Brr Patapim
-- (Rare, 3) + Butter, Tralaritas Seer & Orcalero Orcala (Epic, 3) + 67 Knife, Job Job Sahur &
-- Guest 666 (Legendary, 3) + Strawberry Elephant, Meowl & Pot Hotspot (Secret, 3). Secret stays
-- pinned at 1%; the remaining 99% splits among the present tiers by their base weights (Common 45 /
-- Uncommon 27 / Rare 15 / Epic 8 / Legendary 4 = 99 total).
KnifeSkinManager.CRATES["Brainrot Crate"] = {
	"bombardilo", "tralalero", "lirililarila",      -- Common (3)
	"assassino", "tungsahur", "frigocamelo",        -- Uncommon (3)
	"pipipotatoseer", "chimpanziniseer", "brrbrrpatapim",  -- Rare (3)
	"butter", "tralaritasseer", "orcaleroorcala",  -- Epic (3)
	"sixtyseven", "jobjobsahur", "guest666",        -- Legendary (3)
	"strawberryelephant", "meowl", "pothotspot", "unicorn",    -- Secret (4: the 1% splits evenly)
}

-- KAWAII KITCHEN: the new kitchen-themed crate, 16 kitchen knives across the tiers + all 3 Secrets:
--   Legendary (3): chipmunk, blueberrybunny, dango
--   Epic (4):      bear, kitty, cheesy, bakingspoon
--   Rare (3):      eggspatula, cakefork, sausagefork
--   Uncommon (3):  fork, greenspoon, pinkplastic
--   Common (3):    spatula, pinkspoon, greenplastic
--   Secret (3):    strawberryelephant, meowl, pothotspot (shared across all crates; the pinned 1%
--                  splits evenly, ~0.333% each)
-- (plasticfork was removed from the game.) Tier odds are computed from each knife's rarity in SKINS,
-- the same way as the other crates.
KnifeSkinManager.CRATES["Kawaii Kitchen Crate"] = {
	"cakefork", "cheesy", "dango", "sausagefork", "fork",
	"chipmunk", "kitty", "bear", "spatula", "eggspatula",
	"pinkspoon", "greenspoon", "greenplastic", "pinkplastic",
	"bakingspoon", "blueberrybunny",
	"strawberryelephant", "meowl", "pothotspot", "unicorn",  -- Secret (4: shared across all crates; the 1% splits evenly)
}

-- BACKROOMS: a themed crate of 15 knives. Hound, Hallucination & Entity Void are the Legendaries;
-- Buzzcut, Exit & Entity Whisperer the Epics; the rest fill Rare/Uncommon/Common; Blackhole Dagger is
-- the lone Secret. With a Secret present, effectiveRarityOdds() pins the 1% Secret share and splits
-- the remaining 99% across the present tiers (Common 45 / Uncommon 27 / Rare 15 / Epic 8 /
-- Legendary 4 = 99), so Blackhole Dagger has the full pinned 1% to itself.
KnifeSkinManager.CRATES["Backrooms Crate"] = {
	"fluorescent", "wallpaper",                       -- Common (2)
	"thegoo", "acidlevel", "noclip",                  -- Uncommon (3)
	"smiler", "signalcutter", "assetleak",            -- Rare (3)
	"buzzcut", "exit", "entitywhisperer",             -- Epic (3)
	"hound", "hallucination", "entityvoid",           -- Legendary (3)
	"blackholedagger",                                -- Secret (1: the pinned 1% to itself)
}
KnifeSkinManager.CRATES["Jurassic Crate"] = {
	"carnotaurhorn",
	"dinoeggblade",
	"triceraptorsguard",
	"spinosaursail",
	"dilophosaurfrill",
	"petrosaurwing",
}

KnifeSkinManager.CRATES["Sports Crate"] = {
	"golf",
	"baseball",
	"basketball",
	"tennis",
	"football",
	"ultimatesoccer",
}

-- ELEMENTAL: one knife per rarity tier. Common 37 / Uncommon 29 / Rare 22 / Epic 10 / Legendary 1.9
-- / Secret 0.1 (see CRATE_RARITY_ODDS). With a single knife per tier, each knife's drop chance is
-- exactly its tier's % and the six sum to 100. Robux-only (no coin price / no expiry timer).
KnifeSkinManager.CRATES["Elemental Crate"] = {
	"lightenergy",
	"infernoblade",
	"tidaledge",
	"stormknife",
	"natureblade",
	"plasmadagger",
}
function KnifeSkinManager.getCratePool(crateName)
	return KnifeSkinManager.CRATES[crateName]
end

KnifeSkinManager.CRATE_EXPIRY = {
	["Jurassic Crate"] = 1783170000,
}
-- Elemental Crate reuses this slot's timer; end time = Jurassic + 14 days = 2026-07-18 13:00 UTC.
KnifeSkinManager.CRATE_EXPIRY["Sports Crate"] = KnifeSkinManager.CRATE_EXPIRY["Jurassic Crate"] + 14 * 86400
function KnifeSkinManager.crateExpiry(crateName)
	return KnifeSkinManager.CRATE_EXPIRY[crateName]
end
function KnifeSkinManager.isCrateExpired(crateName)
	local exp = KnifeSkinManager.CRATE_EXPIRY[crateName]
	return exp ~= nil and os.time() >= exp
end

-- Coin (in-game currency) prices for the paid knife crates. SINGLE SOURCE OF TRUTH: both the crate
-- shop UI (CrateShopNewClient) and the server-authoritative coin-purchase handler (MatchManager) read
-- these via crateCoinPrice(), so a price is only ever set here. A crate with NO entry is not coin-
-- purchasable (e.g. the Sports Crate is Robux-only). "Gold Crate" mirrors "Golden Crate" (accepted spelling).
KnifeSkinManager.CRATE_COIN_PRICES = {
	["Wooden Crate"] = 350,
	["Silver Crate"] = 550,
	["Golden Crate"] = 900,
	["Brainrot Crate"] = 700,
	["Kawaii Kitchen Crate"] = 900,
	["Backrooms Crate"] = 1100,
}
KnifeSkinManager.CRATE_COIN_PRICES["Gold Crate"] = KnifeSkinManager.CRATE_COIN_PRICES["Golden Crate"]
function KnifeSkinManager.crateCoinPrice(crateName)
	return KnifeSkinManager.CRATE_COIN_PRICES[crateName]
end

-- Group a crate's pool into { [rarityName] = { id, id, ... } }, skipping ineligible ids.
local function groupByRarity(crateName)
	local pool = KnifeSkinManager.CRATES[crateName]
	if not pool then return nil end
	local byRarity = {}
	for _, id in ipairs(pool) do
		if KnifeSkinManager.isCrateEligible(id) then
			local def = KnifeSkinManager.SKIN_BY_ID[id]
			local rar = def and def.rarity or "Common"
			byRarity[rar] = byRarity[rar] or {}
			table.insert(byRarity[rar], id)
		end
	end
	return byRarity
end

-- Effective rarity odds for a crate. The Secret tier is PINNED at its base % (1%) in every crate
-- that contains a Secret knife; the OTHER present tiers are renormalized to fill the remaining
-- (100 - secret%). Tiers the crate has no knives in are dropped. Returns { [rarityName] = percent },
-- summing to 100.
--
-- oddsTable (optional): the base rarity-odds table to use. Defaults to RARITY_ODDS (paid crates).
-- The Level Up Reward passes LEVELUP_RARITY_ODDS to apply its nerfed top-tier chances.
local SECRET_RARITY = "Secret"
local function applyLuckToBaseOdds(oddsTable, luckMultiplier)
	luckMultiplier = tonumber(luckMultiplier) or 1
	if luckMultiplier <= 1 then
		return oddsTable
	end

	local adjusted = {}
	local maxRank = math.max(KnifeSkinManager.rarityRank(SECRET_RARITY), 1)
	for rarity, pct in pairs(oddsTable) do
		local rank = KnifeSkinManager.rarityRank(rarity)
		if type(pct) == "number" and pct > 0 and rank > 0 then
			local rarityFactor = if maxRank > 1 then (rank - 1) / (maxRank - 1) else 0
			adjusted[rarity] = pct * (1 + ((luckMultiplier - 1) * rarityFactor))
		else
			adjusted[rarity] = pct
		end
	end
	return adjusted
end

local function effectiveRarityOdds(crateName, oddsTable, luckMultiplier)
	oddsTable = oddsTable or KnifeSkinManager.CRATE_RARITY_ODDS[crateName] or KnifeSkinManager.RARITY_ODDS
	oddsTable = applyLuckToBaseOdds(oddsTable, luckMultiplier)
	local byRarity = groupByRarity(crateName)
	if not byRarity then return {} end

	-- fixed Secret share (only if the crate actually has a Secret knife)
	local secretPct = 0
	if byRarity[SECRET_RARITY] and #byRarity[SECRET_RARITY] > 0 then
		secretPct = oddsTable[SECRET_RARITY] or 0
	end

	-- gather the non-Secret present tiers and their base weights
	local raw, total = {}, 0
	for rar, ids in pairs(byRarity) do
		if rar ~= SECRET_RARITY and #ids > 0 then
			local pct = oddsTable[rar] or 0
			if pct > 0 then raw[rar] = pct; total += pct end
		end
	end

	local odds = {}
	if secretPct > 0 then odds[SECRET_RARITY] = secretPct end
	local remaining = 100 - secretPct
	if total > 0 then
		for rar, pct in pairs(raw) do
			odds[rar] = (pct / total) * remaining
		end
	elseif secretPct > 0 then
		-- crate somehow only has the Secret tier: give it everything
		odds[SECRET_RARITY] = 100
	end
	return odds
end

-- compute each knife's TRUE drop % for a crate (for the disclosure panel). Each knife in a rarity
-- shares that rarity's odds equally. The returned chances sum to ~1.0 (100%).
--
-- collapseSecret: when true, ALL Secret-tier knives are merged into ONE combined entry whose chance
-- is the full Secret tier % (e.g. 1%). The shop uses this so the panel shows a single "SECRET" row
-- at 1% (a mystery slot) even though multiple distinct Secrets can actually drop. This is display-
-- only; rollSkin() still picks uniformly among the real Secret knives, so each remains obtainable.
function KnifeSkinManager.getCrateOdds(crateName, collapseSecret, luckMultiplier)
	local byRarity = groupByRarity(crateName)
	if not byRarity then return {} end
	local rarityPct = effectiveRarityOdds(crateName, nil, luckMultiplier)
	local odds = {}
	for rar, ids in pairs(byRarity) do
		local tierPct = rarityPct[rar] or 0
		if collapseSecret and rar == SECRET_RARITY and #ids > 0 then
			-- one combined mystery entry for the whole Secret tier (sums to the pinned tier %)
			odds[#odds + 1] = {
				id = "__secret__",
				name = "Secret",
				rarity = SECRET_RARITY,
				chance = tierPct / 100,  -- 0..1 (the full Secret share, e.g. 0.01)
			}
		else
			local perKnife = (#ids > 0) and (tierPct / #ids) or 0
			for _, id in ipairs(ids) do
				local def = KnifeSkinManager.SKIN_BY_ID[id]
				odds[#odds + 1] = {
					id = id,
					name = def and def.name or id,
					rarity = def and def.rarity or "Common",
					chance = perKnife / 100,  -- 0..1
				}
			end
		end
	end
	return odds
end

-- roll a winning skin id: stage 1 pick a rarity by the (effective) rarity odds, stage 2 pick one
-- knife uniformly within that rarity.
function KnifeSkinManager.rollSkin(crateName, luckMultiplier)
	return KnifeSkinManager.rollSkinWithOdds(crateName, nil, luckMultiplier)
end

-- Same as rollSkin but with an explicit base rarity-odds table. The Level Up Reward calls this with
-- LEVELUP_RARITY_ODDS to use its nerfed top-tier chances; paid crates use the default via rollSkin.
function KnifeSkinManager.rollSkinWithOdds(crateName, oddsTable, luckMultiplier)
	oddsTable = oddsTable or KnifeSkinManager.CRATE_RARITY_ODDS[crateName] or KnifeSkinManager.RARITY_ODDS
	local byRarity = groupByRarity(crateName)
	if not byRarity then return nil end
	local rarityPct = effectiveRarityOdds(crateName, oddsTable, luckMultiplier)

	-- stage 1: weighted pick of a rarity
	local total = 0
	for _, pct in pairs(rarityPct) do total += pct end
	if total <= 0 then return nil end
	local r = math.random() * total
	local acc, chosenRarity = 0, nil
	for rar, pct in pairs(rarityPct) do
		acc += pct
		if r <= acc then chosenRarity = rar; break end
	end
	if not chosenRarity then
		-- numeric fallback: pick any rarity present
		for rar in pairs(rarityPct) do chosenRarity = rar; break end
	end

	-- stage 2: uniform pick within the chosen rarity
	local ids = byRarity[chosenRarity]
	if not ids or #ids == 0 then return nil end
	return ids[math.random(1, #ids)]
end

-- ===== VFX mutations (rolled separately on each unbox) =====
-- "None" is the common no-mutation result. Each other entry is a cosmetic aura applied to the
-- equipped knife. To ADD a new mutation later: (1) put its VFX model in ReplicatedStorage.KnifeVFX
-- named in lowercase (e.g. "frost"), and (2) add a line here with id = that lowercase name. The
-- equip code looks the VFX up by id, so no other code changes are needed.
-- NOTE: `id` MUST match the KnifeVFX folder entry name (lowercase).
-- `color` tints the mutation name label in the UI (chosen to evoke each mutation's theme).
KnifeSkinManager.EFFECTS = {
	{ id = "none",      name = "None",      weight = 80 },  -- no mutation
	{ id = "nightmare", name = "Nightmare", weight = 2, color = Color3.fromRGB(120, 60, 170) },  -- dark purple
	{ id = "sparkly",   name = "Sparkly",   weight = 2, color = Color3.fromRGB(120, 230, 255) },  -- bright cyan sparkle
	{ id = "fireflies", name = "Fireflies", weight = 2, color = Color3.fromRGB(190, 230, 90) },   -- warm yellow-green glow
	{ id = "galaxy",    name = "Galaxy",    weight = 2, color = Color3.fromRGB(110, 120, 240) },  -- deep violet-blue
	{ id = "candy",     name = "Candy",     weight = 2, color = Color3.fromRGB(255, 130, 200) },  -- candy pink
	{ id = "lucky",     name = "Lucky",     weight = 2, color = Color3.fromRGB(90, 210, 110) },   -- clover green
	{ id = "lovely",    name = "Lovely",    weight = 2, color = Color3.fromRGB(255, 105, 150) },  -- rose pink
	{ id = "glitch",    name = "Glitch",    weight = 2, color = Color3.fromRGB(60, 255, 170) },   -- electric green-cyan
	{ id = "firey",     name = "Firey",     weight = 2, color = Color3.fromRGB(255, 120, 40) },   -- orange-red flame
	{ id = "67",        name = "67",        weight = 2, color = Color3.fromRGB(90, 170, 255) },    -- 67 numbers flying out
}
KnifeSkinManager.EFFECT_BY_ID = {}
for _, e in ipairs(KnifeSkinManager.EFFECTS) do
	KnifeSkinManager.EFFECT_BY_ID[e.id] = e
end

function KnifeSkinManager.rollEffect()
	local total = 0
	for _, e in ipairs(KnifeSkinManager.EFFECTS) do total += e.weight end
	local r = math.random() * total
	local acc = 0
	for _, e in ipairs(KnifeSkinManager.EFFECTS) do
		acc += e.weight
		if r <= acc then return e.id end
	end
	return "none"
end

-- Roll a GUARANTEED mutation: like rollEffect but never returns "none" (picks among the real
-- mutations only, by their relative weights). Used by bundles that promise a guaranteed mutation.
function KnifeSkinManager.rollGuaranteedEffect()
	local total = 0
	for _, e in ipairs(KnifeSkinManager.EFFECTS) do
		if e.id ~= "none" then total += e.weight end
	end
	if total <= 0 then return "none" end
	local r = math.random() * total
	local acc = 0
	for _, e in ipairs(KnifeSkinManager.EFFECTS) do
		if e.id ~= "none" then
			acc += e.weight
			if r <= acc then return e.id end
		end
	end
	for _, e in ipairs(KnifeSkinManager.EFFECTS) do
		if e.id ~= "none" then return e.id end
	end
	return "none"
end

function KnifeSkinManager.effectName(id)
	local e = KnifeSkinManager.EFFECT_BY_ID[id]
	return e and e.name or "None"
end

-- color for a mutation's name label (falls back to a neutral white if unset, e.g. "none")
function KnifeSkinManager.effectColor(id)
	local e = KnifeSkinManager.EFFECT_BY_ID[id]
	return (e and e.color) or Color3.fromRGB(235, 235, 235)
end

do
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() and RunService:IsServer() then
		task.defer(function()
			local folder = ReplicatedStorage:FindFirstChild("KnifeSkins")
			if not folder then
				warn("[KnifeSkinManager] audit: ReplicatedStorage.KnifeSkins folder missing -- cannot verify skin templates")
				return
			end

			local missing = 0
			for _, def in ipairs(KnifeSkinManager.SKINS) do
				if not folder:FindFirstChild(def.template) then
					missing += 1
					warn(string.format("[KnifeSkinManager] No template model '%s' found in KnifeSkins for skin '%s' (id=%s, %s)",
						tostring(def.template), tostring(def.name), tostring(def.id), tostring(def.rarity)))
				end
			end
		end)
	end
end

return KnifeSkinManager
