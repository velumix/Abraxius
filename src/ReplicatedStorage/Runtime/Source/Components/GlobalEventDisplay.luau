local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local RarityUtil = require(Modules.RarityUtil)
local UIColors = require(Modules.UI.UIColors)
local UIFactory = require(Modules.UI.UIFactory)

local DISCOVERY_TYPES = {
	"Vertebrates",
	"Invertebrates",
	"Corals and Plants",
}

local PIXELS_PER_MINUTE = 12
local TIMELINE_HOURS = 4
local TIMELINE_WIDTH = TIMELINE_HOURS * 60 * PIXELS_PER_MINUTE
local UPDATE_INTERVAL = 0.25
local TIMELINE_HEADER_WIDTH = 150

local RARITY_COLORS = {
	Mythic = Color3.fromRGB(255, 90, 205),
	Mythical = Color3.fromRGB(255, 90, 205),
	Legendary = Color3.fromRGB(255, 170, 0),
	Epic = Color3.fromRGB(160, 90, 240),
	Rare = Color3.fromRGB(45, 160, 225),
	Uncommon = Color3.fromRGB(60, 200, 150),
	Common = Color3.fromRGB(180, 190, 205),
}

local GlobalEventDisplay = Mince.Component({
	Tag = "EventDisplay",
})

local function getTimezoneOffsetSeconds()
	local localTime = os.time(os.date("*t"))
	local utcTime = os.time(os.date("!*t"))
	return localTime - utcTime
end

local function formatDuration(seconds)
	seconds = math.max(math.floor(seconds), 0)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = seconds % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, remainingSeconds)
	end
	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function setText(label, text)
	if label and label.Text ~= text then
		label.Text = text
	end
end

local function escapeRichText(text)
	return string.gsub(text, "[&<>'\"]", {
		["&"] = "&amp;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		["'"] = "&apos;",
		['"'] = "&quot;",
	})
end

local function colorToHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

local function formatCountdownRichText(seconds)
	local duration = formatDuration(seconds)
	local prefix, finalDigits = string.match(duration, "^(.*:)(%d%d)$")
	if not prefix then
		return "<b>" .. duration .. "</b>"
	end
	return string.format('<b>%s</b><font size="27" color="#FFD37A">%s</font>', prefix, finalDigits)
end

local function addTextShimmer(owner, label, name, edgeColor, duration)
	local gradient = Instance.new("UIGradient")
	gradient.Name = name
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, edgeColor),
		ColorSequenceKeypoint.new(0.43, edgeColor),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.57, edgeColor),
		ColorSequenceKeypoint.new(1, edgeColor),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = label

	local tween = TweenService:Create(
		gradient,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ Offset = Vector2.new(1, 0) }
	)
	table.insert(owner.VisualTweens, tween)
	tween:Play()
end

function GlobalEventDisplay:_getServerNowUtc()
	local controller = self.Controller
	if controller and controller.ServerTimeUTC and controller.ServerTimeReceivedAt then
		return controller.ServerTimeUTC + (time() - controller.ServerTimeReceivedAt)
	end
	return os.time(os.date("!*t"))
end

function GlobalEventDisplay:_connect(signal, callback)
	if not signal then
		return nil
	end

	local connection = signal:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

function GlobalEventDisplay:Construct()
	self.Connections = {}
	self.VisualTweens = {}
	self.Controller = Mince:Get("PhenomenonController")
	self.DiscoveryManager = Mince:Get("DiscoveryManager")
	self.TimezoneOffsetSeconds = getTimezoneOffsetSeconds()
	self._nextUpdateTime = 0
	self._activePhenomenon = nil

	self:BuildInterface()
	self:_requestDiscoveries()

	if self.DiscoveryManager and self.DiscoveryManager.DiscoveryUpdated then
		self:_connect(self.DiscoveryManager.DiscoveryUpdated, function()
			self:RefreshLabels()
		end)
	end

	if self.Controller and self.Controller.TimelineChanged then
		self:_connect(self.Controller.TimelineChanged, function()
			self:RebuildTimeline()
		end)
	end

	self:RebuildTimeline()
	self:_connect(RunService.Heartbeat, function()
		local now = os.clock()
		if now >= self._nextUpdateTime then
			self._nextUpdateTime = now + UPDATE_INTERVAL
			self:UpdatePlayback()
		end
	end)
