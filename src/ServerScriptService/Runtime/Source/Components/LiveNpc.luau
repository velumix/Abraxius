local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local SimplePath = require(Modules.SimplePath)
local Scheduler = Mince.Scheduler.getDefault()

local LiveNpc = Mince.Component({ Tag = "LiveNpc" })
local Poi = Mince.Component({ Tag = "Poi" })

local ConversationEvent = Mince:GetEvent("LiveNpcConversation")

local poiCache: { Instance } = {}

local DEFAULT_AGENT_PARAMETERS = {
	AgentHeight = 4.5,
	AgentRadius = 3.5,
	AgentCanJump = false,
}

local function shallowCopy(source)
	return table.clone(source)
end

function Poi:Construct()
	table.insert(poiCache, self.Instance)
	self.Instance.Transparency = 1
end

function Poi:Removing()
	for i, poi in ipairs(poiCache) do
		if poi == self.Instance then
			table.remove(poiCache, i)
			break
		end
	end
end

function LiveNpc:Construct()
	self.Model = self.Instance
	self.Humanoid = self.Model:WaitForChild("Humanoid")
	self.RootPart = self.Model:WaitForChild("HumanoidRootPart")
	self.Head = self.Model:FindFirstChild("Head")
	self.Data = nil
	self.ChatColor = Enum.ChatColor.White
	self.SpeechLines = nil
	self.NextSpeechTime = math.huge
	self.LastMoveCheck = tick()
	self.LastRootPosition = nil
	self.StuckSeconds = 0
	self.IsWaitingAtPoi = false
	self.ActiveSpeaker = nil
	self.IsConversationFrozen = false
	self.ConversationConnection = nil
	self.PlayerRemovingConnection = nil
	self.PreferNearestPoi = false

	if self.Model then
		self.Model:SetAttribute("CanConverse", false)
	end

	local Data = self.Model:FindFirstChild("Data")

	if Data then
		self.Data = require(Data)
		if typeof(self.Data.SpeechDelay) == "table" then
			self.MinSpeechDelay = self.Data.SpeechDelay.Min or self.MinSpeechDelay
			self.MaxSpeechDelay = self.Data.SpeechDelay.Max or self.MaxSpeechDelay
		elseif typeof(self.Data.SpeechDelay) == "number" then
			self.MinSpeechDelay = self.Data.SpeechDelay
			self.MaxSpeechDelay = self.Data.SpeechDelay
		end

		if typeof(self.Data.ChatColor) == "EnumItem" then
			self.ChatColor = self.Data.ChatColor
		end

		local customLines = self.Data.Dialog or self.Data.SpeechLines or self.Data.Dialogue
		if typeof(customLines) == "table" and #customLines > 0 then
			self.SpeechLines = customLines
		end

		self.Data.Init(self)
	end

	self.IsMoving = false
	self.IsThinking = false
	self.NextMoveTime = tick()
	self.Connection = nil
	self.CurrentPoi = nil
	self.StuckSeconds = 0
	self.FailedPois = {}
	self.RecentPois = {}
	self.MaxRecentPois = 3
	self.MaxPoiChecks = 4
	self.AgentParameters = self:_agentParams()
	self.CostPath = nil
	self.NextCostCheck = 0
	self.NextRepathTime = 0
	local desiredSpacing = if self.Data and self.Data.WaypointSpacing then tonumber(self.Data.WaypointSpacing) else nil
	self.WaypointSpacing = math.clamp(desiredSpacing or 3, 1, 12)

	self.StateChangedConnection = nil

	pcall(function()
		self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
	end)

	self.Humanoid.PlatformStand = false

	self.StateChangedConnection = self.Humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.FallingDown or newState == Enum.HumanoidStateType.PlatformStanding then
			task.defer(function()
				if self.Humanoid then
					local currentState = self.Humanoid:GetState()
					if
						currentState == Enum.HumanoidStateType.FallingDown
						or currentState == Enum.HumanoidStateType.PlatformStanding
					then
						self.Humanoid.PlatformStand = false
						self.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
					end
				end
			end)
		end
	end)

	self.Path = SimplePath.new(self.Model, self.AgentParameters, {
		TIME_VARIANCE = 0.15,
		COMPARISON_CHECKS = 8,
		JUMP_WHEN_STUCK = true,
		WAYPOINT_SPACING = self.WaypointSpacing,
	})

	self.Path.Visualize = false
	self.PathBlockedConnection = self.Path.Blocked:Connect(function()
		self:_jump()
	end)

	self.PathReachedConnection = self.Path.Reached:Connect(function()
		self.IsMoving = false
		self.NextMoveTime = tick() + self.Data.WaitBetweenPoi
		self.CurrentPoi = nil
		self.StuckSeconds = 0
		self:_enterWait()
		if self.Data and typeof(self.Data.SaySomething) == "function" then
			self.Data.SaySomething(self)
		end
	end)

	self.PathErrorConnection = self.Path.Error:Connect(function(errorType)
		warn(`Path error: {errorType}`)
		if self.CurrentPoi then
			self.FailedPois[self.CurrentPoi] = tick() + 10
			self.CurrentPoi = nil
		end
		self.IsMoving = false
		self.NextMoveTime = tick() + self.Data.WaitBetweenPoi
		self.PreferNearestPoi = true
		self:_enterWait()
		self:_queueRepath()
	end)

	self.ConversationConnection = ConversationEvent.Event:Connect(function(player, action, npcInstance)
		if npcInstance ~= self.Model then
			return
		end

		if action == "Start" then
			self:_startConversation(player)
		elseif action == "Stop" then
			self:_stopConversation(player)
		end
	end)

	self.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		if player == self.ActiveSpeaker then
			self:_stopConversation(player, true)
		end
	end)

	self:_startMove()
