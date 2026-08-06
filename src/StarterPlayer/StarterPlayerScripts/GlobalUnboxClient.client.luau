-- GlobalUnboxClient: shows a server-wide chat announcement when any player unboxes a
-- Legendary-or-above skin. Uses the modern TextChatService system message channel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local GlobalUnbox = Remotes:WaitForChild("GlobalUnbox")

-- Color3 -> "#RRGGBB" for the chat rich-text <font> tag
local function colorToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
end
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

GlobalUnbox.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	local channel = getChannel()
	if not channel then return end

	local rarityColor = KnifeSkinManager.rarityColor(data.rarity)
	local hex = colorToHex(rarityColor)
	local goldHex = "#FFD75A"  -- highlight color for the player name

	local name = escapeRich(data.playerName or data.playerUserName or "Someone")
	local skin = escapeRich(data.skinName or "a knife")
	local rarity = escapeRich(data.rarity or "")

	-- optional mutation/effect suffix (e.g. "Flames") when the skin rolled an effect
	local effectSuffix = ""
	if data.effect and data.effect ~= "none" and data.effectName and data.effectName ~= "" then
		effectSuffix = string.format(' <font color="%s">[%s]</font>', hex, escapeRich(data.effectName))
	end

	local msg = string.format(
		'<font color="%s">%s</font> unboxed a <font color="%s">%s %s</font>%s!',
		goldHex, name, hex, rarity, skin, effectSuffix
	)

	pcall(function()
		channel:DisplaySystemMessage(msg)
	end)
end)
