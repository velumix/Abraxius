--!strict
-- Abraxius Studio Companion Plugin
-- Connects to the local Abraxius plugin server on http://localhost:13471
-- and reports live Studio state (selection, source changes, play mode).

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")

local PLUGIN_URL = "http://localhost:13471"
local POLL_INTERVAL = 0.5

local plugin = plugin
if not plugin then
	warn("[AbraxiusCompanion] No plugin global found; this script must run as a plugin.")
	return
end

local sessionId: string? = nil
local connected = false
local commandHandlers: { [string]: (payload: any) -> any } = {}
local eventQueue: { any } = {}
local recentEvents: { any } = {}
local sourceConnections: { [Instance]: RBXScriptConnection } = {}
local lastReportedSource: { [string]: string } = {}
local subscriptions: { [string]: boolean } = {
	selection_changed = true,
	source_changed = true,
}
local widget: DockWidgetPluginGui? = nil
local statusLabel: TextLabel? = nil
local sessionLabel: TextLabel? = nil
local modeLabel: TextLabel? = nil
local watchedLabel: TextLabel? = nil
local pendingLabel: TextLabel? = nil
local eventsLabel: TextLabel? = nil
local lastErrorLabel: TextLabel? = nil
local lastError = "None"

local function getModePayload(): any
	return {
		isEdit = RunService:IsEdit(),
		isRunning = RunService:IsRunning(),
		currentDataModel = if RunService:IsEdit() then "Edit" else "Play",
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
	while #recentEvents > 8 do
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

local function createText(parent: Instance, text: string, height: number, textSize: number, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = if bold then Enum.Font.SourceSansBold else Enum.Font.SourceSans
	label.Text = text
	label.TextColor3 = Color3.fromRGB(230, 236, 245)
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Size = UDim2.new(1, 0, 0, height)
	label.Parent = parent
	return label
end

local function createButton(parent: Instance, text: string): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(55, 73, 96)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.SourceSansBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Size = UDim2.new(1, 0, 0, 30)
	button.Parent = parent
	return button
end

local function formatEvent(event: any): string
	if typeof(event) ~= "table" then
		return "unknown"
	end
	if event.type == "source_changed" then
		return "source_changed: " .. tostring(event.path)
	end
	if event.type == "selection_changed" then
		local paths = event.paths or {}
		if #paths == 0 then
			return "selection_changed: none"
		end
		return "selection_changed: " .. table.concat(paths, ", ")
	end
	return tostring(event.type or "event")
end

local function updatePanel()
	if not statusLabel then return end
	statusLabel.Text = "Status: " .. (if connected then "Connected" else "Disconnected")
	statusLabel.TextColor3 = if connected then Color3.fromRGB(94, 223, 148) else Color3.fromRGB(255, 120, 120)
	if sessionLabel then
		sessionLabel.Text = "Session: " .. (sessionId or "none")
	end
	if modeLabel then
		modeLabel.Text = "Mode: " .. (if RunService:IsEdit() then "Edit" else "Play/Running")
	end
	if watchedLabel then
		local count = 0
		for _ in pairs(sourceConnections) do
			count += 1
		end
		watchedLabel.Text = "Watched scripts: " .. tostring(count)
	end
	if pendingLabel then
		pendingLabel.Text = "Queued events: " .. tostring(#eventQueue)
	end
	if lastErrorLabel then
		lastErrorLabel.Text = "Last error: " .. lastError
	end
	if eventsLabel then
		local lines = {}
		for i = 1, math.min(#recentEvents, 6) do
			table.insert(lines, tostring(i) .. ". " .. formatEvent(recentEvents[i]))
		end
		eventsLabel.Text = if #lines == 0 then "Recent events:\nNone" else "Recent events:\n" .. table.concat(lines, "\n")
	end
end

local function createPanel()
	local info = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		320,
		420,
		260,
		280
	)
	widget = plugin:CreateDockWidgetPluginGui("AbraxiusCompanionPanel", info)
	widget.Title = "Abraxius Companion"

	local root = Instance.new("Frame")
	root.BackgroundColor3 = Color3.fromRGB(24, 30, 38)
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root

	createText(root, "Abraxius Companion", 28, 20, true)
	statusLabel = createText(root, "Status: Disconnected", 24, 16, true)
	sessionLabel = createText(root, "Session: none", 22, 14)
	modeLabel = createText(root, "Mode: unknown", 22, 14)
	watchedLabel = createText(root, "Watched scripts: 0", 22, 14)
	pendingLabel = createText(root, "Queued events: 0", 22, 14)
	lastErrorLabel = createText(root, "Last error: None", 42, 14)

	local refreshButton = createButton(root, "Refresh Status")
	refreshButton.MouseButton1Click:Connect(updatePanel)

	local selectionButton = createButton(root, "Print Selection")
	selectionButton.MouseButton1Click:Connect(function()
		local result = commandHandlers["get_selection"]({})
		print("[AbraxiusCompanion] Selection:", HttpService:JSONEncode(result.selection or {}))
	end)

	eventsLabel = createText(root, "Recent events:\nNone", 150, 13)
	updatePanel()
end

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

local function register(): boolean
	local payload = getModePayload()
	payload.version = "1.0.1"
	local ok, result = post("/plugin/register", payload)
	if ok and result and result.sessionId then
		sessionId = result.sessionId
		connected = true
		lastError = "None"
		updatePanel()
		print("[AbraxiusCompanion] Registered with session", sessionId)
		return true
	end
	connected = false
	lastError = tostring(result or "register failed")
	updatePanel()
	return false
end

local function runLoop()
	while true do
		if not connected or not sessionId then
			register()
			if not connected then
				task.wait(2)
				continue
			end
		end

		local eventsToSend = eventQueue
		eventQueue = {}

		local ok, result = post("/plugin/report", {
			sessionId = sessionId,
			events = eventsToSend,
			heartbeat = true,
			isEdit = RunService:IsEdit(),
			isRunning = RunService:IsRunning(),
			currentDataModel = if RunService:IsEdit() then "Edit" else "Play",
			placeId = game.PlaceId,
		})

		if not ok then
			warn("[AbraxiusCompanion] Report failed:", tostring(result))
			connected = false
			sessionId = nil
			lastError = tostring(result)
			updatePanel()
			task.wait(2)
			continue
		end

		connected = true
		lastError = "None"
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
		task.wait(POLL_INTERVAL)
	end
end

local function init()
	if not pcall(function() return HttpService.RequestAsync end) then
		warn("[AbraxiusCompanion] HttpService.RequestAsync not available. Enable HTTP requests in Studio settings.")
		return
	end

	local toolbar = plugin:CreateToolbar("Abraxius")
	local button = toolbar:CreateButton("Companion", "Abraxius Studio Companion", "")
	createPanel()
	button.Click:Connect(function()
		if widget then
			widget.Enabled = not widget.Enabled
			updatePanel()
		else
			print("[AbraxiusCompanion] Connected:", connected, "Session:", sessionId or "none")
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
	print("[AbraxiusCompanion] Plugin started")
end

init()