end

function GlobalEventDisplay:Stop()
	for _, connection in self.Connections or {} do
		connection:Disconnect()
	end
	table.clear(self.Connections or {})
	for _, tween in self.VisualTweens or {} do
		tween:Cancel()
	end
	table.clear(self.VisualTweens or {})

	if self._nameTween then
		self._nameTween:Cancel()
		self._nameTween = nil
	end
	if self._nameTweenConnection then
		self._nameTweenConnection:Disconnect()
		self._nameTweenConnection = nil
	end
end

function GlobalEventDisplay:Destroy()
	self:Stop()
end

function GlobalEventDisplay:BuildInterface()
	local surfaceGui = self.Instance
	surfaceGui:ClearAllChildren()

	local designFolder = ReplicatedStorage:FindFirstChild("Design")
	local designSheet = designFolder and designFolder:FindFirstChild("StyleSheet")
	if designSheet and designSheet:IsA("StyleSheet") then
		local styleLink = Instance.new("StyleLink")
		styleLink.Name = "GameDesignStyle"
		styleLink.StyleSheet = designSheet
		styleLink.Parent = surfaceGui
		self.StyleLink = styleLink
	end

	local mainFrame = UIFactory.createFrame(surfaceGui, {
		Name = "MainFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 16, 29),
	}, {
		Gradient = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 24, 42)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 11, 22)),
			}),
			Rotation = 90,
		},
	})
	self.MainFrame = mainFrame

	UIFactory.createFrame(mainFrame, {
		Name = "TopAccent",
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = UIColors.Accent,
		ZIndex = 2,
	}, {
		Gradient = {
			Color = ColorSequence.new(UIColors.AccentAlt, Color3.fromRGB(88, 238, 216)),
		},
	})

	self.TitleLabel = UIFactory.createTextLabel(mainFrame, {
		Name = "Title",
		Text = '<font color="#78BAFF">CREATURE</font> ACTIVITY',
		RichText = true,
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.fromOffset(560, 34),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = UIColors.TextLight,
		TextStrokeColor3 = Color3.fromRGB(2, 8, 16),
		TextStrokeTransparency = 0.55,
	})

	UIFactory.createTextLabel(mainFrame, {
		Name = "Subtitle",
		Text = 'LIVE UPDATES  <font color="#4EDBC7">•</font>  NEXT 4 HOURS',
		RichText = true,
		Position = UDim2.fromOffset(25, 52),
		Size = UDim2.fromOffset(560, 22),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(185, 213, 232),
	})

	self.ClockLabel = UIFactory.createTextLabel(mainFrame, {
		Name = "Clock",
		Text = "--:--:--",
		Position = UDim2.new(1, -210, 0, 20),
		Size = UDim2.fromOffset(185, 34),
		Font = Enum.Font.GothamBold,
		TextSize = 30,
		TextColor3 = UIColors.AccentAlt,
		TextStrokeColor3 = Color3.fromRGB(2, 8, 16),
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	UIFactory.createTextLabel(mainFrame, {
		Name = "ClockCaption",
		Text = "LOCAL TIME",
		Position = UDim2.new(1, -220, 0, 52),
		Size = UDim2.fromOffset(195, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(185, 213, 232),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local liveCard = UIFactory.createFrame(mainFrame, {
		Name = "LiveCard",
		Position = UDim2.fromOffset(24, 92),
		Size = UDim2.new(1, -48, 0, 150),
		BackgroundColor3 = Color3.fromRGB(17, 31, 50),
	}, {
		Corner = UDim.new(0, 12),
		Stroke = {
			Color = Color3.fromRGB(54, 89, 120),
			Thickness = 1,
			Transparency = 0.25,
		},
		Gradient = {
			Color = ColorSequence.new(Color3.fromRGB(20, 42, 67), Color3.fromRGB(13, 25, 43)),
		},
	})

	self.LiveAccent = UIFactory.createFrame(liveCard, {
		Name = "Accent",
		Size = UDim2.new(0, 7, 1, 0),
		BackgroundColor3 = UIColors.Accent,
		ZIndex = 2,
	}, {
		Corner = UDim.new(0, 12),
	})

	local liveDot = UIFactory.createFrame(liveCard, {
		Name = "LiveDot",
		Position = UDim2.fromOffset(28, 24),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = UIColors.Success,
		ZIndex = 3,
	}, {
		Corner = UDim.new(1, 0),
	})

	TweenService:Create(liveDot, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundTransparency = 0.65,
	}):Play()

	self.LiveStatusLabel = UIFactory.createTextLabel(liveCard, {
		Name = "LiveStatusLabel",
		Text = '<b>NOW</b> <font color="#B9D5E8">SHOWING</font>',
		RichText = true,
		Position = UDim2.fromOffset(46, 17),
		Size = UDim2.fromOffset(140, 26),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = UIColors.Success,
	})

	self.CurrentEventName = UIFactory.createTextLabel(liveCard, {
		Name = "CurrentEventName",
		Text = "LOADING…",
		RichText = true,
		Position = UDim2.fromOffset(28, 49),
		Size = UDim2.new(1, -285, 0, 52),
		Font = Enum.Font.GothamBlack,
		TextSize = 33,
		TextColor3 = UIColors.TextLight,
		TextStrokeColor3 = Color3.fromRGB(2, 8, 16),
		TextStrokeTransparency = 0.58,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	self.LiveHintLabel = UIFactory.createTextLabel(liveCard, {
		Name = "LiveHint",
		Text = "Checking what is active right now",
		RichText = true,
		Position = UDim2.fromOffset(29, 108),
		Size = UDim2.new(1, -300, 0, 22),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(185, 213, 232),
	})

	self.RarityLabel = UIFactory.createTextLabel(liveCard, {
		Name = "Rarity",
		Text = "WAITING",
		RichText = true,
		Position = UDim2.new(1, -220, 0, 28),
		Size = UDim2.fromOffset(190, 30),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(55, 68, 86),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, {
		Corner = UDim.new(0, 8),
	})

	self.CountdownLabel = UIFactory.createTextLabel(liveCard, {
		Name = "Countdown",
		Text = "--:--",
		RichText = true,
		Position = UDim2.new(1, -235, 0, 70),
		Size = UDim2.fromOffset(205, 38),
		Font = Enum.Font.GothamBlack,
		TextSize = 38,
		TextColor3 = UIColors.Warning,
		TextStrokeColor3 = Color3.fromRGB(2, 8, 16),
		TextStrokeTransparency = 0.55,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	self.CountdownCaption = UIFactory.createTextLabel(liveCard, {
		Name = "CountdownCaption",
		Text = "STARTS IN",
		RichText = true,
		Position = UDim2.new(1, -235, 0, 109),
		Size = UDim2.fromOffset(205, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(185, 213, 232),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	self.ScheduleTitleLabel = UIFactory.createTextLabel(mainFrame, {
		Name = "ScheduleTitle",
		Text = 'WHAT’S <font color="#78BAFF">NEXT</font>',
		RichText = true,
		Position = UDim2.fromOffset(24, 258),
		Size = UDim2.fromOffset(350, 28),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = UIColors.Text,
		TextStrokeColor3 = Color3.fromRGB(2, 8, 16),
		TextStrokeTransparency = 0.65,
	})

	UIFactory.createTextLabel(mainFrame, {
		Name = "NowMarkerHint",
		Text = 'The <font color="#FF6478"><b>red line</b></font> is now',
		RichText = true,
		Position = UDim2.new(1, -330, 0, 261),
		Size = UDim2.fromOffset(305, 22),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(185, 213, 232),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local timelineCard = UIFactory.createFrame(mainFrame, {
		Name = "TimelineCard",
		Position = UDim2.fromOffset(24, 292),
		Size = UDim2.new(1, -48, 0, 230),
		BackgroundColor3 = Color3.fromRGB(13, 24, 40),
	}, {
		Corner = UDim.new(0, 12),
		Stroke = {
			Color = Color3.fromRGB(45, 72, 98),
			Thickness = 1,
			Transparency = 0.3,
		},
	})

	local headerBox = UIFactory.createFrame(timelineCard, {
		Name = "TimelineHeader",
		Size = UDim2.new(0, TIMELINE_HEADER_WIDTH, 1, 0),
		BackgroundColor3 = Color3.fromRGB(20, 37, 58),
		ZIndex = 8,
	}, {
		Corner = UDim.new(0, 12),
	})

	UIFactory.createFrame(headerBox, {
		Name = "CornerFix",
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 12, 1, 0),
		BackgroundColor3 = headerBox.BackgroundColor3,
		ZIndex = 8,
	})

	UIFactory.createTextLabel(headerBox, {
		Name = "ScheduleEyebrow",
		Text = "NEXT 4 HOURS",
		Position = UDim2.fromOffset(18, 22),
		Size = UDim2.new(1, -36, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = UIColors.AccentAlt,
	})

	UIFactory.createTextLabel(headerBox, {
		Name = "ScheduleDescription",
		Text = "UPCOMING\nCREATURES",
		Position = UDim2.fromOffset(18, 58),
		Size = UDim2.new(1, -36, 0, 78),
		Font = Enum.Font.GothamBlack,
		TextSize = 21,
		TextWrapped = true,
		TextColor3 = UIColors.TextLight,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	UIFactory.createTextLabel(headerBox, {
		Name = "DiscoveryHint",
		Text = 'Discover a creature to <font color="#78BAFF"><b>reveal its name</b></font>',
		RichText = true,
		Position = UDim2.fromOffset(18, 176),
		Size = UDim2.new(1, -36, 0, 36),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(185, 213, 232),
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})

	local viewport = UIFactory.createFrame(timelineCard, {
		Name = "Viewport",
		Position = UDim2.fromOffset(TIMELINE_HEADER_WIDTH, 0),
		Size = UDim2.new(1, -TIMELINE_HEADER_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})
	self.Viewport = viewport

	local content = UIFactory.createFrame(viewport, {
		Name = "Content",
		Size = UDim2.new(0, TIMELINE_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	})
	self.Content = content

	self.TicksLayer = UIFactory.createFrame(content, {
		Name = "Ticks",
		Size = UDim2.new(1, 0, 0, 43),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 3,
	})

	self.BlocksLayer = UIFactory.createFrame(content, {
		Name = "Blocks",
		Position = UDim2.fromOffset(0, 43),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 4,
	})

	local marker = UIFactory.createFrame(viewport, {
		Name = "NowMarker",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = UIColors.Error,
		ZIndex = 11,
	}, {
		Stroke = {
			Thickness = 1,
			Color = Color3.new(1, 1, 1),
			Transparency = 0.45,
		},
	})

	TweenService:Create(marker, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundTransparency = 0.55,
	}):Play()

	UIFactory.createTextLabel(mainFrame, {
		Name = "NetworkStatus",
		Text = 'TIMES ARE LOCAL  <font color="#4EDBC7">•</font>  SCHEDULE UPDATES AUTOMATICALLY',
		RichText = true,
		Position = UDim2.fromOffset(24, 547),
		Size = UDim2.new(1, -48, 0, 25),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(166, 198, 220),
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	addTextShimmer(self, self.TitleLabel, "ScreenSweep", Color3.fromRGB(110, 185, 235), 4.2)
	addTextShimmer(self, self.LiveStatusLabel, "LiveSweep", Color3.fromRGB(64, 205, 185), 2.8)
	addTextShimmer(self, self.CurrentEventName, "CreatureSweep", Color3.fromRGB(190, 200, 215), 3.6)
	addTextShimmer(self, self.CountdownLabel, "CountdownSweep", Color3.fromRGB(235, 165, 60), 2.4)
	addTextShimmer(self, self.ScheduleTitleLabel, "SectionSweep", Color3.fromRGB(100, 165, 220), 4.8)
end

function GlobalEventDisplay:RefreshLabels()
	for _, blockData in self.PhenomenonBlocks or {} do
		local phenomenon = blockData.Phenomenon
		if phenomenon and blockData.NameLabel then
			local displayName = self:_getDisplayName(phenomenon.Data)
			if phenomenon == self._activePhenomenon then
				displayName = phenomenon.Data.Name
			end
			setText(blockData.NameLabel, displayName)
		end
	end
end

function GlobalEventDisplay:_clearTimeline()
	for _, blockData in self.PhenomenonBlocks or {} do
		if blockData.Block then
			blockData.Block:Destroy()
		end
	end
	self.PhenomenonBlocks = {}
	self.BlockLookup = {}

	if self.TicksLayer then
		self.TicksLayer:ClearAllChildren()
	end
end

function GlobalEventDisplay:RebuildTimeline()
	if not self.Content then
		return
	end

	self:_clearTimeline()

	local timeline = (self.Controller and self.Controller.Timeline) or {}
	local offset = self.TimezoneOffsetSeconds or getTimezoneOffsetSeconds()
	self.ReferenceTime = timeline[1] and (timeline[1].HourStartTime + offset)
	if not self.ReferenceTime then
		local now = self:_getServerNowUtc() + offset
		self.ReferenceTime = now - (now % 3600)
	end

	local events = {}
	for _, hour in ipairs(timeline) do
		for _, phenomenon in ipairs(hour.Phenomena or {}) do
			table.insert(events, {
				StartTime = phenomenon.StartTime + offset,
				EndTime = phenomenon.EndTime + offset,
				Data = phenomenon.Data,
			})
		end
	end
	table.sort(events, function(a, b)
		return a.StartTime < b.StartTime
	end)
	self.Phenomena = events

	for _, phenomenon in ipairs(events) do
		self:CreateEventBlock(phenomenon)
	end

	for halfHour = 0, TIMELINE_HOURS * 2 do
		local minutes = halfHour * 30
		local x = minutes * PIXELS_PER_MINUTE
		local tickTime = self.ReferenceTime + minutes * 60

		UIFactory.createFrame(self.TicksLayer, {
			Name = "TickLine_" .. tostring(halfHour),
			Position = UDim2.fromOffset(x, 31),
			Size = UDim2.fromOffset(1, 12),
			BackgroundColor3 = Color3.fromRGB(73, 98, 122),
			BackgroundTransparency = 0.35,
		})
		UIFactory.createTextLabel(self.TicksLayer, {
			Name = "TickLabel_" .. tostring(halfHour),
			Text = os.date("%I:%M %p", tickTime),
			Position = UDim2.fromOffset(x + 7, 7),
			Size = UDim2.fromOffset(115, 20),
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(185, 213, 232),
		})
	end

	self:UpdatePlayback()
end

function GlobalEventDisplay:CreateEventBlock(phenomenon)
	local offsetMinutes = (phenomenon.StartTime - self.ReferenceTime) / 60
	local durationMinutes = (phenomenon.EndTime - phenomenon.StartTime) / 60
	local x = offsetMinutes * PIXELS_PER_MINUTE
	local width = math.max(durationMinutes * PIXELS_PER_MINUTE - 4, 60)
	local color = self:GetRarityColor(phenomenon.Data.Rarity)
	local brightness = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	local textColor = if brightness > 0.57 then Color3.fromRGB(15, 24, 35) else Color3.new(1, 1, 1)

	local block = UIFactory.createFrame(self.BlocksLayer, {
		Name = "Block_" .. tostring(phenomenon.StartTime),
		Position = UDim2.fromOffset(x + 2, 4),
		Size = UDim2.new(0, width, 1, -8),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.06,
		ZIndex = 5,
	}, {
		Corner = UDim.new(0, 9),
		Stroke = {
			Color = Color3.new(1, 1, 1),
			Thickness = 1,
			Transparency = 0.48,
		},
	})

	UIFactory.createTextLabel(block, {
		Name = "StartTime",
		Text = os.date("%I:%M %p", phenomenon.StartTime),
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = textColor,
		TextTransparency = 0.25,
	})

	local nameLabel = UIFactory.createTextLabel(block, {
		Name = "CreatureName",
		Text = self:_getDisplayName(phenomenon.Data),
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 1, -42),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.72,
		TextColor3 = textColor,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ClipsDescendants = true,
	})

	local entry = {
		Phenomenon = phenomenon,
		Block = block,
		NameLabel = nameLabel,
		Stroke = block:FindFirstChildOfClass("UIStroke"),
	}
	table.insert(self.PhenomenonBlocks, entry)
	self.BlockLookup[phenomenon] = entry
end

function GlobalEventDisplay:_setActiveBlock(phenomenon)
	if self._activePhenomenon == phenomenon then
		return
	end

	local previous = self.BlockLookup and self.BlockLookup[self._activePhenomenon]
	if previous then
		previous.Block.BackgroundTransparency = 0.06
		if previous.Stroke then
			previous.Stroke.Thickness = 1
			previous.Stroke.Transparency = 0.48
		end
	end

	self._activePhenomenon = phenomenon
	local current = self.BlockLookup and self.BlockLookup[phenomenon]
	if current then
		current.Block.BackgroundTransparency = 0
		if current.Stroke then
			current.Stroke.Thickness = 3
			current.Stroke.Transparency = 0
		end
		setText(current.NameLabel, phenomenon.Data.Name)
	end

	self:RefreshLabels()
end

function GlobalEventDisplay:UpdatePlayback()
	if not self.ReferenceTime or not self.Content then
		return
	end

	local offset = self.TimezoneOffsetSeconds or getTimezoneOffsetSeconds()
	local nowUtc = self:_getServerNowUtc()
	local now = nowUtc + offset
	setText(self.ClockLabel, os.date("%H:%M:%S", now))

	local elapsedMinutes = (now - self.ReferenceTime) / 60
	self.Content.Position = UDim2.fromOffset(-elapsedMinutes * PIXELS_PER_MINUTE, 0)

	local active = nil
	for _, phenomenon in ipairs(self.Phenomena or {}) do
		if now >= phenomenon.StartTime and now < phenomenon.EndTime then
			active = phenomenon
			break
		end
	end

	self:_setActiveBlock(active)
	if active then
		local data = active.Data
		local color = self:GetRarityColor(data.Rarity)
		self:UpdateCurrentEvent(data.Name, color)
		setText(self.RarityLabel, "<b>" .. escapeRichText(string.upper(data.Rarity or "PHENOMENON")) .. "</b>")
		self.RarityLabel.BackgroundColor3 = color
		self.LiveAccent.BackgroundColor3 = color
		setText(self.CountdownLabel, formatCountdownRichText(active.EndTime - now))
		setText(self.CountdownCaption, "ENDS IN")
		setText(self.LiveHintLabel, "Currently visible <b>in the aquarium</b>")
	else
		local upcoming = nil
		for _, phenomenon in ipairs(self.Phenomena or {}) do
			if phenomenon.StartTime > now then
				upcoming = phenomenon
				break
			end
		end

		self:UpdateCurrentEvent("NOTHING ACTIVE RIGHT NOW", Color3.fromRGB(150, 165, 180))
		setText(self.RarityLabel, "<b>WAITING</b>")
		self.RarityLabel.BackgroundColor3 = Color3.fromRGB(55, 68, 86)
		self.LiveAccent.BackgroundColor3 = UIColors.Accent
		setText(self.CountdownLabel, upcoming and formatCountdownRichText(upcoming.StartTime - now) or "<b>--:--</b>")
		setText(self.CountdownCaption, upcoming and "STARTS IN" or "UPDATING SCHEDULE")
		setText(self.LiveHintLabel, "Check back in a moment")
	end
end

function GlobalEventDisplay:UpdateCurrentEvent(text, color)
	if self._currentTargetText == text then
		return
	end
	self._currentTargetText = text

	if self._nameTween then
		self._nameTween:Cancel()
	end
	if self._nameTweenConnection then
		self._nameTweenConnection:Disconnect()
		self._nameTweenConnection = nil
	end

	local fadeOut = TweenService:Create(self.CurrentEventName, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
	})
	self._nameTween = fadeOut
	self._nameTweenConnection = fadeOut.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		self._nameTweenConnection:Disconnect()
		self._nameTweenConnection = nil
		local visibleCharacters = utf8.len(text) or #text
		self.CurrentEventName.Text =
			string.format('<b><font color="%s">%s</font></b>', colorToHex(color), escapeRichText(text))
		self.CurrentEventName.TextColor3 = Color3.new(1, 1, 1)
		self.CurrentEventName.MaxVisibleGraphemes = 0
		local revealDuration = math.clamp(visibleCharacters * 0.025, 0.28, 0.8)
		local fadeIn =
			TweenService:Create(self.CurrentEventName, TweenInfo.new(revealDuration, Enum.EasingStyle.Quad), {
				TextTransparency = 0,
				MaxVisibleGraphemes = visibleCharacters,
			})
		self._nameTween = fadeIn
		fadeIn:Play()
	end)
	fadeOut:Play()
end

function GlobalEventDisplay:GetRarityColor(rarity)
	if RARITY_COLORS[rarity] then
		return RARITY_COLORS[rarity]
	end

	local rarityInfo = RarityUtil.GetRarity(rarity)
	if rarityInfo then
		if rarityInfo.PrimaryColor then
			return rarityInfo.PrimaryColor
		end
		if rarityInfo.Data and rarityInfo.Data.PrimaryColor then
			return rarityInfo.Data.PrimaryColor
		end
	end

	return RARITY_COLORS.Rare
end

function GlobalEventDisplay:_requestDiscoveries()
	if not self.DiscoveryManager or not self.DiscoveryManager.RequestDiscoveries then
		return
	end

	for _, discoveryType in ipairs(DISCOVERY_TYPES) do
		self.DiscoveryManager:RequestDiscoveries(discoveryType)
	end
end

function GlobalEventDisplay:_isDiscovered(eventInfo)
	if not self.DiscoveryManager or not eventInfo then
		return false
	end

	local id = eventInfo.ScanId or eventInfo.Id or eventInfo.Identifier or eventInfo.Name
	if not id then
		return false
	end

	local types = DISCOVERY_TYPES
	if self.DiscoveryManager.GetDiscoveryTypes then
		types = self.DiscoveryManager:GetDiscoveryTypes()
	end

	for _, discoveryType in ipairs(types) do
		if self.DiscoveryManager:HasDiscovered(discoveryType, id) then
			return true
		end
	end

	return false
end

function GlobalEventDisplay:_getDisplayName(eventInfo)
	if self:_isDiscovered(eventInfo) then
		return eventInfo.Name
	end
	return "UNKNOWN CREATURE"
end

return GlobalEventDisplay