end

function LiveNpc:_startMove()
	self.Connection = Scheduler:every(0.1, function()
		if not self.Model.Parent then
			if self.Connection then
				Scheduler:cancel(self.Connection)
				self.Connection = nil
			end
			return
		end

		if self.IsMoving then
			self:_checkStuck()
		end

		if not self.IsMoving and not self.IsThinking and tick() >= self.NextMoveTime then
			self.IsThinking = true
			task.spawn(function()
				local success, target = pcall(function()
					return self:_pickPoi()
				end)
				self.IsThinking = false

				if not success then
					warn("Error picking POI:", target)
					self.NextMoveTime = tick() + self.Data.WaitBetweenPoi
					self:_enterWait()
					return
				end

				if target then
					self.IsMoving = true
					self.NextSpeechTime = math.huge
					self.LastRootPosition = self.RootPart.Position
					self.LastMoveCheck = tick()
					self.StuckSeconds = 0
					self:_exitWait()
					local pathSuccess = self.Path:Run(target)
					if not pathSuccess then
						self.IsMoving = false
						if self.CurrentPoi then
							self.FailedPois[self.CurrentPoi] = tick() + 10
							self.CurrentPoi = nil
						end
						self.NextMoveTime = tick() + self.Data.WaitBetweenPoi
						self:_enterWait()
						self:_queueRepath()
					else
						self.Humanoid.PlatformStand = false
						self.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
					end
				else
					self.NextMoveTime = tick() + self.Data.WaitBetweenPoi
					self:_enterWait()
				end
			end)
		end
	end, Mince.TaskScheduler.Priority.NORMAL, `LiveNpc_{self.Model.Name}`)
end

function LiveNpc:_checkStuck()
	if not self.IsMoving or not self.RootPart then
		return
	end

	local now = tick()
	if now - self.LastMoveCheck < 1 then
		return
	end

	local currentPosition = self.RootPart.Position
	if self.LastRootPosition then
		local delta = (currentPosition - self.LastRootPosition).Magnitude
		if delta < 0.5 then
			self.StuckSeconds += now - self.LastMoveCheck
		else
			self.StuckSeconds = 0
		end
	end

	self.LastRootPosition = currentPosition
	self.LastMoveCheck = now

	if self.StuckSeconds >= 2 then
		self.StuckSeconds = 0
		self.PreferNearestPoi = true
		self:_forceMove()
	end
end

function LiveNpc:_forceMove()
	if not self.Humanoid then
		return
	end

	task.spawn(function()
		self:_jump()
		task.wait(0.25)
		if self.RootPart then
			local randomDirection = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit
			if randomDirection.Magnitude > 0 then
				self.RootPart:ApplyImpulse(randomDirection * self.RootPart.AssemblyMass * 25)
			end
		end
	end)
end

