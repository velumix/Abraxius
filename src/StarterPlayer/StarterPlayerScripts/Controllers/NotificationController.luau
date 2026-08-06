-- NotificationController: centralized toast/announcement system.
-- Adapted from the "Build A Ring Farm" multi-lane coordinator: a toast stack with presets
-- (INFO/SUCCESS/ERROR/ADMIN), an admin glyph + gradient, and an optional Banner lane. Renders
-- through the authored UI at PlayerGui.Notifications.Notifications (AlertFrame = the TCType="Toast"
-- container, ToastTemplate = the per-toast card). Driven locally (:Notify / :Announce / :Banner) and
-- from the server via NotificationService.Show. Backwards-compatible with the prior payloads:
--   :Notify("text")  or  :Notify({ text = "plain", rich = "<rich>"?, duration = n?, typed = bool? })
--   :Notify({ Type = "SUCCESS", Text = "..." })   -- preset form
--   :Announce(name, message, { duration?, nameColor?, typed? })

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")

const Knit = require(ReplicatedStorage.Packages.Knit)

const player = Players.LocalPlayer
const pg = player:WaitForChild("PlayerGui")

-- tunables
const MAX_VISIBLE = 3        -- toasts shown at once; the oldest is evicted past this
const HOLD = 3.0             -- seconds the toast is held on screen
const ADMIN_GLYPH = utf8.char(0xE000)

const NAME_COLOR = "#FFD75A" -- announcer-name accent (gold)
const MSG_COLOR = "#FFFFFF"

const PRESETS = {
	INFO = { duration = 3, textColor = Color3.fromRGB(255, 255, 255), strokeColor = Color3.fromRGB(36, 36, 36) },
	SUCCESS = { duration = 3, textColor = Color3.fromRGB(67, 255, 67), strokeColor = Color3.fromRGB(5, 24, 2) },
	ERROR = { duration = 3, textColor = Color3.fromRGB(255, 61, 64), strokeColor = Color3.fromRGB(24, 4, 4), sound = "SAAlert" },
	ADMIN = { duration = 10, admin = true, textColor = Color3.fromRGB(255, 255, 255), strokeColor = Color3.fromRGB(36, 36, 36), sound = "Notification" },
}

const ADMIN_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.4),
	NumberSequenceKeypoint.new(0.8, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})

const BANNER_HOLD = 4
const BANNER_SLIDE = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local NotificationController = Knit.CreateController({ Name = "NotificationController" })

-- ===== GUI refs (filled by registerElement, keyed off the TCType attribute) =====
local container        -- AlertFrame: the toast stack (TCType="Toast")
local template         -- ToastTemplate: the per-toast card
local bannerLabel      -- optional Banner element (TCType="Banner")
local bannerHomeY = 0  -- bannerLabel's authored Y scale (its slide-in target)
local bannerBaseScale = 1
local bannerBaseThickness = 0
local bannerToken = 0

local active = {}      -- live toast records (oldest first)

-- ===== sound (clone + route through the SFX SoundGroup, matching the rest of the game) =====
local function playSound(name)
	if not name then
		return
	end

	local tmpl = SoundService:FindFirstChild(name)
	if not tmpl or not tmpl:IsA("Sound") then
		return
	end

	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx and sfx:IsA("SoundGroup") then
		s.SoundGroup = sfx
	end

	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
		if s then
			s:Destroy()
		end
	end)
end

