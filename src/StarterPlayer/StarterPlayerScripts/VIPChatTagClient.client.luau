-- VIPChatTagClient: adds a yellow [VIP] prefix to chat messages from VIP gamepass owners,
-- e.g. "[VIP] Player1: hello". TextChatService requires OnIncomingMessage to be implemented on
-- the client, so this runs here. The server marks VIP owners with an "IsVIP" attribute (set by
-- VIPManager); we read that attribute for the message's sender to decide whether to add the tag.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local TAG_COLOR = "#FFD700"  -- yellow/gold

TextChatService.OnIncomingMessage = function(message)
	local src = message.TextSource
	if not src then return end
	local sender = Players:GetPlayerByUserId(src.UserId)
	if not sender or not sender:GetAttribute("IsVIP") then return end

	local props = Instance.new("TextChatMessageProperties")
	props.PrefixText = string.format('<font color="%s">[VIP]</font> ', TAG_COLOR) .. message.PrefixText
	return props
end