function LiveNpc:_setCanTalk(canTalk: boolean)
	if not self.Model then
		return
	end

	self.Model:SetAttribute("CanConverse", canTalk and true or false)
end

function LiveNpc:_jump()
	if not self.Humanoid then
		return
	end

	self.Humanoid.Jump = true
	if self.Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

function LiveNpc:_agentParams()
	local params = shallowCopy(DEFAULT_AGENT_PARAMETERS)
	local data = self.Data

	local function applyOverride(key, value)
		if params[key] == nil then
			return
		end

		local valueType = typeof(value)
		local expectedType = typeof(params[key])
		if valueType == expectedType then
			params[key] = value
		end
	end

	if typeof(data) == "table" then
		local group = data.AgentParameters or data.AgentSettings or data.Agent
		if typeof(group) == "table" then
			for key, value in pairs(group) do
				applyOverride(key, value)
			end
		end

		if typeof(data.AgentRadius) == "number" then
			params.AgentRadius = data.AgentRadius
		end

		if typeof(data.AgentHeight) == "number" then
			params.AgentHeight = data.AgentHeight
		end

		if typeof(data.AgentCanJump) == "boolean" then
			params.AgentCanJump = data.AgentCanJump
		end

		if typeof(data.AgentClearancePadding) == "number" then
			params.AgentRadius += math.max(0, data.AgentClearancePadding)
		end
	end

	params.AgentRadius = math.clamp(params.AgentRadius, 2.5, 10)
	params.AgentHeight = math.clamp(params.AgentHeight, 4, 15)

	return params
end

function LiveNpc:_enterWait()
	self.IsWaitingAtPoi = true
	if not self.ActiveSpeaker then
		self:_setCanTalk(true)
	end
end

function LiveNpc:_exitWait()
	self.IsWaitingAtPoi = false
	self:_setCanTalk(false)
end

function LiveNpc:_startConversation(player: Player)
	if not player or not player:IsA("Player") then
		return
	end

	if self.ActiveSpeaker and self.ActiveSpeaker ~= player then
		return
	end

	if self.IsMoving then
		self.IsMoving = false
		self.NextMoveTime = math.huge
		self.PreferNearestPoi = true
		if self.Path and self.Path.Stop then
			self.Path:Stop()
		end
		self:_enterWait()
	end

	if not self.IsWaitingAtPoi or self.IsConversationFrozen then
		return
	end

	self.ActiveSpeaker = player
	self.IsConversationFrozen = true
	self.NextMoveTime = math.huge
	self:_setCanTalk(false)
end

function LiveNpc:_stopConversation(player: Player?, force: boolean?)
	if not self.IsConversationFrozen then
		return
	end

	if not force and self.ActiveSpeaker and self.ActiveSpeaker ~= player then
		return
	end

	self.ActiveSpeaker = nil
	self.IsConversationFrozen = false
	self.NextMoveTime = tick() + self.Data.WaitBetweenPoi
	self:_enterWait()
end

function LiveNpc:_poiPosition(poi: Instance): Vector3?
	if poi:IsA("BasePart") then
		return poi.Position
	elseif poi:IsA("Model") and poi.PrimaryPart then
		return poi.PrimaryPart.Position
	end

	return nil
end

function LiveNpc:_isRecentPoi(poi: Instance): boolean
	for _, recent in ipairs(self.RecentPois) do
		if recent == poi then
			return true
		end
	end

	return false
end

function LiveNpc:_rememberPoi(poi: Instance)
	if not poi then
		return
	end

	local cleaned = {}
	for _, recent in ipairs(self.RecentPois) do
		if recent and recent.Parent then
			table.insert(cleaned, recent)
		end
	end

	self.RecentPois = cleaned

	table.insert(self.RecentPois, poi)
	self.LastPoi = poi

	while #self.RecentPois > self.MaxRecentPois do
		table.remove(self.RecentPois, 1)
	end
end

function LiveNpc:_nearestPoi(pois: { Instance }): Instance?
	if not self.RootPart then
		return nil
	end

	local rootPosition = self.RootPart.Position
	local nearestPoi = nil
	local nearestDistance = math.huge

	for _, poi in ipairs(pois) do
		local poiPosition = self:_poiPosition(poi)
		if poiPosition then
			local distance = (poiPosition - rootPosition).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPoi = poi
			end
		end
	end

	return nearestPoi
