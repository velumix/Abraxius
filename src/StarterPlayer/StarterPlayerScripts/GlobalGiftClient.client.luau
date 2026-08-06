-- GlobalGiftClient: handles the gift notifications (chat + on-screen toast + sounds).
--   1) CHAT ANNOUNCEMENT (everyone): "<gifter> gifted <recipient> <item>!" system chat message.
--   2) RECEIVER TOAST + SOUND (recipient only): "You got gifted <item> by <gifter>" via the centralized
--      NotificationController, plus the GiftAudios.Audio_Gift_Received chime.
--   3) SENDER SOUND (buyer only): GiftAudios.Audio_Gift_Sent once the server confirms delivery.
--
-- Driven by RemoteEvents fired from the server GiftService:
--   * GiftBroadcast (FireAllClients)              -> the chat announcement
--   * GiftReceived  (FireClient to the recipient) -> the receiver toast + received sound
--   * GiftDelivered (FireClient to the buyer)      -> the sent sound

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TextChatService = game:GetService("TextChatService")
const SoundService = game:GetService("SoundService")

const Knit = require(ReplicatedStorage.Packages.Knit)

const Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
const GiftBroadcast = Remotes:WaitForChild("GiftBroadcast")  -- server -> all: { fromName, recipientName, label }
const GiftReceived = Remotes:WaitForChild("GiftReceived")    -- server -> recipient: { fromName, label }
const GiftDelivered = Remotes:WaitForChild("GiftDelivered")  -- server -> buyer: { recipientName, label }

-- centralized toast system (lazy: wait for Knit to start before resolving the controller)
local NotificationController
local function notifier()
	if not NotificationController then
		if Knit.OnStart():await() then
			NotificationController = Knit.GetController("NotificationController")
		end
	end
	return NotificationController
end

-- ===== gift sounds =====
-- One-shot SFX live under SoundService.GiftAudios. Clone the template, route it through the SFX
-- SoundGroup (so the Settings SFX volume slider applies), play it, then clean up.
local function playGiftSound(soundName)
	local folder = SoundService:FindFirstChild("GiftAudios")
	local tmpl = folder and folder:FindFirstChild(soundName)
	if not tmpl or not tmpl:IsA("Sound") then return end
	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx and sfx:IsA("SoundGroup") then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 5) + 0.2, function()
		if s then s:Destroy() end
	end)
end

-- ===== rich-text helpers (same approach as GlobalUnboxClient) =====
const GOLD_HEX = "#FFD75A"   -- player names
const ITEM_HEX = "#7CE0FF"   -- the gifted item label
local function escapeRich(s)
	s = tostring(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- ===== 1) CHAT ANNOUNCEMENT =====
local function getChannel()
	local channels = TextChatService:FindFirstChild("TextChannels")
	if not channels then return nil end
	return channels:FindFirstChild("RBXGeneral") or channels:FindFirstChildWhichIsA("TextChannel")
end

GiftBroadcast.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	local channel = getChannel()
	if not channel then return end
	local from = escapeRich(data.fromName or "Someone")
	local to = escapeRich(data.recipientName or "someone")
	local item = escapeRich(data.label or "a gift")
	-- "<gifter> gifted <recipient> <item>!"
	local msg = string.format(
		'<font color="%s">%s</font> gifted <font color="%s">%s</font> <font color="%s">%s</font>!',
		GOLD_HEX, from, GOLD_HEX, to, ITEM_HEX, item)
	pcall(function() channel:DisplaySystemMessage(msg) end)
end)

-- ===== 2) RECEIVER TOAST =====
local function showGiftToast(itemLabel, fromName)
	itemLabel = (type(itemLabel) == "string" and itemLabel ~= "") and itemLabel or "a gift"
	fromName = (type(fromName) == "string" and fromName ~= "") and fromName or "someone"
	-- "You got gifted <item> by <player>" -- item + player colored, rest white.
	local plain = string.format("You got gifted %s by %s", itemLabel, fromName)
	local rich = string.format(
		'<font color="#FFFFFF">You got gifted</font> <font color="%s">%s</font> <font color="#FFFFFF">by</font> <font color="%s">%s</font>',
		ITEM_HEX, escapeRich(itemLabel), GOLD_HEX, escapeRich(fromName))
	local nc = notifier()
	if nc then
		nc:Notify({ text = plain, rich = rich })
	end
end

GiftReceived.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	showGiftToast(data.label, data.fromName)
	playGiftSound("Audio_Gift_Received")  -- recipient hears the "received" chime
end)

-- ===== 3) SENDER SOUND =====
-- The buyer hears the "sent" sound once the server confirms the gift was delivered (or mailboxed for an
-- offline recipient). No toast here -- the chat announcement already covers the visible confirmation.
GiftDelivered.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	playGiftSound("Audio_Gift_Sent")
end)
