-- GroupJoinPromptClient: when the server says so (a minute after join, for non-members), show the
-- native in-experience community-join modal. Mirrors the prompt flow used by GroupRewardChestClient:
-- GroupService:PromptJoinAsync, with a fallback to opening the group page if the prompt is
-- unavailable/declined. Only works in the LIVE game; in Studio playtests the native prompt no-ops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local GROUP_ID = 133797237

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local GroupJoinPrompt = Remotes:WaitForChild("GroupJoinPrompt")

local prompting = false
local function promptJoinGroup()
	if RunService:IsStudio() then return end
	if prompting then return end
	prompting = true

	local ok, status = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)
	prompting = false

	-- Joined / AlreadyMember are the success states; nothing more to do (no reward tied to this prompt).
	if ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember) then
		return
	end

	warn(("[GroupJoinPromptClient] PromptJoinAsync ok=%s status=%s — falling back to group page")
		:format(tostring(ok), tostring(status)))

	-- Fallback: open the community group page in the in-experience browser so they can still join.
	pcall(function()
		GuiService:OpenBrowserWindow("https://www.roblox.com/communities/" .. GROUP_ID)
	end)
end

GroupJoinPrompt.OnClientEvent:Connect(promptJoinGroup)
