-- DoubleVotePadClient: drives the "2x Map Vote" gamepass pad, mirroring ChooseMapClient's proven
-- pattern (hook the ProximityPrompt's Triggered on the CLIENT, then call PromptGamePassPurchase from
-- the client). The pad lives at Workspace.LobbyInteractives.2xMapVote.Screen.DoubleVotePrompt.
--
-- On trigger: if the player already owns the gamepass we do nothing (no pointless re-prompt);
-- otherwise we open the Roblox gamepass purchase prompt. The actual "votes count x2" weighting is
-- applied server-side in VotingManager (it checks ownership of this gamepass), and the server
-- DoubleVotePad script refreshes that ownership the moment a purchase completes.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local player = Players.LocalPlayer
local GAMEPASS_ID = Constants.Gamepasses.DOUBLE_VOTE  -- "2x Map Vote"

local function ownsPass()
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
	end)
	return ok and result or false
end

local function findPrompt()
	local folder = Workspace:FindFirstChild("LobbyInteractives")
	local model = folder and folder:FindFirstChild("2xMapVote")
	local screen = model and model:FindFirstChild("Screen")
	return screen and screen:FindFirstChild("DoubleVotePrompt")
end

local function hookPrompt()
	local prompt = findPrompt()
	if not prompt then return false end
	if prompt:GetAttribute("DVHooked") then return true end
	prompt:SetAttribute("DVHooked", true)
	prompt.Triggered:Connect(function(plr)
		if plr ~= player then return end
		if ownsPass() then
			return  -- already owned: weighting is already active for them, nothing to buy
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_ID)
		end)
		if not ok then
			warn("[DoubleVotePadClient] PromptGamePassPurchase failed: " .. tostring(err))
		end
	end)
	return true
end

-- the prompt is a persistent instance, but streaming/replication can mean it isn't present the instant
-- this script runs -- retry a few times like ChooseMapClient does for its prompt.
task.spawn(function()
	for _ = 1, 30 do
		if hookPrompt() then break end
		task.wait(1)
	end
end)