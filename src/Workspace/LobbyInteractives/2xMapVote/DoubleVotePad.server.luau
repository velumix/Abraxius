-- DoubleVotePad (SERVER): the "2x Map Vote" gamepass post-purchase hook. The PROMPT trigger + the
-- PromptGamePassPurchase call are handled CLIENT-side in StarterPlayerScripts.DoubleVotePadClient
-- (mirroring how ChooseMapClient drives the ChooseMap prompt). This server script's only job is to
-- listen for a completed purchase of this gamepass and tell VotingManager to re-check the buyer's
-- ownership, so their next map vote immediately counts double (no rejoin needed). The vote weighting
-- itself lives in VotingManager (it checks ownership of this same gamepass; see weightFor/castVote).

local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VotingManager = require(ServerScriptService:WaitForChild("VotingManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local GAMEPASS_ID = Constants.Gamepasses.DOUBLE_VOTE  -- "2x Map Vote"

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
	if passId ~= GAMEPASS_ID or not purchased then return end
	-- tell VotingManager to re-check ownership so this player's votes immediately weight x2
	local ok = pcall(function() VotingManager.refreshVoteGamepass(plr) end)
	if not ok then
		warn("[DoubleVotePad] VotingManager.refreshVoteGamepass failed for " .. plr.Name)
	end
end)

print("[DoubleVotePad] ready (server: post-purchase refresh)")