-- ===== rich-text helper =====
local function escapeRich(s)
	s = tostring(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- ===== toast pop (UIScale, matching the authored ToastTemplate) =====
local function toggleScale(instance, visible)
	local scale = instance:FindFirstChildOfClass("UIScale")
	if not scale then
		return nil
	end

	local direction = if visible then Enum.EasingDirection.Out else Enum.EasingDirection.In
	local duration = if visible then 0.25 else 0.125
	local tween = TweenService:Create(scale, TweenInfo.new(duration, Enum.EasingStyle.Back, direction), { Scale = if visible then 1 else 0 })
	tween:Play()
	return tween.Completed
end

-- ===== toast lane =====
-- opts = { text, rich?, textColor?, strokeColor?, backgroundColor?, duration?, sound?, admin?, typed? }
local function present(opts)
	local cont = container
	local tmpl = template
	if not cont or not tmpl then
		return
	end

	local entry = tmpl:Clone()
	local content = entry:FindFirstChild("Content")
	local plain = tostring(opts.text or "")

	if content then
		if opts.rich then
			content.RichText = true
			content.Text = (if opts.admin then ADMIN_GLYPH else "") .. opts.rich
		else
			content.RichText = false
			content.Text = (if opts.admin then ADMIN_GLYPH else "") .. plain
			content.TextColor3 = opts.textColor or Color3.new(1, 1, 1)
		end

		local stroke = content:FindFirstChildOfClass("UIStroke")
		if stroke and opts.strokeColor then
			stroke.Color = opts.strokeColor
		end
	end

	-- Keep toasts transparent; the text + stroke is the visible part.
	entry.BackgroundTransparency = 1

	local gradient = entry:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Transparency = if opts.admin then ADMIN_GRADIENT else NumberSequence.new(0)
	end

	local scale = entry:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0
	end

	entry.Visible = true
	entry.Parent = cont

	local duration = tonumber(opts.duration) or HOLD

	local record = {}
	local dismissed = false
	local timer

	function record.dismiss()
		if dismissed then
			return
		end

		dismissed = true
		if timer and timer ~= coroutine.running() then
			task.cancel(timer)
		end

		timer = nil

		local idx = table.find(active, record)
		if idx then
			table.remove(active, idx)
		end

		local completed = toggleScale(entry, false)
		if completed then
			completed:Once(function()
				entry:Destroy()
			end)
		else
			entry:Destroy()
		end
	end

	toggleScale(entry, true)
	playSound(opts.sound)
	timer = task.delay(duration, record.dismiss)

	table.insert(active, record)
	while #active > MAX_VISIBLE do
		local oldest = active[1]
		if oldest == record then
			break
		end

		oldest.dismiss()
	end
end

-- ===== public API =====

-- Show a toast. Accepts a bare string, the legacy { text, rich?, duration?, typed? },
-- or the preset { Type = "SUCCESS"|"ERROR"|"INFO"|"ADMIN", Text = ... } form.
function NotificationController:Notify(payload)
	if type(payload) == "string" then
		payload = { text = payload }
	end

	if type(payload) ~= "table" then
		return
	end

	local preset = if payload.Type then (PRESETS[payload.Type] or PRESETS.INFO) else nil
	present({
		text = payload.Text or payload.text or "",
		rich = payload.rich,
		duration = payload.Duration or payload.duration or (preset and preset.duration),
		textColor = payload.TextColor or (preset and preset.textColor),
		strokeColor = payload.StrokeColor or (preset and preset.strokeColor),
		backgroundColor = payload.BackgroundColor,
		sound = payload.Sound or (preset and preset.sound),
		admin = if payload.Admin ~= nil then payload.Admin else (preset and preset.admin or false),
		typed = payload.typed,
	})
end

-- Announce from a specific person -> "<name>: <message>" (name colored).
function NotificationController:Announce(name, message, opts)
	name = (type(name) == "string" and name ~= "") and name or "Someone"
	message = tostring(message or "")
	opts = opts or {}
	local nameColor = opts.nameColor or NAME_COLOR
	local plain = name .. ": " .. message
	local rich = string.format(
		'<font color="%s">%s</font>: <font color="%s">%s</font>',
		nameColor, escapeRich(name), MSG_COLOR, escapeRich(message))
	self:Notify({ text = plain, rich = rich, duration = opts.duration, typed = opts.typed })
end

-- ===== banner lane (optional; only active if a TCType="Banner" element was authored) =====
local function buildRainbowGradient()
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 60, 60)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 165, 0)),
		ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 240, 0)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(80, 230, 80)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 180, 255)),
		ColorSequenceKeypoint.new(0.84, Color3.fromRGB(160, 90, 255)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 60, 200)),
	})
	g.Rotation = 0
	return g
