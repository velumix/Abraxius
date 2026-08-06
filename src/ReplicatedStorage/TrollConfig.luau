-- TrollConfig: single shared source of truth for the Trolls feature (client + server agree on this).
-- Each troll has a "one" product (troll one random nearest seeker) and an "all" product (every seeker).
--
-- Product IDs below are the LIVE developer-product ids. The ICON ids are still placeholders (rbxassetid://0).
-- Both the client UI and the server ProcessReceipt read these same ids.
--
-- The ORDER of TrollConfig.Order is the order the rows appear in the TrollUI (top to bottom), matching
-- the GUI mock: Jumpscare, Flashbang, Freeze, Trip, Confusion.

local TrollConfig = {}

-- effect durations (seconds). Banner is always 5s per design.
TrollConfig.BANNER_SECONDS = 5
TrollConfig.JUMPSCARE_SECONDS = 2
TrollConfig.FLASHBANG_SECONDS = 2
TrollConfig.FREEZE_SECONDS = 5
TrollConfig.TRIP_SECONDS = 3
TrollConfig.CONFUSION_SECONDS = 5

-- Freeze tint (matches the blue used elsewhere in the game's freeze visuals)
TrollConfig.FREEZE_COLOR = Color3.fromRGB(0, 116, 188)
TrollConfig.FREEZE_WALKSPEED = 5

-- Each entry: key, display name, icon (placeholder), and the two product ids.
-- scope "one" = nearest single seeker, "all" = every seeker in the round.
TrollConfig.Trolls = {
	Jumpscare = {
		key = "Jumpscare",
		name = "Jumpscare",
		icon = "rbxassetid://0",            -- PLACEHOLDER icon
		oneProduct = 3605152165,             -- Jumpscare One
		allProduct = 3605152183,             -- Jumpscare All
	},
	Flashbang = {
		key = "Flashbang",
		name = "Flashbang",
		icon = "rbxassetid://0",            -- PLACEHOLDER icon
		oneProduct = 3605152226,             -- Flashbang One
		allProduct = 3605152253,             -- Flashbang All
	},
	Freeze = {
		key = "Freeze",
		name = "Freeze",
		icon = "rbxassetid://0",            -- PLACEHOLDER icon
		oneProduct = 3605151592,             -- Freeze One
		allProduct = 3605151704,             -- Freeze All
	},
	Trip = {
		key = "Trip",
		name = "Trip",
		icon = "rbxassetid://0",            -- PLACEHOLDER icon
		oneProduct = 3605152083,             -- Trip One
		allProduct = 3605152102,             -- Trip All
	},
	Confusion = {
		key = "Confusion",
		name = "Confusion",
		icon = "rbxassetid://0",            -- PLACEHOLDER icon
		oneProduct = 3605152031,             -- Confuse One
		allProduct = 3605152047,             -- Confuse All
	},
}

-- top-to-bottom row order in the UI
TrollConfig.Order = { "Jumpscare", "Flashbang", "Freeze", "Trip", "Confusion" }

-- Build reverse lookups: productId -> { key=..., scope="one"|"all" }. Used by the server
-- ProcessReceipt to map a purchased product back to an effect + scope in O(1).
TrollConfig.ByProduct = {}
for _, key in ipairs(TrollConfig.Order) do
	local t = TrollConfig.Trolls[key]
	if t then
		TrollConfig.ByProduct[t.oneProduct] = { key = key, scope = "one" }
		TrollConfig.ByProduct[t.allProduct] = { key = key, scope = "all" }
	end
end

return TrollConfig
