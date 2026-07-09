--!strict
-- Abraxius Studio Companion Plugin
-- Modern, information-dense companion panel for the Abraxius MCP bridge.

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Logger = require(script.Logger)

local PLUGIN_URL = "http://localhost:13471"
local POLL_INTERVAL = 0.5
local EVENT_LIMIT = 64

local plugin = plugin
if not plugin then
	print("❌ DISCONNECT │ No plugin global found; this script must run as a plugin.")
	return
end

-- State ----------------------------------------------------------------------
local sessionId: string? = nil
local connected = false
local commandHandlers: { [string]: (payload: any) -> any } = {}
local eventQueue: { any } = {}
local recentEvents: { any } = {}
local sourceConnections: { [Instance]: RBXScriptConnection } = {}
local lastReportedSource: { [string]: string } = {}
local subscriptions: { [string]: boolean } = {
	source_changed = true,
	selection_changed = true,
}
local lastHeartbeat = 0
local lastLatencyMs = 0
local loopStopped = false

-- UI references --------------------------------------------------------------
local widget: DockWidgetPluginGui? = nil
local ui = {
	statusDot = nil :: Frame?,
	statusText = nil :: TextLabel?,
	sessionId = nil :: TextLabel?,
	mode = nil :: TextLabel?,
	latency = nil :: TextLabel?,
	watched = nil :: TextLabel?,
	queued = nil :: TextLabel?,
	errorLabel = nil :: TextLabel?,
	eventList = nil :: ScrollingFrame?,
	eventListLayout = nil :: UIListLayout?,
}

-- Helpers --------------------------------------------------------------------
local function getModePayload(): any
	return {
		isEdit = RunService:IsEdit(),
		isRunning = RunService:IsRunning(),
		currentDataModel = if RunService:IsEdit() then "Edit" elseif RunService:IsRunning() then "Play" else "Unknown",
		placeId = game.PlaceId,
	}
end

local function post(path: string, payload: any): (boolean, any)
	local ok, result = pcall(function()
		return HttpService:RequestAsync({
			Url = PLUGIN_URL .. path,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)
	if not ok then
		return false, tostring(result)
	end
	if result.Success and result.Body then
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, result.Body)
		if decodeOk then
			return true, decoded
		end
	end
	return false, result.Body or "unknown"
end

local function resolvePath(path: string): Instance?
	local parts = string.split(path, ".")
	local current: Instance? = game
	for _, part in ipairs(parts) do
		if current == nil then return nil end
		if part == "game" then continue end
		current = current:FindFirstChild(part)
	end
	return current
end

local function instanceInfo(inst: Instance): any
	return {
		className = inst.ClassName,
		name = inst.Name,
		fullName = inst:GetFullName(),
		path = string.gsub(inst:GetFullName(), "^game%.", ""),
	}
end

local function eventAllowed(eventType: string): boolean
	return subscriptions[eventType] == true
end

local function rememberEvent(event: any)
	table.insert(recentEvents, 1, event)
	while #recentEvents > EVENT_LIMIT do
		table.remove(recentEvents)
	end
end

local function queueEvent(event: any)
	if typeof(event) ~= "table" then return end
	if not event.type or eventAllowed(event.type) then
		rememberEvent(event)
		table.insert(eventQueue, event)
	end
end

-- UI styling -----------------------------------------------------------------
local PALETTE = {
	bg = Color3.fromRGB(22, 24, 28),
	card = Color3.fromRGB(32, 35, 41),
	cardHover = Color3.fromRGB(40, 44, 52),
	stroke = Color3.fromRGB(48, 53, 63),
	text = Color3.fromRGB(230, 236, 245),
	textDim = Color3.fromRGB(160, 168, 182),
	accent = Color3.fromRGB(0, 176, 255),
	accentGlow = Color3.fromRGB(0, 132, 209),
	green = Color3.fromRGB(94, 223, 148),
	red = Color3.fromRGB(255, 120, 120),
	yellow = Color3.fromRGB(255, 209, 102),
	magenta = Color3.fromRGB(215, 130, 255),
}

local function styleFrame(frame: GuiObject, isCard: boolean?)
	frame.BackgroundColor3 = if isCard then PALETTE.card else PALETTE.bg
	frame.BorderSizePixel = 0
	if isCard then
		local stroke = Instance.new("UIStroke")
		stroke.Color = PALETTE.stroke
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
	end
end

local function constrainSize(parent: Instance, minX: number?, minY: number?, maxX: number?, maxY: number?): UISizeConstraint
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(minX or 0, minY or 0)
	constraint.MaxSize = Vector2.new(maxX or math.huge, maxY or math.huge)
	constraint.Parent = parent
	return constraint
end

local function createText(parent: Instance, text: string, height: number, textSize: number, bold: boolean?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = if bold then Enum.Font.SourceSansBold else Enum.Font.SourceSans
	label.Text = text
	label.TextColor3 = color or PALETTE.text
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = parent
	return label
end

local function createButton(parent: Instance, text: string): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = PALETTE.card
	button.BorderSizePixel = 0
	button.Font = Enum.Font.SourceSansBold
	button.Text = text
	button.TextColor3 = PALETTE.text
	button.TextSize = 13
	button.TextWrapped = false
	button.Size = UDim2.fromScale(1, 1)
	constrainSize(button, 90, 32)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = PALETTE.stroke
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = PALETTE.cardHover }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Color = PALETTE.accent }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = PALETTE.card }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Color = PALETTE.stroke }):Play()
	end)
	button.Parent = parent
	return button