end

-- opts = { Title, Desc?, Gradient?, Rainbow?, ScaleMultiplier?, StrokeMultiplier?, Sound?, Hold? }
function NotificationController:Banner(opts)
	local label = bannerLabel
	if not label then
		return
	end

	opts = opts or {}
	bannerToken += 1
	local token = bannerToken

	local existing = label:FindFirstChildOfClass("UIGradient")
	if existing then
		existing:Destroy()
	end

	local gradient
	if opts.Rainbow then
		gradient = buildRainbowGradient()
	elseif opts.Gradient then
		gradient = opts.Gradient:Clone()
	end

	if gradient then
		gradient.Parent = label
		gradient:AddTag("GradientRotate")
	end

	local scale = label:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = bannerBaseScale * (opts.ScaleMultiplier or 1)
	end

	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = bannerBaseThickness * (opts.StrokeMultiplier or 1)
	end

	label.Text = opts.Title or ""
	local desc = label:FindFirstChild("Desc")
	if desc and desc:IsA("TextLabel") and opts.Desc then
		desc.Text = opts.Desc
	end

	label.Position = UDim2.new(0.5, 0, 1.5, 0)
	label.Visible = true
	TweenService:Create(label, BANNER_SLIDE, { Position = UDim2.new(0.5, 0, bannerHomeY, 0) }):Play()

	playSound(opts.Sound or "Announcement")

	task.delay(opts.Hold or BANNER_HOLD, function()
		if token ~= bannerToken then
			return
		end

		local outTween = TweenService:Create(label, BANNER_SLIDE, { Position = UDim2.new(0.5, 0, -0.5, 0) })
		outTween:Play()
		outTween.Completed:Connect(function()
			if token ~= bannerToken then
				return
			end

			label.Visible = false
			if scale then
				scale.Scale = bannerBaseScale
			end

			if stroke then
				stroke.Thickness = bannerBaseThickness
			end

			local g = label:FindFirstChildOfClass("UIGradient")
			if g then
				g:Destroy()
			end
		end)
	end)
end

-- ===== element registration (by TCType, mirrors the authored UI) =====
local function registerElement(element)
	if not element:IsA("GuiObject") then
		return
	end

	local tcType = element:GetAttribute("TCType")
	if tcType == "Toast" then
		container = element
		local layout = element:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
		-- Raise the toast stack so it doesn't overlap the round timer / hider counter.
		element.Position = UDim2.new(0.5, 0, 0.76, 0)
	elseif tcType == "Banner" then
		bannerLabel = element
		bannerHomeY = element.Position.Y.Scale
		local s = element:FindFirstChildOfClass("UIScale")
		bannerBaseScale = s and s.Scale or 1
		local st = element:FindFirstChildOfClass("UIStroke")
		bannerBaseThickness = st and st.Thickness or 0
	end
end

function NotificationController:KnitInit()
	--
end

function NotificationController:KnitStart()
	local screen = pg:WaitForChild("Notifications")
	local gui = screen:WaitForChild("Notifications")
	template = gui:WaitForChild("ToastTemplate")
	for _, element in gui:GetChildren() do
		registerElement(element)
	end

	gui.ChildAdded:Connect(registerElement)

	local notificationService = Knit.GetService("NotificationService")
	notificationService.Show:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end

		if payload.kind == "announce" then
			self:Announce(payload.name, payload.message, payload)
		elseif payload.kind == "banner" then
			self:Banner(payload)
		else
			self:Notify(payload)
		end
	end)
end

return NotificationController
