-- PolicyManager: wraps Roblox's PolicyService so the rest of the game can ask a simple question:
-- "is this player restricted from PAID RANDOM ITEMS (loot boxes / crates)?"
--
-- Roblox decides this per-player based on geolocation, age group, and platform via
-- PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted. Some regions ban
-- paid random-item generators outright; when restricted we must not let the player buy crates, and
-- (per Roblox guidance) we hide the crate shop UI entirely rather than letting a purchase fail.
--
-- IMPORTANT: this only governs PAID crates (Robux dev products, or crates bought with coins that were
-- bought with Robux). The FREE Level Up Reward crate is NOT a paid random item and is unaffected.
--
-- The result is cached per player (it doesn't change during a session) and pushed to the client both
-- as a RemoteEvent and as a player attribute ("PaidRandomRestricted") so client UI can read it
-- synchronously without a round-trip.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PolicyManager = {}

-- [userId] = boolean (true = restricted from paid random items). nil = not yet resolved.
local restricted = {}

local RESTRICT_ATTR = "PaidRandomRestricted"

-- Remote used to push the flag to the owning client (the client also reads the attribute).
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local PolicyUpdate = Remotes:FindFirstChild("PolicyUpdate")
if not PolicyUpdate then
	PolicyUpdate = Instance.new("RemoteEvent")
	PolicyUpdate.Name = "PolicyUpdate"
	PolicyUpdate.Parent = Remotes
end

-- Resolve (and cache) one player's policy. Defaults to RESTRICTED on error: failing closed is the
-- safe choice for a compliance gate — better to hide the shop from someone who could have used it
-- than to show it to someone who is actually restricted.
local function resolve(player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local isRestricted
	if ok and type(info) == "table" then
		isRestricted = info.ArePaidRandomItemsRestricted and true or false
	else
		warn("[PolicyManager] GetPolicyInfoForPlayerAsync failed for " .. player.Name .. ": " .. tostring(info) .. " (defaulting to RESTRICTED)")
		isRestricted = true
	end
	restricted[player.UserId] = isRestricted
	-- attribute (synchronous client read) + remote (event-driven client update)
	player:SetAttribute(RESTRICT_ATTR, isRestricted)
	PolicyUpdate:FireClient(player, isRestricted)
	return isRestricted
end

-- True if the player is restricted from paid random items (crates). If we haven't resolved them
-- yet (call raced ahead of the async resolve), fail closed by treating them as restricted.
function PolicyManager.isPaidRandomRestricted(player)
	if not player then return true end
	local v = restricted[player.UserId]
	if v == nil then return true end  -- not resolved yet -> fail closed
	return v
end

function PolicyManager.init()
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(resolve, plr)
	end
	Players.PlayerAdded:Connect(function(plr)
		task.spawn(resolve, plr)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		restricted[plr.UserId] = nil
	end)
end

return PolicyManager