end

local function createToggle(parent: Instance, label: string, initial: boolean, callback: (boolean) -> ()): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0.3)
	constrainSize(frame, 0, 28)
	local text = createText(frame, label, 0, 14, false, PALETTE.textDim)
	text.Position = UDim2.fromScale(0.04, 0)
	text.Size = UDim2.fromScale(0.72, 1)
	text.TextWrapped = false
	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = if initial then PALETTE.green else PALETTE.red
	knob.Size = UDim2.fromScale(0.16, 0.68)
	knob.Position = UDim2.fromScale(0.8, 0.16)
	constrainSize(knob, 38, 18, 54, 24)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = knob
	knob.Parent = frame
	local enabled = initial
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			enabled = not enabled
			callback(enabled)
			TweenService:Create(knob, TweenInfo.new(0.15), { BackgroundColor3 = if enabled then PALETTE.green else PALETTE.red }):Play()
		end
	end)
	frame.Parent = parent
	return frame
end

-- Event feed -----------------------------------------------------------------
local function eventColor(eventType: string): Color3
	if eventType == "source_changed" then return PALETTE.accent end
	if eventType == "selection_changed" then return PALETTE.yellow end
	if eventType == "command_responses" then return PALETTE.green end
	if eventType == "error" then return PALETTE.red end
	return PALETTE.textDim
end

