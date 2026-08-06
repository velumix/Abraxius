-- KnifeNotifyClient: shows a "[KnifeName] was added to your inventory" toast, with the knife name
-- colored by its rarity. Display is handled by the centralized NotificationController; this script
-- only builds the message and plays the per-add Reward sound.
--
-- Triggers:
--   * server grants (VIP knife, dev-product packs, etc.) -> the KnifeNotify RemoteEvent fires
--   * crate unbox -> UnboxClient fires the LOCAL BindableEvent AFTER the reveal (so it's not a
--     spoiler); the unbox grant itself is sent with notify=false on the server.

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const SoundService = game:GetService("SoundService")

const Knit = require(ReplicatedStorage.Packages.Knit)
const KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))

const Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
const KnifeNotify = Remotes:WaitForChild("KnifeNotify")  -- server -> client
const InventoryItemAdded = Remotes:WaitForChild("InventoryItemAdded")  -- server -> client: play Reward sound on every add

-- A local BindableEvent so the unbox client can trigger the toast itself (post-reveal) without
-- routing through the server.
local KnifeNotifyLocal = Remotes:FindFirstChild("KnifeNotifyLocal")
if not KnifeNotifyLocal then
	KnifeNotifyLocal = Instance.new("BindableEvent")
	KnifeNotifyLocal.Name = "KnifeNotifyLocal"
	KnifeNotifyLocal.Parent = Remotes
end

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

-- ===== rich-text color helper =====
local function toHex(c)
	return string.format("#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5))
end

-- pure-black rarities (e.g. "Secret") would be invisible on a dark UI, so brighten near-black to a
-- clearly readable light grey. The black stroke keeps the outlined "secret" look while staying legible.
local function readableColor(c)
	if c.R < 0.15 and c.G < 0.15 and c.B < 0.15 then
		return Color3.fromRGB(190, 190, 190)
	end
	return c
end

local function showNotification(knifeName, rarity)
	if type(knifeName) ~= "string" or knifeName == "" then return end
	rarity = rarity or "Common"
	local nameHex = toHex(readableColor(KnifeSkinManager.rarityColor(rarity)))
	-- "[KnifeName] was added to your inventory" with the name colored by rarity, rest in white.
	local plain = knifeName .. " was added to your inventory"
	local rich = string.format(
		'<font color="%s">%s</font> <font color="#FFFFFF">was added to your inventory</font>',
		nameHex, knifeName)
	local nc = notifier()
	if nc then
		nc:Notify({ text = plain, rich = rich })
	end
end

-- server grants (VIP, dev-product packs, anything via InventoryManager.add with notify on)
KnifeNotify.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	showNotification(data.name, data.rarity)
end)

-- play SoundService.Reward whenever an item is added to the inventory (fires on EVERY add, including
-- crate unboxes where the toast is suppressed). Clone + route through the SFX SoundGroup so the
-- Settings SFX volume slider applies, matching how the rest of the game plays one-shot effects.
InventoryItemAdded.OnClientEvent:Connect(function()
	local tmpl = SoundService:FindFirstChild("Reward")
	if not tmpl or not tmpl:IsA("Sound") then return end
	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx and sfx:IsA("SoundGroup") then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
		if s then s:Destroy() end
	end)
end)

-- local trigger (crate unbox, fired by UnboxClient AFTER the reveal)
KnifeNotifyLocal.Event:Connect(function(data)
	if type(data) ~= "table" then return end
	showNotification(data.name, data.rarity)
end)
