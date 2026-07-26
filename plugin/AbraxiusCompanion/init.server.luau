--!strict
-- Abraxius Studio Companion Plugin
-- Modern, information-dense companion panel by VELUMIX(TM).

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StudioService = game:GetService("StudioService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local LogService = game:GetService("LogService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local EncodingService = game:GetService("EncodingService")
local SerializationService = game:GetService("SerializationService")
local Logger = require(script.Logger)

local PLUGIN_URL = "http://localhost:13471"
local ANALYTICS_URL = "http://localhost:13472"
local PLUGIN_VERSION = "1.8.1"
local POLL_INTERVAL = 0.5
local EVENT_LIMIT = 64
local CONTEXT_SNAPSHOT_INTERVAL = 10
local ANALYTICS_INTERVAL = 2
local ANALYTICS_HIERARCHY_INTERVAL = 10
local SOURCE_CHANGE_DEBOUNCE = 1.25
local CONTEXT_SERVICES = {
	"Workspace", "Lighting", "ReplicatedFirst", "ReplicatedStorage",
	"ServerScriptService", "ServerStorage", "StarterGui", "StarterPack",
	"StarterPlayer", "SoundService", "Teams", "Chat", "TextChatService",
}

local plugin = plugin
if not plugin then
	Logger.error("Companion must run as a Studio plugin")
	return
end

-- Studio clones plugins into the Server and Client DataModels during play.
-- Only Edit is persistent and may own the companion HTTP/session loop; allowing
-- the runtime clones to register makes all three DataModels evict each other
-- from the daemon's single command session.
if RunService:IsRunning() then
	return
end

-- State ----------------------------------------------------------------------
local sessionId: string? = nil
local connected = false
local lastConnectionError = ""
local lastConnectionLogAt = -math.huge
local commandHandlers: { [string]: (payload: any) -> any } = {}
local transactionActive = false
local eventQueue: { any } = {}
local recentEvents: { any } = {}
local eventListDirty = true
local sourceConnections: { [Instance]: RBXScriptConnection } = {}
local scriptNameConnections: { [Instance]: RBXScriptConnection } = {}
local lastReportedSource: { [string]: string } = {}
local lastReportedPath: { [Instance]: string } = {}
local pendingSourceChanges: { [string]: any } = {}
local subscriptions: { [string]: boolean } = {
	source_changed = true,
	selection_changed = true,
	hierarchy_changed = true,
	active_script_changed = true,
	mode_changed = true,
	output = true,
	history = true,
	context_snapshot = true,
}
local lastHeartbeat = 0
local lastLatencyMs = 0
local loopStopped = false
local retryDelay = 1
local MAX_RETRY_DELAY = 15
local lastContextSnapshot = 0
local lastAnalyticsSnapshot = 0
local lastAnalyticsHierarchy = 0
local analyticsCounts = { instances = 0, scripts = 0, parts = 0, models = 0, guis = 0 }
local analyticsOutput: { any } = {}
local analyticsScriptActivity: { any } = {}
local playSession = {
	active = false,
	startedAt = nil :: number?,
	prints = 0,
	warnings = 0,
	errors = 0,
}
local playDataEnabled = plugin:GetSetting("PlayDataEnabled") ~= false

local function setPlayDataEnabled(enabled: boolean)
	playDataEnabled = enabled
	plugin:SetSetting("PlayDataEnabled", enabled)
	if not enabled then
		analyticsOutput = {}
		analyticsScriptActivity = {}
		playSession.prints = 0
		playSession.warnings = 0
		playSession.errors = 0
	end
end
local lastMode = "Unknown"
local hierarchyChanges = { added = 0, removed = 0, paths = {} }
local lastRenderedConnected: boolean? = nil
local activeEventFilter = "All"

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
	statusHalo = nil :: Frame?,
	connectionRail = nil :: Frame?,
	eventCount = nil :: TextLabel?,
	selectionText = nil :: TextLabel?,
	activeScriptText = nil :: TextLabel?,
	activityPage = nil :: Frame?,
	signalsPage = nil :: Frame?,
	activityTab = nil :: TextButton?,
	signalsTab = nil :: TextButton?,
}

-- Helpers --------------------------------------------------------------------
local function getModePayload(): any
	return {
		isEdit = RunService:IsEdit(),
		isRunning = RunService:IsRunning(),
		currentDataModel = if RunService:IsRunning() then "Play" elseif RunService:IsEdit() then "Edit" else "Unknown",
		placeId = game.PlaceId,
	}
end

--#include modules/Transport.luau as Transport
local transport = Transport.create(HttpService)
local postTo = transport.postTo
local post = transport.bind(PLUGIN_URL)

local function updatePlaySessionState()
	local running = RunService:IsRunning()
	if running and not playSession.active then
		playSession.active = true
		playSession.startedAt = os.time()
		playSession.prints = 0
		playSession.warnings = 0
		playSession.errors = 0
		analyticsOutput = {}
		analyticsScriptActivity = {}
	elseif not running and playSession.active then
		playSession.active = false
	end
end

local function sampleStudioAnalytics(): any
	updatePlaySessionState()
	if os.clock() - lastAnalyticsHierarchy >= ANALYTICS_HIERARCHY_INTERVAL then
		local counts = { instances = 0, scripts = 0, parts = 0, models = 0, guis = 0 }
		for _, inst in ipairs(game:GetDescendants()) do
			counts.instances += 1
			if inst:IsA("LuaSourceContainer") then counts.scripts += 1 end
			if inst:IsA("BasePart") then counts.parts += 1 end
			if inst:IsA("Model") then counts.models += 1 end
			if inst:IsA("GuiObject") then counts.guis += 1 end
		end
		analyticsCounts = counts
		lastAnalyticsHierarchy = os.clock()
	end

	local totalMemoryMb: number? = nil
	pcall(function() totalMemoryMb = Stats:GetTotalMemoryUsageMb() end)
	local memoryByTag = {}
	for _, tagName in ipairs({ "LuaHeap", "Instances", "Signals", "PhysicsParts", "GraphicsTexture", "GraphicsMeshParts", "Script" }) do
		pcall(function()
			local tag = (Enum.DeveloperMemoryTag :: any)[tagName]
			if tag then memoryByTag[tagName] = Stats:GetMemoryUsageMbForTag(tag) end
		end)
	end
	local physicsFps: number? = nil
	pcall(function() physicsFps = workspace:GetRealPhysicsFPS() end)

	return {
		capturedAt = DateTime.now().UnixTimestampMillis,
		pluginVersion = PLUGIN_VERSION,
		placeId = game.PlaceId,
		mode = if RunService:IsRunning() then "Play" elseif RunService:IsEdit() then "Edit" else "Unknown",
		isClient = RunService:IsClient(),
		isServer = RunService:IsServer(),
		isRunning = RunService:IsRunning(),
		players = #Players:GetPlayers(),
		latencyMs = lastLatencyMs,
		totalMemoryMb = totalMemoryMb,
		memoryByTag = memoryByTag,
		physicsFps = physicsFps,
		counts = analyticsCounts,
		playtest = {
			enabled = playDataEnabled,
			active = RunService:IsRunning(),
			startedAt = playSession.startedAt,
			elapsedSec = if playSession.startedAt then math.max(0, os.time() - playSession.startedAt) else 0,
			prints = playSession.prints,
			warnings = playSession.warnings,
			errors = playSession.errors,
			output = if playDataEnabled then analyticsOutput else {},
		},
		scriptActivity = if playDataEnabled then analyticsScriptActivity else {},
	}
end

local function appendBounded(list: { any }, value: any, limit: number)
	table.insert(list, 1, value)
	while #list > limit do table.remove(list) end
end

local function classifyOutput(message: string, messageType: Enum.MessageType): any
	local level = if messageType == Enum.MessageType.MessageError then "error"
		elseif messageType == Enum.MessageType.MessageWarning then "warning"
		elseif messageType == Enum.MessageType.MessageInfo then "info"
		else "print"
	local scriptPath = string.match(message, "Script '([^']+)'")
	local line = tonumber(string.match(message, "[Ll]ine (%d+)") or string.match(message, ":(%d+):"))
	return {
		time = DateTime.now().UnixTimestampMillis,
		level = level,
		message = string.sub(message, 1, 4000),
		script = scriptPath,
		line = line,
		playtest = RunService:IsRunning(),
	}
end

--#include modules/Pathing.luau as Pathing
local resolvePath = Pathing.resolve
local instanceInfo = Pathing.info

