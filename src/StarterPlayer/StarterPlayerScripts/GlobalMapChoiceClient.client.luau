-- GlobalMapChoiceClient: shows a server-wide chat announcement when any player BUYS a map at the
-- lobby Choose Map prompt ("<Player> chose <Map> as the next map!"), using the modern TextChatService
-- system message channel. Mirrors GlobalUnboxClient's colored rich-text style. Server-wide only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local GlobalMapChoice = Remotes:WaitForChild("GlobalMapChoice")

local function escapeRich(s)
	s = tostring(s)
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return s
end

-- find a channel to post the system message into (RBXGeneral is the default "general" channel)
local function getChannel()
	local channels = TextChatService:FindFirstChild("TextChannels")
	if not channels then return nil end
	return channels:FindFirstChild("RBXGeneral") or channels:FindFirstChildWhichIsA("TextChannel")
end

local GOLD_HEX = "#FFD75A"   -- player name highlight (matches the global unbox name color)
local MAP_HEX = "#6BE36B"    -- map name highlight (green)

GlobalMapChoice.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	local channel = getChannel()
	if not channel then return end

	local name = escapeRich(data.playerName or "Someone")
	local map = escapeRich(data.mapName or "a map")

	local msg = string.format(
		'<font color="%s">%s</font> chose <font color="%s">%s</font> as the next map!',
		GOLD_HEX, name, MAP_HEX, map
	)

	pcall(function()
		channel:DisplaySystemMessage(msg)
	end)
end)