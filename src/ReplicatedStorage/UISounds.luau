-- UISounds: shared helper for UI sound effects + button tween animations.
-- Sounds route through the "SFX" SoundGroup so the Settings SFX slider controls volume.
-- Call UISounds.play("click"), or UISounds.bindButton(btn) for sound + hover/press tween.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UISounds = {}
local TweenController

local MAP = {
	click = "MouseClick",
	hover = "MouseHover",
	close = "CloseUI",
	error = "Error",
	select = "On67Click",
}

local function getSound(key)
	return SoundService:FindFirstChild(MAP[key] or key)
end

function UISounds.play(key)
	local template = getSound(key)
	if not template or not template:IsA("Sound") then return end
	local s = template:Clone()
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 2) + 0.1, function()
		if s then s:Destroy() end
	end)
end

function UISounds.click() UISounds.play("click") end
function UISounds.hover() UISounds.play("hover") end
function UISounds.close() UISounds.play("close") end
function UISounds.error() UISounds.play("error") end
function UISounds.select() UISounds.play("select") end

-- ===== Button tween (hover grow, press shrink) via UIScale =====
-- UIScale scales the rendered button WITHOUT changing its layout size, so it works
-- inside UIListLayouts and with any anchor/position without causing reflow or drift.
local HOVER_SCALE = 1.08
local PRESS_SCALE = 0.92
local TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function getScale(button)
	local s = button:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Scale = 1
		s.Parent = button
	end
	return s
end

local function tweenScale(scaleObj, value)
	if TweenController then
		TweenController:Play(scaleObj, TWEEN, { Scale = value }, "button-scale")
	else
		TweenService:Create(scaleObj, TWEEN, { Scale = value }):Play()
	end
end

-- Add hover/press tween animation to any GuiButton (independent of sounds).
function UISounds.SetTweenController(controller)
	TweenController = controller
end

function UISounds.bindTween(button, enabledFn)
	if not button or not button:IsA("GuiObject") then return end
	if TweenController and button:IsA("GuiButton") then
		return TweenController:BindButton(button, { enabled = enabledFn, tweenInfo = TWEEN })
	end
	local scaleObj = getScale(button)
	local hovering = false
	local function enabled() return enabledFn == nil or enabledFn() == true end
	button.MouseEnter:Connect(function() hovering = true; if enabled() then tweenScale(scaleObj, HOVER_SCALE) end end)
	button.MouseLeave:Connect(function() hovering = false; tweenScale(scaleObj, 1) end)
	button.MouseButton1Down:Connect(function() if enabled() then tweenScale(scaleObj, PRESS_SCALE) end end)
	button.MouseButton1Up:Connect(function() tweenScale(scaleObj, (enabled() and hovering) and HOVER_SCALE or 1) end)
end

-- Attach click (+ hover) sound AND tween to a GuiButton.
function UISounds.bindButton(button, opts)
	opts = opts or {}
	if not button or not button:IsA("GuiButton") then return end
	local clickKey = opts.click or "click"
	button.MouseButton1Click:Connect(function() UISounds.play(clickKey) end)
	if opts.hover ~= false then
		button.MouseEnter:Connect(function() UISounds.play("hover") end)
	end
	if opts.tween ~= false then
		UISounds.bindTween(button)
	end
end

-- Bind hover sound + tween to EVERY GuiButton under `root` (recursively).
-- Skips buttons already bound (marked via attribute) so it's safe to call alongside
-- explicit bindButton calls. Does NOT add a click sound by default (avoids conflicting
-- with purchase/close handlers); pass withClick=true to also add the click sound.
function UISounds.bindAll(root, withClick)
	if not root then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiButton") and not d:GetAttribute("UISoundsBound") then
			d:SetAttribute("UISoundsBound", true)
			d.MouseEnter:Connect(function() UISounds.play("hover") end)
			UISounds.bindTween(d)
			if withClick then
				d.MouseButton1Click:Connect(function() UISounds.play("click") end)
			end
		end
	end
end

return UISounds