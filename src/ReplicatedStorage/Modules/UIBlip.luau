local TweenService = game:GetService("TweenService")

local UIBlip = {}
UIBlip.__index = UIBlip

local DEFAULTS = {
	Color = Color3.fromRGB(120, 230, 255),
	PulseColor = Color3.fromRGB(255, 255, 255),
	Thickness = 3,
	Transparency = 0.1,
	PulseDuration = 0.65,
	PulseThickness = 6,
}

local function resolveOption(options, key)
	if options and options[key] ~= nil then
		return options[key]
	end
	return DEFAULTS[key]
end

function UIBlip.new(target: GuiObject, options)
	if not target or not target:IsA("GuiObject") then
		return nil
	end

	local self = setmetatable({}, UIBlip)
	self.Target = target
	self.Options = options or {}
	self.Stroke = nil
	self.Tween = nil

	local stroke = target:FindFirstChild("TutorialBlipStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "TutorialBlipStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = target
	end

	stroke.Color = resolveOption(options, "Color")
	stroke.Transparency = resolveOption(options, "Transparency")
	stroke.Thickness = resolveOption(options, "Thickness")

	self.Stroke = stroke

	self:StartPulse()
	return self
end

function UIBlip:StartPulse()
	if not self.Stroke then
		return
	end

	local duration = resolveOption(self.Options, "PulseDuration")
	local pulseThickness = resolveOption(self.Options, "PulseThickness")
	local pulseColor = resolveOption(self.Options, "PulseColor")
	local baseColor = resolveOption(self.Options, "Color")
	local baseThickness = resolveOption(self.Options, "Thickness")
	local baseTransparency = resolveOption(self.Options, "Transparency")

	self.Stroke.Color = baseColor
	self.Stroke.Thickness = baseThickness
	self.Stroke.Transparency = baseTransparency

	self.Tween = TweenService:Create(
		self.Stroke,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			Thickness = pulseThickness,
			Transparency = 0,
			Color = pulseColor,
		}
	)

	self.Tween:Play()
end

function UIBlip:Destroy()
	if self.Tween then
		self.Tween:Cancel()
		self.Tween = nil
	end

	if self.Stroke then
		self.Stroke:Destroy()
		self.Stroke = nil
	end

	self.Target = nil
end

return UIBlip
