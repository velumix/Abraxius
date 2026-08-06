-- InviteFriendClient: when the local player steps onto the InviteFriendPad, prompt Roblox's
-- "Invite a Friend" UI (SocialService:PromptGameInvite must be called from the client). The
-- prompt fires once per step-on; stepping off re-arms it. The +5% friend-present XP bonus is
-- handled server-side in LevelManager.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer

-- locate the pad (a Model under StarMesh, in the central Workspace.LobbyInteractives folder).
-- With StreamingEnabled the folder exists before its children stream in, so a plain recursive
-- FindFirstChild can momentarily return nil on join; poll until StarMesh (and the pad) arrive.
local interactives = workspace:WaitForChild("LobbyInteractives", 30)
local function waitForDescendant(root, name, timeout)
	if not root then return nil end
	local found = root:FindFirstChild(name, true)
	local waited = 0
	while not found and waited < (timeout or 30) do
		task.wait(0.25); waited += 0.25
		found = root:FindFirstChild(name, true)
	end
	return found
end
local starMesh = waitForDescendant(interactives, "StarMesh", 30)
local pad = starMesh and (starMesh:FindFirstChild("InviteFriendPad") or waitForDescendant(starMesh, "InviteFriendPad", 30))

if not pad then
	warn("[InviteFriendClient] InviteFriendPad not found")
	return
end

-- the pad is a Model; use its bounding box as the trigger footprint
local padCF, padSize = pad:GetBoundingBox()
local TRIGGER_PADDING = 1  -- small leeway in studs
local halfX = padSize.X / 2 + TRIGGER_PADDING
local halfZ = padSize.Z / 2 + TRIGGER_PADDING

local function canInvite()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	return ok and can
end

local function promptInvite()
	if not canInvite() then return end
	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end

local onPad = false
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- footprint check against the pad's X/Z bounds
	local localPos = padCF:PointToObjectSpace(hrp.Position)
	local nowOnPad = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ

	if nowOnPad and not onPad then
		onPad = true
		promptInvite()
	elseif not nowOnPad and onPad then
		onPad = false  -- re-arm so stepping on again prompts again
	end
end)