--#include modules/CommandSchema.luau as CommandSchema
local CAPABILITIES = CommandSchema.capabilities
local COMMAND_SCHEMAS = CommandSchema.commands
--#include modules/Export.luau as Export
--#include modules/Inspection.luau as Inspection
--#include modules/Update.luau as Update
--#include modules/AXL.luau as AXL

--#include modules/SourceCodec.luau as SourceCodec
local codec = SourceCodec.create(resolvePath)
local encodeValue = codec.encode
local decodeValue = codec.decode

local function requireEditMode(): (boolean, string?)
	if not RunService:IsEdit() then
		return false, "This operation is only available in Studio edit mode"
	end
	return true, nil
end

local function waypoint(name: string)
	if transactionActive then return end
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, name)
end

local sourceDiff = SourceCodec.diff

local function currentMode(): string
	if RunService:IsRunning() then return "Play" end
	if RunService:IsEdit() then return "Edit" end
	return "Unknown"
end

local hashSource = SourceCodec.hash

local function buildContextSnapshot(): any
	local selected = {}
	for i, inst in ipairs(Selection:Get()) do
		if i > 20 then break end
		table.insert(selected, instanceInfo(inst))
	end

	local activeScript = nil
	if StudioService.ActiveScript and StudioService.ActiveScript:IsA("LuaSourceContainer") then
		activeScript = instanceInfo(StudioService.ActiveScript)
	end

	local openScripts = {}
	pcall(function()
		for _, document in ipairs(ScriptEditorService:GetScriptDocuments()) do
			if #openScripts >= 20 then break end
			if not document:IsCommandBar() then
				local scriptInstance = document:GetScript()
				if scriptInstance then
					local line, character = document:GetSelection()
					table.insert(openScripts, {
						path = string.gsub(scriptInstance:GetFullName(), "^game%.", ""),
						className = scriptInstance.ClassName,
						lineCount = document:GetLineCount(),
						cursor = { line = line, character = character },
					})
				end
			end
		end
	end)

	local serviceStats = {}
	for _, name in ipairs(CONTEXT_SERVICES) do
		local service = game:FindFirstChild(name)
		if service then
			local descendants = service:GetDescendants()
			local scriptCount = 0
			for _, inst in ipairs(descendants) do
				if inst:IsA("LuaSourceContainer") then scriptCount += 1 end
			end
			serviceStats[name] = {
				children = #service:GetChildren(),
				descendants = #descendants,
				scripts = scriptCount,
			}
		end
	end

	local tags = {}
	for _, tag in ipairs(CollectionService:GetAllTags()) do
		tags[tag] = #CollectionService:GetTagged(tag)
	end

	local history = { canUndo = false, undo = nil, canRedo = false, redo = nil }
	pcall(function()
		local canUndo, undoName = ChangeHistoryService:GetCanUndo()
		local canRedo, redoName = ChangeHistoryService:GetCanRedo()
		history = { canUndo = canUndo, undo = undoName, canRedo = canRedo, redo = redoName }
	end)

	return {
		place = { id = game.PlaceId, version = game.PlaceVersion, name = game.Name },
		mode = currentMode(),
		selection = selected,
		activeScript = activeScript,
		openScripts = openScripts,
		services = serviceStats,
		tags = tags,
		history = history,
	}
end

local function eventAllowed(eventType: string): boolean
	return subscriptions[eventType] == true
end

local function rememberEvent(event: any)
	if event.type == "context_snapshot" or event.type == "command_responses" then return end
	table.insert(recentEvents, 1, event)
	while #recentEvents > EVENT_LIMIT do
		table.remove(recentEvents)
	end
	eventListDirty = true
end

local function queueEvent(event: any)
	if typeof(event) ~= "table" then return end
	event.time = event.time or DateTime.now().UnixTimestampMillis
	if not event.type or eventAllowed(event.type) then
		rememberEvent(event)
		table.insert(eventQueue, event)
	end
end

-- UI styling -----------------------------------------------------------------
local PALETTE = {
	bg = Color3.fromRGB(18, 19, 22),
	surface = Color3.fromRGB(25, 27, 31),
	card = Color3.fromRGB(30, 33, 38),
	cardHover = Color3.fromRGB(38, 42, 48),
	stroke = Color3.fromRGB(49, 53, 61),
	strokeSoft = Color3.fromRGB(37, 40, 46),
	text = Color3.fromRGB(242, 244, 248),
	textDim = Color3.fromRGB(155, 163, 177),
	textMuted = Color3.fromRGB(103, 110, 122),
	accent = Color3.fromRGB(51, 173, 255),
	accentGlow = Color3.fromRGB(24, 115, 174),
	green = Color3.fromRGB(66, 211, 146),
	red = Color3.fromRGB(244, 92, 105),
	yellow = Color3.fromRGB(245, 190, 72),
	magenta = Color3.fromRGB(194, 116, 255),
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
		corner.CornerRadius = UDim.new(0, 6)
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
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
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
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.TextColor3 = PALETTE.text
	button.TextSize = 13
	button.TextWrapped = false
	button.Size = UDim2.fromScale(1, 1)
	constrainSize(button, 72, 30)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = PALETTE.stroke
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { TextColor3 = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = PALETTE.cardHover }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Color = PALETTE.accent }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { TextColor3 = PALETTE.text }):Play()
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
	local rail = Instance.new("TextButton")
	rail.AutoButtonColor = false
	rail.Text = ""
	rail.BackgroundColor3 = if initial then PALETTE.accentGlow else PALETTE.stroke
	rail.Size = UDim2.new(0, 38, 0, 20)
	rail.AnchorPoint = Vector2.new(1, 0.5)
	rail.Position = UDim2.new(1, -6, 0.5, 0)
	local railCorner = Instance.new("UICorner")
	railCorner.CornerRadius = UDim.new(1, 0)
	railCorner.Parent = rail
	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Size = UDim2.fromOffset(14, 14)
	knob.Position = if initial then UDim2.new(1, -17, 0, 3) else UDim2.fromOffset(3, 3)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = knob
	knob.Parent = rail
	rail.Parent = frame
	local enabled = initial
	rail.MouseButton1Click:Connect(function()
		enabled = not enabled
		callback(enabled)
		TweenService:Create(rail, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
			BackgroundColor3 = if enabled then PALETTE.accentGlow else PALETTE.stroke,
		}):Play()
		TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
			Position = if enabled then UDim2.new(1, -17, 0, 3) else UDim2.fromOffset(3, 3),
		}):Play()
	end)
	frame.Parent = parent
	return frame
end