local function formatEvent(event: any): (string, string)
	if typeof(event) ~= "table" then
		return "unknown", ""
	end
	local t = tostring(event.type or "event")
	if t == "source_changed" then
		return t, tostring(event.path or "?")
	end
	if t == "selection_changed" then
		local paths = event.paths or {}
		return t, if #paths == 0 then "none" else table.concat(paths, ", ")
	end
	if t == "command_responses" then
		return t, tostring(#(event.responses or {})) .. " responses"
	end
	return t, tostring(event.path or "")
end

local function refreshEventList()
	local list = ui.eventList
	if not list then return end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i = 1, math.min(#recentEvents, 24) do
		local event = recentEvents[i]
		local row = Instance.new("Frame")
		row.BackgroundColor3 = PALETTE.card
		row.Size = UDim2.fromScale(0.98, 0.18)
		constrainSize(row, 0, 42)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row
		local stroke = Instance.new("UIStroke")
		stroke.Color = PALETTE.stroke
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = row
		local indicator = Instance.new("Frame")
		indicator.BackgroundColor3 = eventColor(event.type)
		indicator.Size = UDim2.fromScale(0.015, 0.72)
		indicator.Position = UDim2.fromScale(0.02, 0.14)
		local ic = Instance.new("UICorner")
		ic.CornerRadius = UDim.new(1, 0)
		ic.Parent = indicator
		indicator.Parent = row
		local t, detail = formatEvent(event)
		local typeLabel = createText(row, t, 0, 13, true, eventColor(event.type))
		typeLabel.Position = UDim2.fromScale(0.07, 0.04)
		typeLabel.Size = UDim2.fromScale(0.9, 0.42)
		local detailLabel = createText(row, detail, 0, 12, false, PALETTE.textDim)
		detailLabel.Position = UDim2.fromScale(0.07, 0.48)
		detailLabel.Size = UDim2.fromScale(0.9, 0.42)
		detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
		row.Parent = list
		row.BackgroundTransparency = 1
		TweenService:Create(row, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
	end
	if ui.eventListLayout then
		list.CanvasSize = UDim2.new(0, 0, 0, ui.eventListLayout.AbsoluteContentSize.Y + 8)
	end
end

-- Panel update ---------------------------------------------------------------
local function updatePanel()
	local statusText = ui.statusText
	if statusText then
		statusText.Text = if connected then "Connected" else "Disconnected"
		statusText.TextColor3 = if connected then PALETTE.green else PALETTE.red
	end
	local dot = ui.statusDot
	if dot then
		dot.BackgroundColor3 = if connected then PALETTE.green else PALETTE.red
		local goal = { BackgroundColor3 = if connected then PALETTE.green else PALETTE.red }
		local tw = TweenService:Create(dot, TweenInfo.new(0.25), goal)
		tw:Play()
	end
	if ui.sessionId then
		ui.sessionId.Text = sessionId or "none"
	end
	if ui.mode then
		ui.mode.Text = if RunService:IsEdit() then "Edit" elseif RunService:IsRunning() then "Play" else "Unknown"
	end
	if ui.latency then
		ui.latency.Text = string.format("%d ms", lastLatencyMs)
	end
	if ui.watched then
		local count = 0
		for _ in pairs(sourceConnections) do
			count += 1
		end
		ui.watched.Text = tostring(count)
	end
	if ui.queued then
		ui.queued.Text = tostring(#eventQueue)
	end
end

-- Panel construction ---------------------------------------------------------
local function createPanel()
	local info = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		340,
		520,
		300,
		320
	)
	widget = plugin:CreateDockWidgetPluginGui("AbraxiusCompanionPanel", info)
	widget.Title = "Abraxius Companion"

	local root = Instance.new("ScrollingFrame")
	root.Name = "Root"
	root.BackgroundColor3 = PALETTE.bg
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ScrollBarThickness = 6
	root.ScrollBarImageColor3 = PALETTE.stroke
	root.CanvasSize = UDim2.fromScale(0, 0)
	root.AutomaticCanvasSize = Enum.AutomaticSize.Y
	root.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.025, 0)
	padding.PaddingBottom = UDim.new(0.025, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.018, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root

	-- Header
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.fromScale(1, 0.08)
	constrainSize(header, 0, 42)
	local title = createText(header, "Abraxius", 0, 22, true, PALETTE.text)
	title.Size = UDim2.fromScale(0.56, 1)
	title.TextWrapped = false
	local statusPill = Instance.new("Frame")
	statusPill.BackgroundColor3 = PALETTE.card
	statusPill.Size = UDim2.fromScale(0.4, 0.7)
	statusPill.Position = UDim2.fromScale(0.6, 0.15)
	constrainSize(statusPill, 120, 26)
	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(1, 0)
	pillCorner.Parent = statusPill
	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = PALETTE.stroke
	pillStroke.Thickness = 1
	pillStroke.Parent = statusPill
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = PALETTE.red
	dot.Size = UDim2.fromScale(0.08, 0.3)
	dot.Position = UDim2.fromScale(0.08, 0.35)
	local dotAspect = Instance.new("UIAspectRatioConstraint")
	dotAspect.AspectRatio = 1
	dotAspect.Parent = dot
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	local pulse = Instance.new("UIStroke")
	pulse.Color = PALETTE.red
	pulse.Thickness = 2
	pulse.Transparency = 0.6
	pulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pulse.Parent = dot
	dot.Parent = statusPill
	ui.statusDot = dot
	local statusText = createText(statusPill, "Disconnected", 0, 12, true, PALETTE.red)
	statusText.Position = UDim2.fromScale(0.22, 0)
	statusText.Size = UDim2.fromScale(0.74, 1)
	statusText.TextWrapped = false
	statusText.TextScaled = true
	ui.statusText = statusText
	statusPill.Parent = header
	header.Parent = root

	-- Info cards grid
	local cards = Instance.new("Frame")
	cards.BackgroundTransparency = 1
	cards.Size = UDim2.fromScale(1, 0.22)
	constrainSize(cards, 0, 126)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.485, 0.46)
	grid.CellPadding = UDim2.fromScale(0.03, 0.08)
	grid.FillDirectionMaxCells = 2
	grid.Parent = cards

	local function makeCard(titleText: string, valueRef: (TextLabel) -> ()): Frame
		local card = Instance.new("Frame")
		styleFrame(card, true)
		constrainSize(card, 120, 56)
		local titleLabel = createText(card, titleText, 0, 11, false, PALETTE.textDim)
		titleLabel.Position = UDim2.fromScale(0.08, 0.08)
		titleLabel.Size = UDim2.fromScale(0.84, 0.32)
		titleLabel.TextWrapped = false
		local valueLabel = createText(card, "-", 0, 15, true, PALETTE.text)
		valueLabel.Position = UDim2.fromScale(0.08, 0.42)
		valueLabel.Size = UDim2.fromScale(0.84, 0.46)
		valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
		valueRef(valueLabel)
		card.Parent = cards
		return card
	end

	makeCard("Session", function(l) ui.sessionId = l end)
	makeCard("Mode", function(l) ui.mode = l end)
	makeCard("Latency", function(l) ui.latency = l end)
	makeCard("Watched", function(l) ui.watched = l end)
	cards.Parent = root

	-- Quick stats / queue
	local queueCard = Instance.new("Frame")
	styleFrame(queueCard, true)
	queueCard.Size = UDim2.fromScale(1, 0.07)
	constrainSize(queueCard, 0, 34)
	local queueTitle = createText(queueCard, "Queued events", 0, 13, false, PALETTE.textDim)
	queueTitle.Position = UDim2.fromScale(0.04, 0)
	queueTitle.Size = UDim2.fromScale(0.58, 1)
	local queueValue = createText(queueCard, "0", 0, 17, true, PALETTE.accent)
	queueValue.Position = UDim2.fromScale(0.64, 0)
	queueValue.Size = UDim2.fromScale(0.32, 1)
	queueValue.TextXAlignment = Enum.TextXAlignment.Right
	ui.queued = queueValue
	queueCard.Parent = root

	-- Controls
	local controls = Instance.new("Frame")
	controls.BackgroundTransparency = 1
	controls.Size = UDim2.fromScale(1, 0.15)
	constrainSize(controls, 0, 82)
	local cl = Instance.new("UIListLayout")
	cl.Padding = UDim.new(0.08, 0)
	cl.Parent = controls
	local row1 = Instance.new("Frame")
	row1.BackgroundTransparency = 1
	row1.Size = UDim2.fromScale(1, 0.46)
	constrainSize(row1, 0, 36)
	local r1l = Instance.new("UIListLayout")
	r1l.FillDirection = Enum.FillDirection.Horizontal
	r1l.Padding = UDim.new(0.03, 0)
	r1l.Parent = row1
	local refreshBtn = createButton(row1, "Refresh")
	refreshBtn.Size = UDim2.fromScale(0.485, 1)
	refreshBtn.MouseButton1Click:Connect(updatePanel)
	local reconnectBtn = createButton(row1, "Reconnect")
	reconnectBtn.Size = UDim2.fromScale(0.485, 1)
	reconnectBtn.MouseButton1Click:Connect(function()
		connected = false
		sessionId = nil
		Logger.plugin("Manual reconnect requested")
	end)
	row1.Parent = controls
	local row2 = Instance.new("Frame")
	row2.BackgroundTransparency = 1
	row2.Size = UDim2.fromScale(1, 0.46)
	constrainSize(row2, 0, 36)
	local r2l = Instance.new("UIListLayout")
	r2l.FillDirection = Enum.FillDirection.Horizontal
	r2l.Padding = UDim.new(0.03, 0)
	r2l.Parent = row2
	local clearBtn = createButton(row2, "Clear events")
	clearBtn.Size = UDim2.fromScale(0.485, 1)
	clearBtn.MouseButton1Click:Connect(function()
		table.clear(recentEvents)
		refreshEventList()
		updatePanel()
	end)
	local selectionBtn = createButton(row2, "Print selection")
	selectionBtn.Size = UDim2.fromScale(0.485, 1)
	selectionBtn.MouseButton1Click:Connect(function()
		local result = commandHandlers["get_selection"]({})
		Logger.info("Selection: " .. HttpService:JSONEncode(result.selection or {}))
	end)
	row2.Parent = controls
	controls.Parent = root

	-- Subscriptions
	local subCard = Instance.new("Frame")
	styleFrame(subCard, true)
	subCard.Size = UDim2.fromScale(1, 0.16)
	constrainSize(subCard, 0, 104)
	local subTitle = createText(subCard, "Subscriptions", 0, 13, true, PALETTE.textDim)
	subTitle.Position = UDim2.fromScale(0.04, 0.02)
	subTitle.Size = UDim2.fromScale(0.92, 0.22)
	local sourceToggle = createToggle(subCard, "Source changes", true, function(enabled)
		subscriptions.source_changed = enabled
		Logger.info("Source change subscription " .. (if enabled then "enabled" else "disabled"))
	end)
	sourceToggle.Position = UDim2.fromScale(0, 0.28)
	local selToggle = createToggle(subCard, "Selection changes", true, function(enabled)
		subscriptions.selection_changed = enabled
		Logger.info("Selection change subscription " .. (if enabled then "enabled" else "disabled"))
	end)
	selToggle.Position = UDim2.fromScale(0, 0.64)
	subCard.Parent = root

	-- Last error
	local errorCard = Instance.new("Frame")
	styleFrame(errorCard, true)
	errorCard.Size = UDim2.fromScale(1, 0.09)
	constrainSize(errorCard, 0, 58)
	local errorTitle = createText(errorCard, "Last error", 0, 12, false, PALETTE.textDim)
	errorTitle.Position = UDim2.fromScale(0.04, 0.04)
	errorTitle.Size = UDim2.fromScale(0.92, 0.35)
	local errorValue = createText(errorCard, "None", 0, 13, false, PALETTE.text)
	errorValue.Position = UDim2.fromScale(0.04, 0.42)
	errorValue.Size = UDim2.fromScale(0.92, 0.5)
	errorValue.TextWrapped = true
	ui.errorLabel = errorValue
	errorCard.Parent = root

	-- Events feed
	local eventsTitle = createText(root, "Recent events", 0, 15, true, PALETTE.text)
	eventsTitle.Size = UDim2.fromScale(1, 0.04)
	constrainSize(eventsTitle, 0, 24)
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 0.23)
	constrainSize(list, 0, 150)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = PALETTE.stroke
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0.025, 0)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	ui.eventList = list
	ui.eventListLayout = listLayout
	list.Parent = root

	updatePanel()
	refreshEventList()
