-- GroupJoinPromptServer: a minute after a player joins, if they are NOT in the community group,
-- tell their client to show the native group-join prompt. No persistence and no "first time" flag --
-- it simply checks group membership on each join and prompts non-members. Members are never prompted.
-- Mirrors the membership check + prompt the GroupRewardChest uses (same GROUP_ID, same client API).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GROUP_ID = 133797237        -- "Blend In Or Die" community group (same as the reward chest)
local PROMPT_DELAY = 30           -- seconds after join before prompting (30 seconds)

-- remote: server -> client "show the group-join prompt"
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local GroupJoinPrompt = Remotes:FindFirstChild("GroupJoinPrompt")
if not GroupJoinPrompt then
	GroupJoinPrompt = Instance.new("RemoteEvent")
	GroupJoinPrompt.Name = "GroupJoinPrompt"
	GroupJoinPrompt.Parent = Remotes
end

-- Check membership (async/fresh so a player who joined the group very recently is seen as a member),
-- then, only if they're NOT a member, prompt them after the delay. We re-check membership right
-- before prompting too, in case they joined the group during that wait (e.g. via the chest).
local function handlePlayer(player)
	-- initial membership check
	local okGroup, inGroup = pcall(function()
		return player:IsInGroupAsync(GROUP_ID)
	end)
	if not okGroup then
		-- couldn't verify membership (web error) -> do nothing this session, fail safe (no prompt)
		return
	end
	if inGroup then return end  -- already a member: never prompt

	task.delay(PROMPT_DELAY, function()
		-- player may have left during the wait
		if not player.Parent then return end
		-- re-check: they might have joined the group during the wait
		local okRecheck, nowInGroup = pcall(function()
			return player:IsInGroupAsync(GROUP_ID)
		end)
		if okRecheck and nowInGroup then return end  -- joined in the meantime: don't prompt
		GroupJoinPrompt:FireClient(player)
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(handlePlayer, plr)
end
Players.PlayerAdded:Connect(function(plr)
	task.spawn(handlePlayer, plr)
end)