-- Event feed -----------------------------------------------------------------
local function eventColor(eventType: string): Color3
	if eventType == "source_changed" then return PALETTE.accent end
	if eventType == "selection_changed" then return PALETTE.yellow end
	if eventType == "active_script_changed" then return PALETTE.magenta end
	if eventType == "history" then return PALETTE.green end
	if eventType == "hierarchy_changed" then return PALETTE.yellow end
	if eventType == "mode_changed" then return PALETTE.magenta end
	if eventType == "output" then return PALETTE.red end
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
		return "Source committed", string.format("%s  |  %d changes", tostring(event.path or "?"), tonumber(event.changeCount) or 1)
	end
	if t == "selection_changed" then
		local paths = event.paths or {}
		return "Selection", if #paths == 0 then "Nothing selected" else table.concat(paths, ", ")
	end
	if t == "active_script_changed" then return "Active script", tostring(event.path or "Editor closed") end
	if t == "history" then return string.upper(string.sub(tostring(event.action or "commit"), 1, 1)) .. string.sub(tostring(event.action or "commit"), 2), tostring(event.name or "Studio change") end
	if t == "hierarchy_changed" then return "Hierarchy", string.format("+%d  -%d instances", tonumber(event.added) or 0, tonumber(event.removed) or 0) end
	if t == "mode_changed" then return "Studio mode", tostring(event.mode or "Unknown") end
	if t == "output" then return (if event.level == "MessageError" then "Error" else "Warning"), tostring(event.message or "") end
	if t == "command_responses" then
		return t, tostring(#(event.responses or {})) .. " responses"
	end
	return t, tostring(event.path or "")
end

local function formatEventTime(event: any): string
	local timestamp = tonumber(event.time)
	if not timestamp then return "--:--:--" end
	if timestamp < 100000000000 then timestamp *= 1000 end
	local localTime = DateTime.fromUnixTimestampMillis(timestamp):ToLocalTime()
	return string.format("%02d:%02d:%02d", localTime.Hour, localTime.Minute, localTime.Second)
end

local function eventMatchesFilter(event: any): boolean
	if activeEventFilter == "All" then return true end
	if activeEventFilter == "Code" then
		return event.type == "source_changed" or event.type == "active_script_changed"
	end
	if activeEventFilter == "Studio" then
		return event.type == "selection_changed" or event.type == "hierarchy_changed" or event.type == "history" or event.type == "mode_changed"
	end
	if activeEventFilter == "Issues" then
		return event.type == "output" or event.type == "error"
	end
	return true
end

local function refreshEventList()
	local list = ui.eventList
	if not list then return end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local shown = 0
	for _, event in ipairs(recentEvents) do
		if shown >= 40 then break end
		if not eventMatchesFilter(event) then continue end
		shown += 1
		local row = Instance.new("CanvasGroup")
		row.BackgroundColor3 = PALETTE.card
		row.BackgroundTransparency = 0.35
		row.Size = UDim2.new(1, -6, 0, 48)
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
		indicator.Size = UDim2.new(0, 3, 1, -16)
		indicator.Position = UDim2.fromOffset(8, 8)
		local ic = Instance.new("UICorner")
		ic.CornerRadius = UDim.new(1, 0)
		ic.Parent = indicator
		indicator.Parent = row
		local t, detail = formatEvent(event)
		local typeLabel = createText(row, t, 0, 13, true, eventColor(event.type))
		typeLabel.Position = UDim2.new(0, 20, 0, 3)
		typeLabel.Size = UDim2.new(1, -96, 0, 22)
		local timePill = Instance.new("TextLabel")
		timePill.Name = "Timestamp"
		timePill.AnchorPoint = Vector2.new(1, 0)
		timePill.BackgroundColor3 = PALETTE.surface
		timePill.BorderSizePixel = 0
		timePill.Font = Enum.Font.GothamMedium
		timePill.Position = UDim2.new(1, -7, 0, 6)
		timePill.Size = UDim2.fromOffset(62, 17)
		timePill.Text = formatEventTime(event)
		timePill.TextColor3 = PALETTE.textMuted
		timePill.TextSize = 9
		local timeCorner = Instance.new("UICorner")
		timeCorner.CornerRadius = UDim.new(0, 4)
		timeCorner.Parent = timePill
		timePill.Parent = row
		local detailLabel = createText(row, detail, 0, 12, false, PALETTE.textDim)
		detailLabel.Position = UDim2.new(0, 20, 0, 23)
		detailLabel.Size = UDim2.new(1, -28, 0, 20)
		detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
		row.Parent = list
		if shown == 1 then
			row.GroupTransparency = 1
			row.Position = UDim2.fromOffset(-10, 0)
			TweenService:Create(row, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				GroupTransparency = 0,
				Position = UDim2.fromOffset(0, 0),
			}):Play()
		end
	end
	if shown == 0 then
		local empty = createText(list, "No activity in this filter", 0, 13, false, PALETTE.textMuted)
		empty.Size = UDim2.new(1, -8, 0, 48)
		empty.TextXAlignment = Enum.TextXAlignment.Center
	end
	if ui.eventListLayout then
		list.CanvasSize = UDim2.new(0, 0, 0, ui.eventListLayout.AbsoluteContentSize.Y + 8)
	end
	eventListDirty = false
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
	end
	if lastRenderedConnected ~= connected then
		lastRenderedConnected = connected
		if ui.connectionRail then
			ui.connectionRail.Size = UDim2.new(0, 0, 0, 2)
			ui.connectionRail.BackgroundColor3 = if connected then PALETTE.green else PALETTE.red
			TweenService:Create(ui.connectionRail, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 0, 2),
			}):Play()
		end
		if ui.statusHalo then
			ui.statusHalo.BackgroundColor3 = if connected then PALETTE.green else PALETTE.red
			ui.statusHalo.BackgroundTransparency = 0.55
			ui.statusHalo.Size = UDim2.fromOffset(8, 8)
			TweenService:Create(ui.statusHalo, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(24, 24),
			}):Play()
		end
	end
	if ui.sessionId then
		ui.sessionId.Text = sessionId or "none"
	end
	if ui.mode then
		ui.mode.Text = if RunService:IsRunning() then "Play" elseif RunService:IsEdit() then "Edit" else "Unknown"
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
		ui.queued.Text = tostring(#eventQueue + (if next(pendingSourceChanges) then 1 else 0))
	end
	if ui.eventCount then ui.eventCount.Text = tostring(#recentEvents) end
	if ui.selectionText then
		local selected = Selection:Get()
		ui.selectionText.Text = if #selected == 0 then "Nothing selected" else string.gsub(selected[1]:GetFullName(), "^game%.", "")
	end
	if ui.activeScriptText then
		local active = StudioService.ActiveScript
		ui.activeScriptText.Text = if active then string.gsub(active:GetFullName(), "^game%.", "") else "No script open"
	end
end

-- Panel construction ---------------------------------------------------------
local function createLegacyPanel()
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
		retryDelay = 1
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
		eventListDirty = true
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

local function createPanel()
	local info = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		390,
		650,
		320,
		400
	)
	widget = plugin:CreateDockWidgetPluginGui("AbraxiusCompanionPanel", info)
	widget.Title = "Abraxius by Velumix"

	local root = Instance.new("CanvasGroup")
	root.Name = "AbraxiusRoot"
	root.BackgroundColor3 = PALETTE.bg
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.GroupTransparency = 1
	root.Parent = widget
	TweenService:Create(root, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
	}):Play()

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = PALETTE.surface
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, 66)
	header.Parent = root

	local brandMark = Instance.new("Frame")
	brandMark.BackgroundColor3 = PALETTE.accent
	brandMark.Size = UDim2.fromOffset(32, 32)
	brandMark.Position = UDim2.fromOffset(14, 14)
	local brandCorner = Instance.new("UICorner")
	brandCorner.CornerRadius = UDim.new(0, 6)
	brandCorner.Parent = brandMark
	local brandText = createText(brandMark, "A", 0, 17, true, Color3.new(1, 1, 1))
	brandText.TextXAlignment = Enum.TextXAlignment.Center
	brandText.Size = UDim2.fromScale(1, 1)
	brandMark.Parent = header

	local title = createText(header, "ABRAXIUS", 0, 15, true, PALETTE.text)
	title.Position = UDim2.fromOffset(56, 10)
	title.Size = UDim2.new(1, -190, 0, 24)
	title.TextWrapped = false
	local subtitle = createText(header, "A VELUMIX STUDIO TOOL", 0, 9, true, PALETTE.textMuted)
	subtitle.Position = UDim2.fromOffset(56, 31)
	subtitle.Size = UDim2.new(1, -190, 0, 18)
	subtitle.TextWrapped = false

	local status = Instance.new("Frame")
	status.BackgroundTransparency = 1
	status.AnchorPoint = Vector2.new(1, 0.5)
	status.Position = UDim2.new(1, -14, 0.5, 0)
	status.Size = UDim2.fromOffset(116, 34)
	status.Parent = header
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromOffset(9, 17)
	halo.BackgroundColor3 = PALETTE.red
	halo.BackgroundTransparency = 1
	halo.Size = UDim2.fromOffset(8, 8)
	local haloCorner = Instance.new("UICorner")
	haloCorner.CornerRadius = UDim.new(1, 0)
	haloCorner.Parent = halo
	halo.Parent = status
	ui.statusHalo = halo
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(9, 17)
	dot.BackgroundColor3 = PALETTE.red
	dot.Size = UDim2.fromOffset(8, 8)
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	dot.Parent = status
	ui.statusDot = dot
	local statusText = createText(status, "Offline", 0, 11, true, PALETTE.red)
	statusText.Position = UDim2.fromOffset(23, 0)
	statusText.Size = UDim2.new(1, -23, 1, 0)
	statusText.TextWrapped = false
	ui.statusText = statusText

	local connectionRail = Instance.new("Frame")
	connectionRail.BorderSizePixel = 0
	connectionRail.BackgroundColor3 = PALETTE.red
	connectionRail.Position = UDim2.new(0, 0, 1, -2)
	connectionRail.Size = UDim2.new(0, 0, 0, 2)
	connectionRail.Parent = header
	ui.connectionRail = connectionRail

	local metrics = Instance.new("Frame")
	metrics.Name = "Metrics"
	metrics.BackgroundColor3 = PALETTE.bg
	metrics.BorderSizePixel = 0
	metrics.Position = UDim2.fromOffset(0, 66)
	metrics.Size = UDim2.new(1, 0, 0, 64)
	metrics.Parent = root

	local function makeMetric(index: number, label: string, bind: (TextLabel) -> ())
		local metric = Instance.new("Frame")
		metric.BackgroundTransparency = 1
		metric.Position = UDim2.new((index - 1) * 0.25, 0, 0, 0)
		metric.Size = UDim2.new(0.25, 0, 1, 0)
		metric.Parent = metrics
		local value = createText(metric, "-", 0, 17, true, PALETTE.text)
		value.Position = UDim2.fromOffset(12, 9)
		value.Size = UDim2.new(1, -18, 0, 25)
		value.TextTruncate = Enum.TextTruncate.AtEnd
		local caption = createText(metric, string.upper(label), 0, 9, true, PALETTE.textMuted)
		caption.Position = UDim2.fromOffset(12, 33)
		caption.Size = UDim2.new(1, -18, 0, 18)
		caption.TextWrapped = false
		bind(value)
		if index > 1 then
			local divider = Instance.new("Frame")
			divider.BorderSizePixel = 0
			divider.BackgroundColor3 = PALETTE.strokeSoft
			divider.Position = UDim2.fromOffset(0, 12)
			divider.Size = UDim2.new(0, 1, 1, -24)
			divider.Parent = metric
		end
	end

	makeMetric(1, "Mode", function(label) ui.mode = label end)
	makeMetric(2, "Latency", function(label) ui.latency = label end)
	makeMetric(3, "Scripts", function(label) ui.watched = label end)
	makeMetric(4, "Queued", function(label) ui.queued = label end)

	local toolbar = Instance.new("Frame")
	toolbar.Name = "Toolbar"
	toolbar.BackgroundColor3 = PALETTE.surface
	toolbar.BorderSizePixel = 0
	toolbar.Position = UDim2.fromOffset(0, 130)
	toolbar.Size = UDim2.new(1, 0, 0, 44)
	toolbar.Parent = root
	local toolbarPadding = Instance.new("UIPadding")
	toolbarPadding.PaddingLeft = UDim.new(0, 10)
	toolbarPadding.PaddingRight = UDim.new(0, 10)
	toolbarPadding.PaddingTop = UDim.new(0, 7)
	toolbarPadding.PaddingBottom = UDim.new(0, 7)
	toolbarPadding.Parent = toolbar
	local toolbarLayout = Instance.new("UIListLayout")
	toolbarLayout.FillDirection = Enum.FillDirection.Horizontal
	toolbarLayout.Padding = UDim.new(0, 7)
	toolbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	toolbarLayout.Parent = toolbar

	local reconnectBtn = createButton(toolbar, "Reconnect")
	reconnectBtn.Size = UDim2.new(0.34, -5, 1, 0)
	reconnectBtn.MouseButton1Click:Connect(function()
		connected = false
		sessionId = nil
		retryDelay = 1
		updatePanel()
	end)
	local refreshBtn = createButton(toolbar, "Refresh")
	refreshBtn.Size = UDim2.new(0.33, -5, 1, 0)
	refreshBtn.MouseButton1Click:Connect(function()
		queueEvent({ type = "context_snapshot", snapshot = buildContextSnapshot() })
		updatePanel()
	end)
	local clearBtn = createButton(toolbar, "Clear")
	clearBtn.Size = UDim2.new(0.33, -5, 1, 0)
	clearBtn.MouseButton1Click:Connect(function()
		table.clear(recentEvents)
		eventListDirty = true
		refreshEventList()
		updatePanel()
	end)

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundColor3 = PALETTE.bg
	tabs.BorderSizePixel = 0
	tabs.Position = UDim2.fromOffset(0, 174)
	tabs.Size = UDim2.new(1, 0, 0, 38)
	tabs.Parent = root
	local tabDivider = Instance.new("Frame")
	tabDivider.BackgroundColor3 = PALETTE.strokeSoft
	tabDivider.BorderSizePixel = 0
	tabDivider.Position = UDim2.new(0, 0, 1, -1)
	tabDivider.Size = UDim2.new(1, 0, 0, 1)
	tabDivider.Parent = tabs

	local function makeTab(text: string, x: number): TextButton
		local tab = Instance.new("TextButton")
		tab.AutoButtonColor = false
		tab.BackgroundTransparency = 1
		tab.Font = Enum.Font.GothamMedium
		tab.Text = text
		tab.TextColor3 = PALETTE.textDim
		tab.TextSize = 12
		tab.Position = UDim2.fromOffset(x, 0)
		tab.Size = UDim2.fromOffset(88, 38)
		tab.Parent = tabs
		return tab
	end
	local activityTab = makeTab("Activity", 8)
	local signalsTab = makeTab("Signals", 96)
	ui.activityTab = activityTab
	ui.signalsTab = signalsTab
	local count = createText(tabs, "0", 0, 10, true, PALETTE.textMuted)
	count.AnchorPoint = Vector2.new(1, 0.5)
	count.Position = UDim2.new(1, -14, 0.5, 0)
	count.Size = UDim2.fromOffset(36, 24)
	count.TextXAlignment = Enum.TextXAlignment.Right
	ui.eventCount = count

	local pageHost = Instance.new("Frame")
	pageHost.Name = "PageHost"
	pageHost.BackgroundTransparency = 1
	pageHost.Position = UDim2.fromOffset(0, 212)
	pageHost.Size = UDim2.new(1, 0, 1, -250)
	pageHost.ClipsDescendants = true
	pageHost.Parent = root

	local activityPage = Instance.new("Frame")
	activityPage.Name = "Activity"
	activityPage.BackgroundTransparency = 1
	activityPage.Size = UDim2.fromScale(1, 1)
	activityPage.Parent = pageHost
	ui.activityPage = activityPage

	local contextBand = Instance.new("Frame")
	contextBand.BackgroundColor3 = PALETTE.surface
	contextBand.BorderSizePixel = 0
	contextBand.Position = UDim2.fromOffset(10, 8)
	contextBand.Size = UDim2.new(1, -20, 0, 58)
	local bandCorner = Instance.new("UICorner")
	bandCorner.CornerRadius = UDim.new(0, 6)
	bandCorner.Parent = contextBand
	contextBand.Parent = activityPage
	local selectionCaption = createText(contextBand, "SELECTION", 0, 9, true, PALETTE.textMuted)
	selectionCaption.Position = UDim2.fromOffset(10, 5)
	selectionCaption.Size = UDim2.new(0.5, -14, 0, 18)
	local selectionValue = createText(contextBand, "Nothing selected", 0, 11, false, PALETTE.text)
	selectionValue.Position = UDim2.fromOffset(10, 23)
	selectionValue.Size = UDim2.new(0.5, -14, 0, 26)
	selectionValue.TextTruncate = Enum.TextTruncate.AtEnd
	ui.selectionText = selectionValue
	local contextDivider = Instance.new("Frame")
	contextDivider.BackgroundColor3 = PALETTE.strokeSoft
	contextDivider.BorderSizePixel = 0
	contextDivider.Position = UDim2.new(0.5, 0, 0, 9)
	contextDivider.Size = UDim2.new(0, 1, 1, -18)
	contextDivider.Parent = contextBand
	local scriptCaption = createText(contextBand, "ACTIVE SCRIPT", 0, 9, true, PALETTE.textMuted)
	scriptCaption.Position = UDim2.new(0.5, 10, 0, 5)
	scriptCaption.Size = UDim2.new(0.5, -18, 0, 18)
	local scriptValue = createText(contextBand, "No script open", 0, 11, false, PALETTE.text)
	scriptValue.Position = UDim2.new(0.5, 10, 0, 23)
	scriptValue.Size = UDim2.new(0.5, -18, 0, 26)
	scriptValue.TextTruncate = Enum.TextTruncate.AtEnd
	ui.activeScriptText = scriptValue

	local filters = Instance.new("Frame")
	filters.BackgroundTransparency = 1
	filters.Position = UDim2.fromOffset(10, 72)
	filters.Size = UDim2.new(1, -20, 0, 30)
	filters.Parent = activityPage
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.Padding = UDim.new(0, 5)
	filterLayout.Parent = filters
	local filterButtons: { [string]: TextButton } = {}
	local function setFilter(filter: string)
		activeEventFilter = filter
		for name, button in pairs(filterButtons) do
			TweenService:Create(button, TweenInfo.new(0.14), {
				BackgroundTransparency = if name == filter then 0 else 1,
				BackgroundColor3 = PALETTE.card,
				TextColor3 = if name == filter then PALETTE.text else PALETTE.textMuted,
			}):Play()
		end
		eventListDirty = true
		refreshEventList()
	end
	for _, filter in ipairs({ "All", "Code", "Studio", "Issues" }) do
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BackgroundColor3 = PALETTE.card
		button.BackgroundTransparency = if filter == "All" then 0 else 1
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.Text = filter
		button.TextColor3 = if filter == "All" then PALETTE.text else PALETTE.textMuted
		button.TextSize = 10
		button.Size = UDim2.fromOffset(58, 26)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = button
		button.MouseButton1Click:Connect(function() setFilter(filter) end)
		button.Parent = filters
		filterButtons[filter] = button
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "EventList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(10, 106)
	list.Size = UDim2.new(1, -14, 1, -110)
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = PALETTE.stroke
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = activityPage
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.Parent = list
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	ui.eventList = list
	ui.eventListLayout = listLayout

	local signalsPage = Instance.new("Frame")
	signalsPage.Name = "Signals"
	signalsPage.BackgroundTransparency = 1
	signalsPage.Size = UDim2.fromScale(1, 1)
	signalsPage.Position = UDim2.new(1, 0, 0, 0)
	signalsPage.Visible = false
	signalsPage.Parent = pageHost
	ui.signalsPage = signalsPage
	local signalsTitle = createText(signalsPage, "Captured signals", 0, 15, true, PALETTE.text)
	signalsTitle.Position = UDim2.fromOffset(14, 12)
	signalsTitle.Size = UDim2.new(1, -28, 0, 26)
	local signalsHint = createText(signalsPage, "Choose which Studio activity enters the context stream.", 0, 11, false, PALETTE.textDim)
	signalsHint.Position = UDim2.fromOffset(14, 37)
	signalsHint.Size = UDim2.new(1, -28, 0, 34)
	local signalList = Instance.new("Frame")
	signalList.BackgroundColor3 = PALETTE.surface
	signalList.BorderSizePixel = 0
	signalList.Position = UDim2.fromOffset(10, 78)
	signalList.Size = UDim2.new(1, -20, 0, 211)
	local signalCorner = Instance.new("UICorner")
	signalCorner.CornerRadius = UDim.new(0, 6)
	signalCorner.Parent = signalList
	signalList.Parent = signalsPage
	local signalLayout = Instance.new("UIListLayout")
	signalLayout.Padding = UDim.new(0, 4)
	signalLayout.Parent = signalList
	for _, config in ipairs({
		{ "Source commits", "source_changed" },
		{ "Explorer selection", "selection_changed" },
		{ "Hierarchy changes", "hierarchy_changed" },
		{ "Warnings and errors", "output" },
		{ "History commits", "history" },
	}) do
		local toggle = createToggle(signalList, config[1], subscriptions[config[2]], function(enabled)
			subscriptions[config[2]] = enabled
		end)
		toggle.Size = UDim2.new(1, 0, 0, 31)
	end
	local playDataToggle = createToggle(signalList, "Play data analytics", playDataEnabled, function(enabled)
		setPlayDataEnabled(enabled)
	end)
	playDataToggle.Size = UDim2.new(1, 0, 0, 31)

	local sessionBand = Instance.new("Frame")
	sessionBand.BackgroundColor3 = PALETTE.surface
	sessionBand.BorderSizePixel = 0
	sessionBand.Position = UDim2.fromOffset(10, 301)
	sessionBand.Size = UDim2.new(1, -20, 0, 56)
	local sessionCorner = Instance.new("UICorner")
	sessionCorner.CornerRadius = UDim.new(0, 6)
	sessionCorner.Parent = sessionBand
	sessionBand.Parent = signalsPage
	local sessionCaption = createText(sessionBand, "SESSION", 0, 9, true, PALETTE.textMuted)
	sessionCaption.Position = UDim2.fromOffset(10, 5)
	sessionCaption.Size = UDim2.new(1, -20, 0, 18)
	local sessionValue = createText(sessionBand, "none", 0, 11, false, PALETTE.text)
	sessionValue.Position = UDim2.fromOffset(10, 23)
	sessionValue.Size = UDim2.new(1, -20, 0, 22)
	sessionValue.TextTruncate = Enum.TextTruncate.AtEnd
	ui.sessionId = sessionValue

	local activePage = "Activity"
	local function setPage(name: string)
		if name == activePage then return end
		activePage = name
		local showActivity = name == "Activity"
		local incoming = if showActivity then activityPage else signalsPage
		local outgoing = if showActivity then signalsPage else activityPage
		incoming.Visible = true
		incoming.Position = UDim2.new(if showActivity then 1 else -1, 0, 0, 0)
		TweenService:Create(outgoing, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
			Position = UDim2.new(if showActivity then -1 else 1, 0, 0, 0),
		}):Play()
		TweenService:Create(incoming, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0, 0),
		}):Play()
		task.delay(0.22, function() outgoing.Visible = false end)
		TweenService:Create(activityTab, TweenInfo.new(0.14), { TextColor3 = if showActivity then PALETTE.text else PALETTE.textMuted }):Play()
		TweenService:Create(signalsTab, TweenInfo.new(0.14), { TextColor3 = if showActivity then PALETTE.textMuted else PALETTE.text }):Play()
	end
	activityTab.MouseButton1Click:Connect(function() setPage("Activity") end)
	signalsTab.MouseButton1Click:Connect(function() setPage("Signals") end)
	activityTab.TextColor3 = PALETTE.text

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundColor3 = PALETTE.surface
	footer.BorderSizePixel = 0
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 38)
	footer.Parent = root
	local footerLabel = createText(footer, "LAST ERROR", 0, 8, true, PALETTE.textMuted)
	footerLabel.Position = UDim2.fromOffset(12, 2)
	footerLabel.Size = UDim2.fromOffset(72, 16)
	local errorValue = createText(footer, "None", 0, 10, false, PALETTE.textDim)
	errorValue.Position = UDim2.fromOffset(12, 16)
	errorValue.Size = UDim2.new(1, -112, 0, 18)
	errorValue.TextTruncate = Enum.TextTruncate.AtEnd
	ui.errorLabel = errorValue
	local trademark = createText(footer, "VELUMIX", 0, 9, true, PALETTE.textMuted)
	trademark.AnchorPoint = Vector2.new(1, 0.5)
	trademark.Position = UDim2.new(1, -12, 0.5, 2)
	trademark.Size = UDim2.fromOffset(82, 24)
	trademark.TextXAlignment = Enum.TextXAlignment.Right

	updatePanel()
	refreshEventList()
