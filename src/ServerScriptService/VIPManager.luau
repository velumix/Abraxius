-- VIPManager: owns the VIP gamepass (Constants.Gamepasses.VIP) perks in one place.
--
-- Perks:
--   1. Special Knife  - grants the "vip" knife skin once (template "VIPKnife" in ReplicatedStorage.KnifeSkins).
--   2. Permanent Double XP - handled elsewhere: LevelManager.CONFIG.VIP_GAMEPASS_ID is set to this pass,
--                            and MatchManager applies VIP_VICTORY_MULT (2x, non-stacking) for owners.
--                            Nothing to do here for that perk; it is automatic.
--   3. +1500 Coins (one time) - granted exactly once ever via CoinManager.grantVIPCoinsOnce.
--
-- applyPerks(player) is safe to call on join AND on purchase; both the knife grant and the coin
-- grant are idempotent (knife via InventoryManager.grantOnce, coins via a persistent flag).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _coin, _inv
local function coinSvc() if not _coin then _coin = svc("CoinService") end return _coin end
local function invSvc() if not _inv then _inv = svc("DataService") end return _inv end

local VIPManager = {}

VIPManager.GAMEPASS_ID = Constants.Gamepasses.VIP
VIPManager.VIP_KNIFE_SKIN_ID = "vip"   -- registered in KnifeSkinManager.SKINS
VIPManager.COIN_GRANT = 1500           -- one-time coin bonus
VIPManager.CHAT_TAG_COLOR = "#FFD700"  -- yellow/gold for the [VIP] chat tag

-- ownership cache so we don't hit the API repeatedly
local ownsCache = {}  -- [userId] = bool

local function ownsVIP(player)
	local cached = ownsCache[player.UserId]
	if cached ~= nil then return cached end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIPManager.GAMEPASS_ID)
	end)
	local owns = ok and result or false
	ownsCache[player.UserId] = owns
	return owns
end
VIPManager.ownsVIP = ownsVIP

-- Grant all VIP perks the player is entitled to. Idempotent: safe to call repeatedly.
function VIPManager.applyPerks(player)
	if not player or not player.Parent then return end
	if not ownsVIP(player) then return end

	-- Perk 1: VIP knife (grant once; won't duplicate on rejoin)
	invSvc():GrantWeaponOnce(player, VIPManager.VIP_KNIFE_SKIN_ID, "none")

	-- Perk: mark the player as VIP so clients can show the [VIP] chat tag
	player:SetAttribute("IsVIP", true)

	-- Perk 3: +1500 coins, one time ever (persistent flag inside CoinManager)
	coinSvc():GrantVIPCoinsOnce(player, VIPManager.COIN_GRANT)

	-- Perk 2 (Double XP) is automatic via LevelManager.VIP_GAMEPASS_ID + MatchManager.
end

-- VIP chat tag is rendered CLIENT-side (TextChatService.OnIncomingMessage must be implemented on
-- the client). The server just marks owners with the "IsVIP" attribute (done in applyPerks above);
-- VIPChatTagClient reads that attribute to prepend the yellow [VIP] prefix for everyone.

function VIPManager.init()
	-- apply on join for existing owners
	local function onPlayer(plr)
		task.spawn(function()
			task.wait(1.5)  -- give Coin/Inventory data a moment to load
			VIPManager.applyPerks(plr)
		end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
	Players.PlayerAdded:Connect(onPlayer)

	-- apply immediately when someone buys the VIP pass mid-session
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, wasPurchased)
		if passId == VIPManager.GAMEPASS_ID and wasPurchased then
			ownsCache[plr.UserId] = true
			VIPManager.applyPerks(plr)
		end
	end)

	Players.PlayerRemoving:Connect(function(plr) ownsCache[plr.UserId] = nil end)
end

return VIPManager
