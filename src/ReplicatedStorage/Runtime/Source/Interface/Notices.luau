--[[
    Notices Module
    Handles the creation and management of notification items in the UI
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

export type NoticeConfig = {
	QueueBreak: number,
	IsEnabled: boolean,
	ClearTextUponDissapearing: boolean,
	MaximumItems: number,
	SizeIncrease: number,
	DefaultDuration: number
}

-- Constants
local DEFAULT_CONFIG: NoticeConfig = {
	QueueBreak = 0.2,
	IsEnabled = true,
	ClearTextUponDissapearing = false,
	MaximumItems = 5,
	SizeIncrease = 1.05,
	DefaultDuration = 5,
}

-- Module Dependencies
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local InterfaceHandler = Mince:Get("InterfaceHandler")
local SoundHandler = Mince:Get("SoundHandler")
local NoticeEvent = Mince:GetEvent("NoticeEvent")

local Notices = {
	QueueList = {},
	IsDisplaying = false,
	ScreenGui = nil,
	MainFrame = nil,
	NoticeFrame = nil,
	NoticeLabel = nil,
	VisibleFrameTransparency = 0,
	VisibleTextTransparency = 0,
	VisibleStrokeTransparency = 0,
	HiddenFrameTransparency = 1,
	HiddenTextTransparency = 1,
	HiddenStrokeTransparency = 1,
	Config = table.clone(DEFAULT_CONFIG)
}

local SHOW_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Utility Functions
local function modifyColor(color: Color3, modifier: {H: number?, S: number?, V: number?}): Color3
	local H, S, V = color:ToHSV()
	return Color3.fromHSV(
		H * (modifier.H or 1),
		S * (modifier.S or 1),
		V * (modifier.V or 1)
	)
end

local function createTween(object: Instance, tweenInfo: TweenInfo, properties: {[string]: any}): Tween
	return TweenService:Create(object, tweenInfo, properties)
end

local function playTween(object: Instance, info: TweenInfo, properties: {[string]: any})
	local tween = TweenService:Create(object, info, properties)
	tween:Play()
	return tween
end

function Notices:_applyEntry(entry)
	if not self.NoticeLabel then
		return
	end

	local duration = entry.duration or self.Config.DefaultDuration
	if typeof(duration) ~= "number" or duration <= 0 then
		duration = self.Config.DefaultDuration
	end
	duration = math.min(duration, 5)

	local color = entry.color or Color3.new(1, 1, 1)
	local label = self.NoticeLabel
	local frame = self.NoticeFrame

	self.ScreenGui.Enabled = true
	self.MainFrame.Visible = true
	frame.Visible = true

	frame.BackgroundTransparency = self.HiddenFrameTransparency
	label.TextTransparency = self.HiddenTextTransparency
	label.TextStrokeTransparency = self.HiddenStrokeTransparency

	label.Text = entry.text
	label.TextColor3 = color

	local stroke = label:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		stroke.Color = modifyColor(color, {V = 0.2})
	end

	if entry.sound then
		SoundHandler.PlaySound(entry.sound)
	end

	local showFrameTween = playTween(frame, SHOW_TWEEN, {BackgroundTransparency = self.VisibleFrameTransparency})
	local showTextTween = playTween(label, SHOW_TWEEN, {
		TextTransparency = self.VisibleTextTransparency,
		TextStrokeTransparency = self.VisibleStrokeTransparency,
	})

	task.wait(math.max(SHOW_TWEEN.Time, 0))

	task.wait(duration)

	local hideFrameTween = playTween(frame, HIDE_TWEEN, {BackgroundTransparency = self.HiddenFrameTransparency})
	local hideTextTween = playTween(label, HIDE_TWEEN, {
		TextTransparency = self.HiddenTextTransparency,
		TextStrokeTransparency = self.HiddenStrokeTransparency,
	})

	task.wait(math.max(HIDE_TWEEN.Time, 0))

	frame.Visible = false
	label.Text = ""
end

function Notices:_processQueue()
	if self.IsDisplaying then
		return
	end

	local entry = table.remove(self.QueueList, 1)
	if not entry then
		return
	end

	self.IsDisplaying = true
	task.spawn(function()
		local ok, err = pcall(function()
			self:_applyEntry(entry)
		end)

		if not ok then
			warn("[Notices] Failed to display entry:", err)
		end

		self.IsDisplaying = false
		local queueBreak = tonumber(self.Config.QueueBreak) or 0
		if queueBreak > 0 then
			task.wait(queueBreak)
		end
		self:_processQueue()
	end)
end

-- Public API
function Notices:CreateNotice(text: string, color: Color3?, duration: number?, sound: string?)
	if typeof(text) ~= "string" or text == "" then
		return
	end

	local entry = {
		text = text,
		color = color or Color3.new(1, 1, 1),
		duration = math.min(duration or self.Config.DefaultDuration, 5),
		sound = sound or "notifsound",
	}

	table.insert(self.QueueList, entry)
	if self.NoticeLabel then
		self:_processQueue()
	end

	return entry
end

function Notices:Error(text: string, duration: number?)
	return self:CreateNotice(text, Color3.new(1, 0.2, 0.2), duration, "error")
end

function Notices:GameStart()
	if self.NoticeLabel then
		return
	end

	local screenGui = InterfaceHandler:GetScreenGui("EventUI", true)
	local main = screenGui:WaitForChild("Main")
	local notice = main:WaitForChild("Notice")
	local label = notice:FindFirstChildWhichIsA("TextLabel")
	assert(label, "[Notices] EventUI Notice frame missing TextLabel")

	self.ScreenGui = screenGui
	self.MainFrame = main
	self.NoticeFrame = notice
	self.NoticeLabel = label

	self.VisibleFrameTransparency = notice.BackgroundTransparency
	self.VisibleTextTransparency = label.TextTransparency
	self.VisibleStrokeTransparency = label.TextStrokeTransparency

	self.HiddenFrameTransparency = math.min(1, self.VisibleFrameTransparency + 0.4)
	self.HiddenTextTransparency = 1
	self.HiddenStrokeTransparency = 1

	notice.Visible = false
	notice.BackgroundTransparency = self.HiddenFrameTransparency
	label.TextTransparency = self.HiddenTextTransparency
	label.TextStrokeTransparency = self.HiddenStrokeTransparency

	if #self.QueueList > 0 then
		self:_processQueue()
	end

	NoticeEvent.Event:Connect(function(...)
		self:CreateNotice(...)
	end)
end

function Notices:Configure(newConfig: {[string]: any})
	for key, value in newConfig do
		if Notices.Config[key] ~= nil then
			Notices.Config[key] = value
		end
	end
end

return Notices 