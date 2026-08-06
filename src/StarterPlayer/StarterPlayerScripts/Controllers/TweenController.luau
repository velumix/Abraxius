local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local UISounds = require(ReplicatedStorage.UISounds)

local TweenController = Knit.CreateController({
	Name = "TweenController",
})

local tweenInfoCache = {}
local activeTweens = setmetatable({}, { __mode = "k" })
local buttonBindings = setmetatable({}, { __mode = "k" })

local function tweenInfoKey(duration, easingStyle, easingDirection, repeatCount, reverses, delayTime)
	return table.concat({
		tostring(duration),
		easingStyle.Name,
		easingDirection.Name,
		tostring(repeatCount),
		tostring(reverses),
		tostring(delayTime),
	}, "|")
end

function TweenController:GetInfo(duration, easingStyle, easingDirection, repeatCount, reverses, delayTime)
	easingStyle = easingStyle or Enum.EasingStyle.Quad
	easingDirection = easingDirection or Enum.EasingDirection.Out
	repeatCount = repeatCount or 0
	reverses = reverses == true
	delayTime = delayTime or 0

	local key = tweenInfoKey(duration, easingStyle, easingDirection, repeatCount, reverses, delayTime)
	local tweenInfo = tweenInfoCache[key]
	if not tweenInfo then
		tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection, repeatCount, reverses, delayTime)
		tweenInfoCache[key] = tweenInfo
	end
	return tweenInfo
end

function TweenController:Play(instance, tweenInfo, properties, channel)
	if not instance or instance.Parent == nil or type(properties) ~= "table" then
		return nil
	end
	if typeof(tweenInfo) ~= "TweenInfo" then
		tweenInfo = self:GetInfo(tonumber(tweenInfo) or 0.12)
	end

	channel = channel or "default"
	local channels = activeTweens[instance]
	if not channels then
		channels = {}
		activeTweens[instance] = channels
	end
	local previous = channels[channel]
	if previous then
		previous:Cancel()
	end

	local tween = TweenService:Create(instance, tweenInfo, properties)
	channels[channel] = tween
	tween.Completed:Once(function()
		local currentChannels = activeTweens[instance]
		if currentChannels and currentChannels[channel] == tween then
			currentChannels[channel] = nil
			if next(currentChannels) == nil then
				activeTweens[instance] = nil
			end
		end
	end)
	tween:Play()
	return tween
end

function TweenController:Cancel(instance, channel)
	local channels = activeTweens[instance]
	if not channels then
		return
	end
	if channel then
		local tween = channels[channel]
		if tween then
			tween:Cancel()
			channels[channel] = nil
		end
	else
		for name, tween in pairs(channels) do
			tween:Cancel()
			channels[name] = nil
		end
	end
	if next(channels) == nil then
		activeTweens[instance] = nil
	end
end

function TweenController:GetScale(guiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = guiObject
	end
	return scale
end

function TweenController:UnbindButton(button)
	local cleanup = buttonBindings[button]
	if cleanup then
		cleanup()
	end
end

function TweenController:BindButton(button, options)
	if not button or not button:IsA("GuiButton") then
		return function() end
	end
	self:UnbindButton(button)
	options = options or {}

	local scale = self:GetScale(button)
	local tweenInfo = options.tweenInfo or self:GetInfo(options.duration or 0.12)
	local hoverScale = options.hoverScale or 1.08
	local pressScale = options.pressScale or 0.92
	local hovering = false
	local cleaned = false
	local connections = {}

	local function enabled()
		return options.enabled == nil or options.enabled() == true
	end
	local function baseScale()
		return type(options.baseScale) == "function" and options.baseScale() or (options.baseScale or 1)
	end
	local function animate(value)
		self:Play(scale, tweenInfo, { Scale = value }, "button-scale")
	end

	connections[#connections + 1] = button.MouseEnter:Connect(function()
		hovering = true
		if enabled() then
			animate(baseScale() * hoverScale)
		end
	end)
	connections[#connections + 1] = button.MouseLeave:Connect(function()
		hovering = false
		animate(baseScale())
	end)
	connections[#connections + 1] = button.MouseButton1Down:Connect(function()
		if enabled() then
			animate(baseScale() * pressScale)
		end
	end)
	connections[#connections + 1] = button.MouseButton1Up:Connect(function()
		animate((enabled() and hovering) and (baseScale() * hoverScale) or baseScale())
	end)

	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		self:Cancel(scale, "button-scale")
		buttonBindings[button] = nil
	end
	connections[#connections + 1] = button.Destroying:Connect(cleanup)
	buttonBindings[button] = cleanup
	return cleanup
end

function TweenController:KnitInit()
	UISounds.SetTweenController(self)
end

return TweenController
