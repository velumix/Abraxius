-- WelcomeBadge: awards the "Welcome" badge (id 2346554554573763) to a player the first time they
-- join. BadgeService:AwardBadge is a no-op if the player already owns the badge, but we still check
-- UserHasBadgeAsync first to avoid an unnecessary award call on returning players.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local WELCOME_BADGE_ID = 2346554554573763

local function awardWelcome(player)
	-- check current ownership (wrapped: these web calls can error/time out)
	local okHas, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, WELCOME_BADGE_ID)
	end)
	if not okHas then
		-- couldn't verify ownership; don't risk a spurious award, just stop
		warn("[WelcomeBadge] ownership check failed for " .. player.Name .. ": " .. tostring(hasBadge))
		return
	end
	if hasBadge then
		return  -- already has it (returning player) — nothing to do
	end

	-- first time joining: award it
	local okAward, awarded = pcall(function()
		return BadgeService:AwardBadge(player.UserId, WELCOME_BADGE_ID)
	end)
	if not okAward then
		warn("[WelcomeBadge] award failed for " .. player.Name .. ": " .. tostring(awarded))
	end
end

Players.PlayerAdded:Connect(awardWelcome)
-- handle anyone already in-game when this script starts (e.g. live script update)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(awardWelcome, player)
end
