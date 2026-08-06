-- HiderBubbleHiderClient: hides a HIDER's bubble chat from SEEKERS.
-- Bubble chat normally appears above every speaking player's head for everyone nearby. That leaks a
-- hider's position to the seeker (they could spot the bubble and home in). This client suppresses the
-- bubble ONLY in the case that matters: when the local viewer is a Seeker and the speaker is a Hider.
-- Everyone else (hiders viewing other hiders, lobby players, seekers viewing seekers) sees bubbles
-- normally. This is purely visual/client-side; it doesn't touch the actual chat messages.
--
-- How: TextChatService.OnBubbleAdded runs on each client right before a bubble renders. We identify the
-- speaker via message.TextSource.UserId and look up roles from the server's RoleMap broadcast (the same
-- map spectate uses: in-round players -> "Hider"/"Seeker"). If viewer=Seeker and speaker=Hider, we
-- return FALSE, which tells the engine not to show the bubble at all. (Returning false is the supported
-- "suppress this bubble" signal; it only affects the bubble, never the chat window.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoleMap = Remotes:WaitForChild("RoleMap")

-- [userId] = "Hider" | "Seeker" for the in-round players, mirrored from the server's RoleMap remote.
-- Remotes turn numeric keys into strings in transit, so we normalize back to number keys (matching
-- how SpectateClient/SeekerHighlightClient read the same remote).
local roleByUserId = {}
RoleMap.OnClientEvent:Connect(function(map)
	roleByUserId = {}
	if type(map) == "table" then
		for k, v in pairs(map) do
			roleByUserId[tonumber(k) or k] = v
		end
	end
end)

-- Suppress the bubble when the local viewer is a Seeker and the speaker is a Hider.
-- IMPORTANT: return nil to allow the bubble (default), or false to hide it. We must NOT build a
-- BubbleChatMessageProperties to "hide" it -- that object has no transparency/visible property, and
-- assigning one errors inside the callback, which breaks the message (that earlier bug stopped hiders'
-- text from reaching the seeker's chat window). Returning false is clean and bubble-only.
TextChatService.OnBubbleAdded = function(message, adornee)
	-- only act while a round is live (RoleMap is cleared to {} between rounds)
	local myRole = roleByUserId[player.UserId]
	if myRole ~= "Seeker" then return nil end   -- viewer isn't a seeker -> show bubble normally

	local source = message and message.TextSource
	if not source then return nil end           -- system/announcement bubble, no speaker -> leave alone
	local speakerRole = roleByUserId[source.UserId]
	if speakerRole ~= "Hider" then return nil end  -- speaker isn't a hider -> show normally

	return false   -- viewer = Seeker, speaker = Hider: don't show the bubble (window text is unaffected)
end

print("[HiderBubbleHiderClient] ready (hides hider bubbles from seekers)")