end

-- Command handlers ------------------------------------------------------------
commandHandlers["read_source"] = function(payload: any): any
	local inst = resolvePath(payload.path)
	if not inst then
		return { ok = false, error = "Instance not found: " .. tostring(payload.path) }
	end
	if not inst:IsA("LuaSourceContainer") then
		return { ok = false, error = "Not a script: " .. tostring(payload.path) }
	end
	return { ok = true, source = inst.Source, sourceLength = #inst.Source }
end

commandHandlers["get_selection"] = function(): any
	local selected = Selection:Get()
	local out = {}
	for _, inst in ipairs(selected) do
		table.insert(out, instanceInfo(inst))
	end
	return { ok = true, selection = out }
end

commandHandlers["get_state"] = function(): any
	return {
		ok = true,
		isEdit = RunService:IsEdit(),
		isRunning = RunService:IsRunning(),
		currentDataModel = if RunService:IsEdit() then "Edit" else "Play",
		placeId = game.PlaceId,
	}
end

commandHandlers["resolve_path"] = function(payload: any): any
	local inst = resolvePath(payload.path)
	if not inst then
		return { ok = false, error = "Not found" }
	end
	return { ok = true, instance = instanceInfo(inst) }
end

commandHandlers["subscribe"] = function(payload: any): any
	local events = payload.events or {}
	subscriptions = {}
	for _, eventName in ipairs(events) do
		subscriptions[tostring(eventName)] = true
	end
	return { ok = true, events = events }
end

commandHandlers["ping"] = function(): any
	return { ok = true, time = os.time(), connected = connected, sessionId = sessionId }
end

commandHandlers["get_watched_sources"] = function(): any
	local paths = {}
	for inst, _ in pairs(sourceConnections) do
		table.insert(paths, (string.gsub(inst:GetFullName(), "^game%.", "")))
	end
	table.sort(paths)
	return { ok = true, count = #paths, paths = paths }
end

commandHandlers["set_properties"] = function(payload: any): any
	local inst = resolvePath(payload.path)
	if not inst then
		return { ok = false, error = "Instance not found: " .. tostring(payload.path) }
	end
	local props = payload.properties or {}
	for key, value in pairs(props) do
		local ok, err = pcall(function()
			if key == "RunContext" and typeof(value) == "string" then
				local enumItem = Enum.RunContext[value]
				if enumItem then
					inst.RunContext = enumItem
				end
			else
				inst[key] = value
			end
		end)
		if not ok then
			return { ok = false, error = tostring(err) }
		end
	end
	return { ok = true }
end

commandHandlers["get_properties"] = function(payload: any): any
	local inst = resolvePath(payload.path)
	if not inst then
		return { ok = false, error = "Instance not found: " .. tostring(payload.path) }
	end
	local out = {}
	local keys = payload.properties or {}
	for _, key in ipairs(keys) do
		local ok, value = pcall(function()
			return inst[key]
		end)
		if ok then
			if key == "RunContext" and typeof(value) == "EnumItem" then
				out[key] = value.Name
			else
				out[key] = value
			end
		end
	end
	return { ok = true, properties = out }
end

local function handleCommand(cmd: any): any
	local handler = commandHandlers[cmd.type]
	if not handler then
		return { id = cmd.id, error = "Unknown command type: " .. tostring(cmd.type) }
	end
	local ok, result = pcall(handler, cmd)
	if not ok then
		return { id = cmd.id, error = tostring(result) }
	end
	return { id = cmd.id, result = result }
end

-- Source watching -----------------------------------------------------------
local function reportSourceChanged(inst: Instance)
	if not inst:IsA("LuaSourceContainer") then return end
	local path = string.gsub(inst:GetFullName(), "^game%.", "")
	local source = inst.Source
	local last = lastReportedSource[path]
	if last == source then return end
	lastReportedSource[path] = source
	queueEvent({
		type = "source_changed",
		path = path,
		sourceLength = #source,
	})
end

local function watchInstance(inst: Instance)
	if not inst:IsA("LuaSourceContainer") then return end
	if sourceConnections[inst] then return end
	local conn = inst:GetPropertyChangedSignal("Source"):Connect(function()
		reportSourceChanged(inst)
	end)
	sourceConnections[inst] = conn
	lastReportedSource[string.gsub(inst:GetFullName(), "^game%.", "")] = inst.Source
end

local function unwatchInstance(inst: Instance)
	local conn = sourceConnections[inst]
	if conn then
		conn:Disconnect()
		sourceConnections[inst] = nil
	end
	lastReportedSource[string.gsub(inst:GetFullName(), "^game%.", "")] = nil
end

local function watchService(service: Instance)
	for _, child in ipairs(service:GetDescendants()) do
		watchInstance(child)
	end
	local addedConn = service.DescendantAdded:Connect(function(child)
		watchInstance(child)
	end)
	local removedConn = service.DescendantRemoving:Connect(function(child)
		unwatchInstance(child)
	end)
	return { addedConn, removedConn }
end

local serviceWatchConnections = {}
local SERVICES_TO_WATCH = {
	"ServerScriptService",
	"ServerStorage",
	"ReplicatedStorage",
	"StarterGui",
	"StarterPlayer",
	"Workspace",
	"ReplicatedFirst",
}

local function startWatching()
	for _, name in ipairs(SERVICES_TO_WATCH) do
		local svc = game:FindFirstChild(name)
		if svc then
			local conns = watchService(svc)
			serviceWatchConnections[svc] = conns
		end
	end
end

local function stopWatching()
	for _, conns in pairs(serviceWatchConnections) do
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
	end
	serviceWatchConnections = {}
	for inst, conn in pairs(sourceConnections) do
		conn:Disconnect()
		sourceConnections[inst] = nil
	end
end

-- Selection listener ---------------------------------------------------------
local selectionConn: RBXScriptConnection? = nil
local function startSelectionListener()
	if selectionConn then return end
	selectionConn = Selection.SelectionChanged:Connect(function()
		local selected = Selection:Get()
		local paths = {}
		for _, inst in ipairs(selected) do
			table.insert(paths, (string.gsub(inst:GetFullName(), "^game%.", "")))
		end
		queueEvent({ type = "selection_changed", paths = paths })
	end)
end

local function stopSelectionListener()
	if selectionConn then
		selectionConn:Disconnect()
		selectionConn = nil
	end
end

-- Main loop ------------------------------------------------------------------
local HTTP_RESTRICTED = "Http requests can only be executed by game server"

local function isHttpRestricted(err: string): boolean
	return string.find(tostring(err), HTTP_RESTRICTED, 1, true) ~= nil
end

local function register(): boolean
	local payload = getModePayload()
	payload.version = "1.1.0"
	local ok, result = post("/plugin/register", payload)
	if ok and result and result.sessionId then
		sessionId = result.sessionId
		connected = true
		if ui.errorLabel then
			ui.errorLabel.Text = "None"
			ui.errorLabel.TextColor3 = PALETTE.text
		end
		updatePanel()
		Logger.connect("Registered with session " .. tostring(sessionId))
		return true
	end
	connected = false
	local err = tostring(result or "register failed")
	if ui.errorLabel then
		ui.errorLabel.Text = err
		ui.errorLabel.TextColor3 = PALETTE.red
	end
	if isHttpRestricted(err) then
		loopStopped = true
		Logger.info("HTTP restricted in this datamodel; companion polling stopped")
	else
		Logger.disconnect("Register failed: " .. err)
	end
	return false
end

local function runLoop()
	while true do
		if loopStopped then
			Logger.info("Companion event loop stopped")
			break
		end
		if not connected or not sessionId then
			register()
			if loopStopped then break end
			if not connected then
				task.wait(2)
				continue
			end
		end

		local eventsToSend = eventQueue
		eventQueue = {}
		local startTime = os.clock()

		local ok, result = post("/plugin/report", {
			sessionId = sessionId,
			events = eventsToSend,
			heartbeat = true,
			isEdit = RunService:IsEdit(),
			isRunning = RunService:IsRunning(),
			currentDataModel = if RunService:IsEdit() then "Edit" elseif RunService:IsRunning() then "Play" else "Unknown",
			placeId = game.PlaceId,
		})

		lastLatencyMs = math.floor((os.clock() - startTime) * 1000)
		lastHeartbeat = os.time()

		if not ok then
			local err = tostring(result)
			if isHttpRestricted(err) then
				loopStopped = true
				Logger.info("HTTP restricted in this datamodel; companion polling stopped")
				updatePanel()
				break
			end
			Logger.warn("Report failed: " .. err)
			connected = false
			sessionId = nil
			if ui.errorLabel then
				ui.errorLabel.Text = tostring(result)
				ui.errorLabel.TextColor3 = PALETTE.red
			end
			updatePanel()
			task.wait(2)
			continue
		end

		connected = true
		if ui.errorLabel then
			ui.errorLabel.Text = "None"
			ui.errorLabel.TextColor3 = PALETTE.text
		end
		if result and result.commands then
			local responses = {}
			for _, cmd in ipairs(result.commands) do
				table.insert(responses, handleCommand(cmd))
			end
			if #responses > 0 then
				table.insert(eventQueue, { type = "command_responses", responses = responses })
			end
		end

		updatePanel()
		refreshEventList()
		task.wait(POLL_INTERVAL)
	end
end

-- Init -----------------------------------------------------------------------
local function init()
	if not pcall(function() return HttpService.RequestAsync end) then
		Logger.error("HttpService.RequestAsync not available. Enable HTTP requests in Studio settings.")
		return
	end

	local toolbar = plugin:CreateToolbar("Abraxius")
	local button = toolbar:CreateButton("Companion", "Abraxius Studio Companion", "")
	createPanel()
	button.Click:Connect(function()
		if widget then
			widget.Enabled = not widget.Enabled
			updatePanel()
		end
	end)

	startWatching()
	startSelectionListener()

	plugin.Unloading:Connect(function()
		stopWatching()
		stopSelectionListener()
		if widget then
			widget:Destroy()
			widget = nil
		end
	end)

	task.spawn(runLoop)
	Logger.plugin("🎮 Companion plugin started")
end

init()