end

-- Command handlers ------------------------------------------------------------
commandHandlers["read_source"] = function(payload: any): any
	return Inspection.source(resolvePath(payload.path), payload.path, instanceInfo, hashSource)
end

commandHandlers["write_source"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	local validation = Update.validateSource(resolvePath(payload.path), payload, hashSource, sourceDiff)
	if validation.error then return { ok = false, error = validation.error, currentHash = validation.currentHash } end
	local inst = validation.instance :: LuaSourceContainer
	local previousSource = validation.previous
	local diff = validation.diff
	if payload.dryRun == true then
		return {
			ok = true, dryRun = true, changed = previousSource ~= payload.source,
			previousHash = hashSource(previousSource), sourceHash = hashSource(payload.source),
			sourceLength = #payload.source, diff = diff,
		}
	end
	local updated, updateError = pcall(function()
		ScriptEditorService:UpdateSourceAsync(inst, function()
			return payload.source
		end)
	end)
	if not updated then
		updated, updateError = pcall(function() inst.Source = payload.source end)
	end
	if not updated then return { ok = false, error = tostring(updateError) } end
	if inst.Source ~= payload.source then return { ok = false, error = "Studio did not commit the requested source" } end
	waypoint("Abraxius: Write " .. inst.Name)
	return {
		ok = true,
		script = instanceInfo(inst),
		changed = previousSource ~= payload.source,
		previousHash = hashSource(previousSource),
		sourceHash = hashSource(inst.Source),
		sourceLength = #inst.Source,
		diff = diff,
	}
end

commandHandlers["create_script"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	local className = tostring(payload.className or "ModuleScript")
	if className ~= "Script" and className ~= "LocalScript" and className ~= "ModuleScript" then
		return { ok = false, error = "className must be Script, LocalScript, or ModuleScript" }
	end
	local parentPath = payload.parent
	local requestedName = payload.name
	if payload.path ~= nil then
		if typeof(payload.path) ~= "string" or payload.path == "" then return { ok = false, error = "path must be a non-empty string" } end
		local parts = string.split(payload.path, ".")
		requestedName = table.remove(parts)
		parentPath = table.concat(parts, ".")
		if parentPath == "" then return { ok = false, error = "path must include a parent" } end
	end
	local parent = resolvePath(parentPath)
	if not parent then return { ok = false, error = "Parent not found: " .. tostring(parentPath) } end
	local name = tostring(requestedName or "NewScript")
	if parent:FindFirstChild(name) then return { ok = false, error = "An instance already exists at " .. parent:GetFullName() .. "." .. name } end
	local scriptInstance = Instance.new(className) :: LuaSourceContainer
	scriptInstance.Name = name
	local ok, err = pcall(function()
		scriptInstance.Source = tostring(payload.source or "")
		for key, value in pairs(payload.properties or {}) do
			(scriptInstance :: any)[key] = decodeValue(value)
		end
		scriptInstance.Parent = parent
	end)
	if not ok then scriptInstance:Destroy(); return { ok = false, error = tostring(err) } end
	waypoint("Abraxius: Create " .. name)
	return { ok = true, script = instanceInfo(scriptInstance), sourceHash = hashSource(scriptInstance.Source), sourceLength = #scriptInstance.Source }
end

commandHandlers["execute_luau"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	if payload.confirm ~= true then return { ok = false, error = "Luau execution requires confirm=true" } end
	if typeof(payload.code) ~= "string" or payload.code == "" then return { ok = false, error = "code must be a non-empty string" } end
	if #payload.code > 65536 then return { ok = false, error = "code exceeds the 64 KiB execution limit" } end
	local runner = Instance.new("ModuleScript")
	runner.Name = "__AbraxiusExecution_" .. HttpService:GenerateGUID(false)
	local ok, result = pcall(function()
		runner.Source = "return function()\n" .. payload.code .. "\nend"
		runner.Parent = game:GetService("ServerStorage")
		local fn = require(runner)
		return fn()
	end)
	runner:Destroy()
	if not ok then return { ok = false, error = tostring(result) } end
	return { ok = true, result = encodeValue(result) }
end

commandHandlers["get_selection"] = function(): any
	return Inspection.selection(Selection, instanceInfo)
end

commandHandlers["get_children"] = function(payload: any): any
	return Inspection.children(resolvePath(payload.path), payload.path, instanceInfo)
end

commandHandlers["set_selection"] = function(payload: any): any
	local selected = {}
	for _, path in ipairs(payload.paths or {}) do
		local inst = resolvePath(tostring(path))
		if inst then table.insert(selected, inst) end
	end
	Selection:Set(selected)
	return { ok = true, selection = (commandHandlers["get_selection"]({})).selection }
end

commandHandlers["open_script"] = function(payload: any): any
	local inst = resolvePath(payload.path)
	if not inst or not inst:IsA("LuaSourceContainer") then
		return { ok = false, error = "Script not found: " .. tostring(payload.path) }
	end
	plugin:OpenScript(inst, math.max(1, tonumber(payload.line) or 1))
	return { ok = true, script = instanceInfo(inst), line = math.max(1, tonumber(payload.line) or 1) }
end

commandHandlers["export_scripts"] = function(payload: any): any
	return Export.scripts(payload.services, CONTEXT_SERVICES)
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

commandHandlers["get_context_snapshot"] = function(): any
	return { ok = true, snapshot = buildContextSnapshot() }
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
	return { ok = true, time = os.time(), connected = connected, sessionId = sessionId, version = PLUGIN_VERSION }
end

commandHandlers["get_capabilities"] = function(): any
	return {
		ok = true,
		protocolVersion = 6,
		pluginVersion = PLUGIN_VERSION,
		capabilities = CAPABILITIES,
		valueTypes = { "Vector2", "Vector3", "CFrame", "Color3", "Color3uint8", "UDim", "UDim2", "BrickColor", "EnumItem", "NumberRange", "Rect", "Instance" },
		canonicalization = { Color3uint8 = "Color3" },
		commands = COMMAND_SCHEMAS,
	}
end

commandHandlers["get_play_data_settings"] = function(): any
	return { ok = true, enabled = playDataEnabled }
end

commandHandlers["set_play_data_enabled"] = function(payload: any): any
	if typeof(payload.enabled) ~= "boolean" then
		return { ok = false, error = "enabled must be a boolean" }
	end
	setPlayDataEnabled(payload.enabled)
	return { ok = true, enabled = playDataEnabled }
end

commandHandlers["get_assistant_context"] = function(): any
	return {
		ok = true,
		pluginVersion = PLUGIN_VERSION,
		capabilities = CAPABILITIES,
		context = buildContextSnapshot(),
		mode = getModePayload(),
	}
end

commandHandlers["get_watched_sources"] = function(): any
	local paths = {}
	for inst, _ in pairs(sourceConnections) do
		table.insert(paths, (string.gsub(inst:GetFullName(), "^game%.", "")))
	end
	table.sort(paths)
	return { ok = true, count = #paths, paths = paths }
end

local axl = AXL.create({
	resolvePath = resolvePath,
	instanceInfo = instanceInfo,
	hashSource = hashSource,
	jsonEncode = function(value: any): string return HttpService:JSONEncode(value) end,
	contextSnapshot = buildContextSnapshot,
	requireEditMode = requireEditMode,
	updateSource = function(instance: LuaSourceContainer, source: string): (boolean, string?, boolean?)
		local ok, err = pcall(function()
			ScriptEditorService:UpdateSourceAsync(instance, function() return source end)
		end)
		if not ok then return false, tostring(err), nil end
		return true, nil, instance.Source ~= source
	end,
	beginRecording = function(name: string): any
		return ChangeHistoryService:TryBeginRecording("AbraxiusAXL", name)
	end,
	finishRecording = function(recording: any, commit: boolean)
		if recording then
			ChangeHistoryService:FinishRecording(
				recording,
				if commit then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end
	end,
	executeLuau = function(code: string): any
		return commandHandlers["execute_luau"]({ code = code, confirm = true })
	end,
	getState = function(): any return commandHandlers["get_state"]({}) end,
})

commandHandlers["axl"] = function(payload: any): any
	if typeof(payload.source) ~= "string" then return { ok = false, error = "source must be a string" } end
	local response = axl.execute(payload.source)
	return { ok = not string.match(response, "^ERR "), response = response }
end

commandHandlers["set_properties"] = function(payload: any): any
	local inst = resolvePath(payload.path)
	if not inst then
		return { ok = false, error = "Instance not found: " .. tostring(payload.path) }
	end
	local props = payload.properties or {}
	local changed = {}
	for key, value in pairs(props) do
		local ok, err = pcall(function()
			if key == "RunContext" and typeof(value) == "string" then
				local enumItem = Enum.RunContext[value]
				if enumItem then
					inst.RunContext = enumItem
				end
			else
				inst[key] = decodeValue(value)
			end
		end)
		if not ok then
			return { ok = false, error = tostring(err), changed = changed }
		end
		table.insert(changed, key)
	end
	waypoint("Abraxius: Set properties")
	return { ok = true, changed = changed, instance = instanceInfo(inst) }
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
				out[key] = encodeValue(value)
			end
		end
	end
	return { ok = true, instance = instanceInfo(inst), properties = out }
end

commandHandlers["create_instance"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	local parent = resolvePath(payload.parent or "Workspace")
	if not parent then return { ok = false, error = "Parent not found: " .. tostring(payload.parent) } end
	local created: Instance? = nil
	local ok, err = pcall(function()
		created = Instance.new(tostring(payload.className))
		created.Name = tostring(payload.name or payload.className)
		for key, value in pairs(payload.properties or {}) do
			(created :: any)[key] = decodeValue(value)
		end
		created.Parent = parent
	end)
	if not ok or not created then
		if created then created:Destroy() end
		return { ok = false, error = tostring(err) }
	end
	waypoint("Abraxius: Create " .. created.Name)
	return { ok = true, instance = instanceInfo(created) }
end

commandHandlers["import_model"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	if payload.confirm ~= true then return { ok = false, error = "Model import requires confirm=true" } end
	if payload.format ~= "rbxm" and payload.format ~= "rbxmx" then
		return { ok = false, error = "format must be rbxm or rbxmx" }
	end
	if typeof(payload.contentBase64) ~= "string" or payload.contentBase64 == "" then
		return { ok = false, error = "contentBase64 must be a non-empty string" }
	end
	if #payload.contentBase64 > 28 * 1024 * 1024 then
		return { ok = false, error = "Encoded model exceeds the 20 MiB asset limit" }
	end
	local parent = resolvePath(payload.parent)
	if not parent then return { ok = false, error = "Parent not found: " .. tostring(payload.parent) } end
	local name = tostring(payload.name or "")
	if name == "" or string.find(name, ".", 1, true) then
		return { ok = false, error = "name must be a non-empty path segment" }
	end
	local existing = parent:FindFirstChild(name)
	if existing and payload.replace ~= true then
		return { ok = false, error = "An instance already exists at " .. parent:GetFullName() .. "." .. name }
	end

	local instances: { Instance }? = nil
	local loaded, loadError = pcall(function()
		local decoded = EncodingService:Base64Decode(buffer.fromstring(payload.contentBase64))
		instances = SerializationService:DeserializeInstancesAsync(decoded)
	end)
	if not loaded or not instances or #instances == 0 then
		return { ok = false, error = "Could not deserialize model: " .. tostring(loadError or "asset contained no instances") }
	end

	local root: Instance
	if #instances == 1 then
		root = instances[1]
	else
		local container = Instance.new("Model")
		for _, instance in instances do instance.Parent = container end
		root = container
	end
	root.Name = name
	local committed, commitError = pcall(function()
		waypoint("Abraxius: Before import " .. name)
		if existing then existing:Destroy() end
		root.Parent = parent
	end)
	if not committed then
		root:Destroy()
		return { ok = false, error = "Could not commit model: " .. tostring(commitError) }
	end
	local verified = parent:FindFirstChild(name)
	if verified ~= root then
		root:Destroy()
		return { ok = false, error = "Studio did not commit the imported model" }
	end
	waypoint("Abraxius: Import " .. name)
	return {
		ok = true, instance = instanceInfo(root), format = payload.format,
		rootCount = #instances, descendantCount = #root:GetDescendants(), replaced = existing ~= nil,
	}
end

commandHandlers["clone_instance"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	local source = resolvePath(payload.path)
	if not source then return { ok = false, error = "Instance not found: " .. tostring(payload.path) } end
	local parent = if payload.parent then resolvePath(payload.parent) else source.Parent
	if not parent then return { ok = false, error = "Clone parent not found" } end
	local ok, clone = pcall(source.Clone, source)
	if not ok or not clone then return { ok = false, error = tostring(clone) } end
	clone.Name = tostring(payload.name or (source.Name .. " Copy"))
	clone.Parent = parent
	waypoint("Abraxius: Clone " .. source.Name)
	return { ok = true, instance = instanceInfo(clone), source = instanceInfo(source) }
end

commandHandlers["rename_instance"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	local inst = resolvePath(payload.path)
	if not inst then return { ok = false, error = "Instance not found: " .. tostring(payload.path) } end
	if inst == game or inst.Parent == game then return { ok = false, error = "Cannot rename a data model or service" } end
	local name = tostring(payload.name or "")
	if name == "" then return { ok = false, error = "name is required" } end
	local previousPath = string.gsub(inst:GetFullName(), "^game%.", "")
	local previousName = inst.Name
	inst.Name = name
	waypoint("Abraxius: Rename " .. previousName)
	return { ok = true, previousPath = previousPath, previousName = previousName, instance = instanceInfo(inst) }
end

commandHandlers["reparent_instance"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	local inst = resolvePath(payload.path)
	local parent = resolvePath(payload.parent)
	if not inst then return { ok = false, error = "Instance not found: " .. tostring(payload.path) } end
	if not parent then return { ok = false, error = "Parent not found: " .. tostring(payload.parent) } end
	if inst == game or inst.Parent == game or inst:IsA("ServiceProvider") then
		return { ok = false, error = "Cannot reparent a data model or service" }
	end
	if parent:IsDescendantOf(inst) then return { ok = false, error = "Cannot parent an instance beneath itself" } end
	local previousParent = inst.Parent
	inst.Parent = parent
	waypoint("Abraxius: Reparent " .. inst.Name)
	return { ok = true, instance = instanceInfo(inst), previousParent = if previousParent then instanceInfo(previousParent) else nil }
end

commandHandlers["transform_instance"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	local inst = resolvePath(payload.path)
	if not inst then return { ok = false, error = "Instance not found: " .. tostring(payload.path) } end
	local target = if payload.cframe then decodeValue(payload.cframe) else nil
	if not target and payload.position then
		local position = decodeValue(payload.position)
		local current = if inst:IsA("PVInstance") then inst:GetPivot() else nil
		if current then target = CFrame.new(position) * current.Rotation end
	end
	if typeof(target) ~= "CFrame" then return { ok = false, error = "Provide a typed CFrame or Vector3 position" } end
	local ok, err = pcall(function()
		if inst:IsA("PVInstance") then
			inst:PivotTo(target)
		else
			error("Instance is not transformable: " .. inst.ClassName)
		end
	end)
	if not ok then return { ok = false, error = tostring(err) } end
	waypoint("Abraxius: Transform " .. inst.Name)
	return { ok = true, instance = instanceInfo(inst), pivot = encodeValue(inst:GetPivot()) }
end

commandHandlers["delete_instance"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	if payload.confirm ~= true then return { ok = false, error = "Deletion requires confirm=true" } end
	local inst = resolvePath(payload.path)
	if not inst then return { ok = false, error = "Instance not found: " .. tostring(payload.path) } end
	if inst == game or inst.Parent == game or inst:IsA("ServiceProvider") then
		return { ok = false, error = "Cannot delete a data model or service" }
	end
	local deleted = instanceInfo(inst)
	waypoint("Abraxius: Before delete " .. inst.Name)
	inst:Destroy()
	waypoint("Abraxius: Delete " .. deleted.name)
	return { ok = true, deleted = deleted }
end

local BATCH_MUTATIONS: { [string]: boolean } = {
	write_source = true, create_script = true, set_properties = true, create_instance = true,
	clone_instance = true, rename_instance = true, reparent_instance = true,
	transform_instance = true, delete_instance = true,
}

commandHandlers["batch"] = function(payload: any): any
	local editable, editError = requireEditMode()
	if not editable then return { ok = false, error = editError } end
	if transactionActive then return { ok = false, error = "Nested batches are not supported" } end
	if typeof(payload.operations) ~= "table" then return { ok = false, error = "operations must be an array" } end
	if #payload.operations == 0 then return { ok = false, error = "operations must not be empty" } end
	if #payload.operations > 50 then return { ok = false, error = "batch is limited to 50 operations" } end
	for index, operation in ipairs(payload.operations) do
		local operationType = if typeof(operation) == "table" then operation.type else nil
		if not BATCH_MUTATIONS[operationType] then
			return { ok = false, error = "Unsupported batch operation at index " .. index .. ": " .. tostring(operationType) }
		end
	end
	local recordingId = ChangeHistoryService:TryBeginRecording("AbraxiusBatch", tostring(payload.name or "Abraxius batch"))
	if not recordingId then return { ok = false, error = "Could not begin a Studio history recording" } end
	transactionActive = true
	local results = {}
	for index, operation in ipairs(payload.operations) do
		local handler = commandHandlers[operation.type]
		local called, result = pcall(handler, operation)
		if not called or typeof(result) ~= "table" or result.ok ~= true then
			transactionActive = false
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
			return {
				ok = false, rolledBack = true, failedIndex = index,
				error = if called then tostring(result and result.error or "Operation failed") else tostring(result),
				results = results,
			}
		end
		table.insert(results, result)
	end
	transactionActive = false
	ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
	return { ok = true, committed = true, count = #results, results = results }
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
	if playDataEnabled then appendBounded(analyticsScriptActivity, {
		time = DateTime.now().UnixTimestampMillis,
		path = path,
		sourceLength = #source,
		sourceHash = hashSource(source),
		playtest = RunService:IsRunning(),
	}, 100) end
	local now = os.clock()
	local pending = pendingSourceChanges[path]
	if pending then
		pending.source = source
		pending.sourceLength = #source
		pending.lastChangedAt = now
		pending.changeCount += 1
	else
		pendingSourceChanges[path] = {
			path = path,
			previousHash = if last then hashSource(last) else nil,
			source = source,
			sourceLength = #source,
			firstChangedAt = now,
			lastChangedAt = now,
			changeCount = 1,
		}
	end
end

local function flushSourceChanges()
	local now = os.clock()
	for path, pending in pairs(pendingSourceChanges) do
		if now - pending.lastChangedAt >= SOURCE_CHANGE_DEBOUNCE then
			queueEvent({
				type = "source_changed",
				path = path,
				previousHash = pending.previousHash,
				sourceHash = hashSource(pending.source),
				sourceLength = pending.sourceLength,
				changeCount = pending.changeCount,
				durationMs = math.floor((pending.lastChangedAt - pending.firstChangedAt) * 1000),
			})
			pendingSourceChanges[path] = nil
		end
	end
end

local function watchInstance(inst: Instance)
	if not inst:IsA("LuaSourceContainer") then return end
	if sourceConnections[inst] then return end
	local conn = inst:GetPropertyChangedSignal("Source"):Connect(function()
		reportSourceChanged(inst)
	end)
	sourceConnections[inst] = conn
	local path = string.gsub(inst:GetFullName(), "^game%.", "")
	lastReportedSource[path] = inst.Source
	lastReportedPath[inst] = path
	scriptNameConnections[inst] = inst:GetPropertyChangedSignal("Name"):Connect(function()
		local previousPath = lastReportedPath[inst]
		local nextPath = string.gsub(inst:GetFullName(), "^game%.", "")
		lastReportedPath[inst] = nextPath
		if previousPath and previousPath ~= nextPath then
			lastReportedSource[nextPath] = lastReportedSource[previousPath]
			lastReportedSource[previousPath] = nil
			if pendingSourceChanges[previousPath] then
				pendingSourceChanges[nextPath] = pendingSourceChanges[previousPath]
				pendingSourceChanges[nextPath].path = nextPath
				pendingSourceChanges[previousPath] = nil
			end
			queueEvent({ type = "script_path_changed", from = previousPath, path = nextPath })
		end
	end)
end

local function unwatchInstance(inst: Instance)
	local conn = sourceConnections[inst]
	if conn then
		conn:Disconnect()
		sourceConnections[inst] = nil
	end
	local nameConn = scriptNameConnections[inst]
	if nameConn then nameConn:Disconnect() end
	scriptNameConnections[inst] = nil
	lastReportedPath[inst] = nil
	lastReportedSource[string.gsub(inst:GetFullName(), "^game%.", "")] = nil
end

local function watchService(service: Instance)
	for _, child in ipairs(service:GetDescendants()) do
		watchInstance(child)
	end
	local addedConn = service.DescendantAdded:Connect(function(child)
		watchInstance(child)
		hierarchyChanges.added += 1
		if #hierarchyChanges.paths < 20 then
			table.insert(hierarchyChanges.paths, "+" .. string.gsub(child:GetFullName(), "^game%.", ""))
		end
	end)
	local removedConn = service.DescendantRemoving:Connect(function(child)
		hierarchyChanges.removed += 1
		if #hierarchyChanges.paths < 20 then
			table.insert(hierarchyChanges.paths, "-" .. string.gsub(child:GetFullName(), "^game%.", ""))
		end
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
	for inst, conn in pairs(scriptNameConnections) do
		conn:Disconnect()
		scriptNameConnections[inst] = nil
		lastReportedPath[inst] = nil
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


-- Studio activity listeners --------------------------------------------------
local activityConnections: { RBXScriptConnection } = {}

local function startActivityListeners()
	table.insert(activityConnections, StudioService:GetPropertyChangedSignal("ActiveScript"):Connect(function()
		local active = StudioService.ActiveScript
		queueEvent({
			type = "active_script_changed",
			path = if active then string.gsub(active:GetFullName(), "^game%.", "") else nil,
		})
	end))

	table.insert(activityConnections, LogService.MessageOut:Connect(function(message, messageType)
		if Logger.isOwnMessage(message) then return end
		local output = classifyOutput(message, messageType)
		if playDataEnabled then
			appendBounded(analyticsOutput, output, 200)
			if output.level == "error" then playSession.errors += 1
			elseif output.level == "warning" then playSession.warnings += 1
			else playSession.prints += 1 end
		end
		if output.level == "error" or output.level == "warning" then
			queueEvent({ type = "output", level = messageType.Name, message = string.sub(message, 1, 2000) })
		end
	end))

	table.insert(activityConnections, ChangeHistoryService.OnUndo:Connect(function(waypoint)
		queueEvent({ type = "history", action = "undo", name = waypoint })
	end))
	table.insert(activityConnections, ChangeHistoryService.OnRedo:Connect(function(waypoint)
		queueEvent({ type = "history", action = "redo", name = waypoint })
	end))
	pcall(function()
		table.insert(activityConnections, ChangeHistoryService.OnRecordingFinished:Connect(function(name, displayName, _, operation)
			queueEvent({
				type = "history",
				action = "recording_finished",
				name = displayName or name,
				operation = tostring(operation),
			})
		end))
	end)
end

local function stopActivityListeners()
	for _, connection in ipairs(activityConnections) do connection:Disconnect() end
	table.clear(activityConnections)
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

local function friendlyConnectionError(err: string): string
	local clean = string.gsub(tostring(err), "^HttpError:%s*", "")
	if clean == "ConnectFail" then return "host unavailable" end
	return clean
end

local function logConnectionIssue(context: string, err: string)
	local now = os.clock()
	local clean = friendlyConnectionError(err)
	if clean ~= lastConnectionError or now - lastConnectionLogAt >= 30 then
		Logger.disconnect(string.format("%s; retrying in %ds (%s)", context, retryDelay, clean))
		lastConnectionError = clean
		lastConnectionLogAt = now
	end
end

local function register(): boolean
	local payload = getModePayload()
	payload.version = PLUGIN_VERSION
	payload.sessionId = sessionId
	local ok, result = post("/plugin/register", payload)
	if ok and result and result.sessionId then
		sessionId = result.sessionId
		connected = true
		retryDelay = 1
		lastConnectionError = ""
		lastConnectionLogAt = -math.huge
		if ui.errorLabel then
			ui.errorLabel.Text = "None"
			ui.errorLabel.TextColor3 = PALETTE.text
		end
		updatePanel()
		Logger.connect("Registered session " .. tostring(sessionId))
		return true
	end
	connected = false
	local err = tostring(result or "register failed")
	if ui.errorLabel then
		ui.errorLabel.Text = err
		ui.errorLabel.TextColor3 = PALETTE.red
	end
	if isHttpRestricted(err) then
		logConnectionIssue("HTTP unavailable in this DataModel", err)
	else
		logConnectionIssue("Registration unavailable", err)
	end
	return false
end

local function runLoop()
	while true do
		if loopStopped then break end
		if not connected or not sessionId then
			register()
			if not connected then
				task.wait(retryDelay)
				retryDelay = math.min(retryDelay * 2, MAX_RETRY_DELAY)
				continue
			end
		end

		local mode = currentMode()
		if mode ~= lastMode then
			queueEvent({ type = "mode_changed", from = lastMode, mode = mode })
			updatePlaySessionState()
			lastMode = mode
		end
		if hierarchyChanges.added > 0 or hierarchyChanges.removed > 0 then
			queueEvent({
				type = "hierarchy_changed",
				added = hierarchyChanges.added,
				removed = hierarchyChanges.removed,
				paths = hierarchyChanges.paths,
			})
			hierarchyChanges = { added = 0, removed = 0, paths = {} }
		end
		flushSourceChanges()
		if os.clock() - lastContextSnapshot >= CONTEXT_SNAPSHOT_INTERVAL then
			queueEvent({ type = "context_snapshot", snapshot = buildContextSnapshot() })
			lastContextSnapshot = os.clock()
		end
		if os.clock() - lastAnalyticsSnapshot >= ANALYTICS_INTERVAL then
			local analyticsOk = postTo(ANALYTICS_URL, "/studio", {
				sessionId = sessionId,
				snapshot = sampleStudioAnalytics(),
			})
			if analyticsOk then lastAnalyticsSnapshot = os.clock() end
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
			currentDataModel = if RunService:IsRunning() then "Play" elseif RunService:IsEdit() then "Edit" else "Unknown",
			placeId = game.PlaceId,
		})

		lastLatencyMs = math.floor((os.clock() - startTime) * 1000)
		lastHeartbeat = os.time()

		if not ok then
			local err = tostring(result)
			if isHttpRestricted(err) then
				logConnectionIssue("HTTP unavailable in this DataModel", err)
			else
				logConnectionIssue("Connection lost", err)
			end
			for i = #eventsToSend, 1, -1 do
				table.insert(eventQueue, 1, eventsToSend[i])
			end
			connected = false
			if typeof(result) == "table" and result.error == "Invalid or missing session" then
				sessionId = nil
			end
			if ui.errorLabel then
				ui.errorLabel.Text = tostring(result)
				ui.errorLabel.TextColor3 = PALETTE.red
			end
			updatePanel()
			task.wait(retryDelay)
			retryDelay = math.min(retryDelay * 2, MAX_RETRY_DELAY)
			continue
		end

		connected = true
		retryDelay = 1
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
		if eventListDirty then
			refreshEventList()
		end
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
	startActivityListeners()
	lastMode = currentMode()
	lastContextSnapshot = os.clock()
	lastAnalyticsSnapshot = 0
	queueEvent({ type = "context_snapshot", snapshot = buildContextSnapshot() })

	plugin.Unloading:Connect(function()
		loopStopped = true
		stopWatching()
		stopSelectionListener()
		stopActivityListeners()
		if widget then
			widget:Destroy()
			widget = nil
		end
	end)

	task.spawn(runLoop)
	Logger.plugin("Companion ready (v" .. PLUGIN_VERSION .. ")")
end

init()