end

function LiveNpc:_poiDistance(poi: Instance): number
	if not self.RootPart then
		return math.huge
	end

	local position = self:_poiPosition(poi)
	if not position then
		return math.huge
	end

	return (position - self.RootPart.Position).Magnitude
end

function LiveNpc:_routeCost(poi: Instance): number
	if not self.RootPart then
		return math.huge
	end

	local destination = self:_poiPosition(poi)
	if not destination then
		return math.huge
	end

	local now = os.clock()
	if now < (self.NextCostCheck or 0) then
		return (destination - self.RootPart.Position).Magnitude
	end
	self.NextCostCheck = now + 0.1

	self.CostPath = self.CostPath or PathfindingService:CreatePath(self.AgentParameters)

	local ok, result = pcall(function()
		self.CostPath:ComputeAsync(self.RootPart.Position, destination)
		return self.CostPath
	end)

	if not ok or result.Status ~= Enum.PathStatus.Success then
		self.FailedPois[poi] = tick() + 20
		return math.huge
	end

	local cost = 0
	local waypoints = result:GetWaypoints()
	for index = 2, #waypoints do
		cost += (waypoints[index].Position - waypoints[index - 1].Position).Magnitude
	end

	return cost
end

function LiveNpc:_pickPoi(): Vector3?
	local availablePois: { Instance } = {}
	local now = tick()

	for _, poi in ipairs(poiCache) do
		if poi.Parent then
			local retryTime = self.FailedPois[poi]
			if not retryTime or retryTime <= now then
				self.FailedPois[poi] = nil
				table.insert(availablePois, poi)
			end
		end
	end

	if #availablePois == 0 then
		return nil
	end

	local target: Instance?
	if self.PreferNearestPoi then
		target = self:_nearestPoi(availablePois)
		self.PreferNearestPoi = false
	end

	if not target then
		local unvisited = {}
		for _, poi in ipairs(availablePois) do
			if not self:_isRecentPoi(poi) then
				table.insert(unvisited, poi)
			end
		end

		local pool = (#unvisited > 0) and unvisited or availablePois

		table.sort(pool, function(a, b)
			return self:_poiDistance(a) < self:_poiDistance(b)
		end)

		local limit = math.min(self.MaxPoiChecks, #pool)
		local bestPoi = pool[1]
		local bestCost = math.huge

		for index = 1, limit do
			local poi = pool[index]
			local cost = self:_routeCost(poi)
			if cost < bestCost then
				bestCost = cost
				bestPoi = poi
			end
		end

		target = bestPoi or pool[1]
	end

	self:_rememberPoi(target)
	self.CurrentPoi = target
	local position = target and self:_poiPosition(target)

	if position then
		return position
	else
		warn("Poi missing a valid position; skipping")
		self.CurrentPoi = nil
		return nil
	end
end

function LiveNpc:_queueRepath()
	if self.IsConversationFrozen then
		return
	end

	local now = tick()
	if now < (self.NextRepathTime or 0) then
		return
	end

	self.NextRepathTime = now + 0.75
	self.IsMoving = false
	self.NextMoveTime = now + 0.1
end

function LiveNpc:Removing()
	if self.Connection then
		Scheduler:cancel(self.Connection)
		self.Connection = nil
	end
	if self.PathReachedConnection then
		self.PathReachedConnection:Disconnect()
		self.PathReachedConnection = nil
	end
	if self.PathErrorConnection then
		self.PathErrorConnection:Disconnect()
		self.PathErrorConnection = nil
	end
	if self.PathBlockedConnection then
		self.PathBlockedConnection:Disconnect()
		self.PathBlockedConnection = nil
	end
	if self.Path then
		self.Path:Destroy()
		self.Path = nil
	end
	if self.StateChangedConnection then
		self.StateChangedConnection:Disconnect()
		self.StateChangedConnection = nil
	end
	if self.ConversationConnection then
		self.ConversationConnection:Disconnect()
		self.ConversationConnection = nil
	end
	if self.PlayerRemovingConnection then
		self.PlayerRemovingConnection:Disconnect()
		self.PlayerRemovingConnection = nil
	end
	self.ActiveSpeaker = nil
	self.IsConversationFrozen = false
	self.IsWaitingAtPoi = false
	self:_setCanTalk(false)
end

return LiveNpc
