-- NotificationService: server entry point for the centralized toast/announcement system.
-- The actual UI lives in the client NotificationController; this just pushes payloads to it.
--   payload = { text = "plain", rich = "<rich>"?, duration = n?, typed = bool? }
-- Announcements render as "<name>: <message>" (name colored), built client-side from { kind = "announce", ... }.

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Knit = require(ReplicatedStorage.Packages.Knit)

local NotificationService = Knit.CreateService({
	Name = "NotificationService",
	Client = {
		Show = Knit.CreateSignal(),
	},
})

local function announcePayload(name, message, opts)
	local payload = { kind = "announce", name = name, message = message }
	if type(opts) == "table" then
		payload.duration = opts.duration
		payload.nameColor = opts.nameColor
		payload.typed = opts.typed
	end
	return payload
end

-- Show a toast on one player's screen.
function NotificationService:NotifyPlayer(player, payload)
	if typeof(player) ~= "Instance" then return end
	self.Client.Show:Fire(player, payload)
end

-- Show a toast on every player's screen.
function NotificationService:Broadcast(payload)
	self.Client.Show:FireAll(payload)
end

-- Announce from a specific person to everyone -> "<name>: <message>".
-- opts = { duration = n?, nameColor = "#RRGGBB"?, typed = bool? }
function NotificationService:Announce(name, message, opts)
	self.Client.Show:FireAll(announcePayload(name, message, opts))
end

-- Announce from a specific person to a single player.
function NotificationService:AnnounceTo(player, name, message, opts)
	if typeof(player) ~= "Instance" then return end
	self.Client.Show:Fire(player, announcePayload(name, message, opts))
end

local function presetPayload(presetType, text, opts)
	local payload = { Type = presetType, Text = text }
	if type(opts) == "table" then
		payload.Duration = opts.Duration or opts.duration
		payload.Sound = opts.Sound
	end
	return payload
end

-- Preset toast (INFO/SUCCESS/ERROR/ADMIN) on one player's screen.
function NotificationService:Preset(player, presetType, text, opts)
	if typeof(player) ~= "Instance" then return end
	self.Client.Show:Fire(player, presetPayload(presetType, text, opts))
end

-- Preset toast on every player's screen.
function NotificationService:BroadcastPreset(presetType, text, opts)
	self.Client.Show:FireAll(presetPayload(presetType, text, opts))
end

-- Big banner on one player's screen. opts = { Title, Desc?, Rainbow?, Gradient?, Sound?, Hold? }.
-- Requires a TCType="Banner" element under PlayerGui.Notifications.Notifications; no-ops otherwise.
function NotificationService:Banner(player, opts)
	if typeof(player) ~= "Instance" then return end
	local payload = opts or {}
	payload.kind = "banner"
	self.Client.Show:Fire(player, payload)
end

-- Big banner on every player's screen.
function NotificationService:BroadcastBanner(opts)
	local payload = opts or {}
	payload.kind = "banner"
	self.Client.Show:FireAll(payload)
end

function NotificationService:KnitStart() end
function NotificationService:KnitInit() end

return NotificationService
