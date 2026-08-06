-- TrollBroadcastClient: a public, screen-wide toast shown to EVERYONE when a player trolls a seeker:
--   "<Buyer> trolled <Target> with <Effect>!"
-- Display is handled by the centralized NotificationController; this script only builds the message.
-- Driven by the server's TrollBroadcast RemoteEvent (TrollService:FireAllClients). This is separate
-- from the red "you've been trolled" banner that only the target/buyer see (TrollBannerClient).

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Knit = require(ReplicatedStorage.Packages.Knit)

const Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
const TrollBroadcast = Remotes:WaitForChild("TrollBroadcast")

-- colors: buyer green-ish, target red-ish, effect amber -- the rest white.
const BUYER_COLOR = "#7CE08A"
const TARGET_COLOR = "#FF8A8A"
const EFFECT_COLOR = "#FFD24A"

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

local function richEscape(s)
	s = tostring(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function showBroadcast(buyerName, targetName, effectName)
	if type(buyerName) ~= "string" or buyerName == "" then return end
	targetName = targetName or "someone"
	effectName = effectName or "a troll"
	local plain = string.format("%s trolled %s with %s!", buyerName, targetName, effectName)
	local rich = string.format(
		'<font color="%s">%s</font> <font color="#FFFFFF">trolled</font> <font color="%s">%s</font> <font color="#FFFFFF">with</font> <font color="%s">%s</font><font color="#FFFFFF">!</font>',
		BUYER_COLOR, richEscape(buyerName),
		TARGET_COLOR, richEscape(targetName),
		EFFECT_COLOR, richEscape(effectName))
	local nc = notifier()
	if nc then
		nc:Notify({ text = plain, rich = rich })
	end
end

TrollBroadcast.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	showBroadcast(data.buyer, data.target, data.effect)
end)
