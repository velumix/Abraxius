--[[
	TutorialManager - A comprehensive tutorial system for guiding players
	Features:
	- Step-by-step tutorial progression
	- Highlight integration for visual guidance
	- Directional markers pointing to targets
	- Encyclopedia integration
	- Customizable tutorial configurations
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Signal = require(Modules:WaitForChild("Signal"))
local Mince = require(Modules:WaitForChild("Mince"))
local Highlight = require(Modules:WaitForChild("Highlight"))
local LocationMarker = require(Modules:WaitForChild("LocationMarker"))
local UI = require(Modules:WaitForChild("UI"))

local LocalPlayer = Players.LocalPlayer

local TutorialManager = {}
TutorialManager.__index = TutorialManager

local activeTutorials = {}

-- structure:
--[[
	{
		Message = "Step description",
		Type = "notification" | "highlight" | "marker" | "wait",
		Duration = number (for notifications),
		Target = Instance | Vector3 | function() -> Instance,
		Condition = function() -> boolean,
		OnStart = function(tutorial),
		OnComplete = function(tutorial),
		HighlightColor = Color3 (optional),
		MarkerColor = Color3 (optional),
		MarkerIcon = string (emoji or unicode),
		WaitFor = Signal (optional),
	}
]]

function TutorialManager.new(config)
	local self = setmetatable({}, TutorialManager)

	self.Id = config.Id or "Tutorial_" .. tostring(os.clock())
	self.Name = config.Name or "Tutorial"
	self.Steps = config.Steps or {}
	self.CurrentStep = 0
	self.Active = false
	self.Completed = false

	self.StepChanged = Signal.new()
	self.TutorialCompleted = Signal.new()
	self.TutorialCancelled = Signal.new()

	self.CurrentHighlight = nil
	self.CurrentMarker = nil
	self.HighlightSet = Highlight.newSet({
		Color = Color3.new(1, 0.8, 0),
		OutlineColor = Color3.new(1, 1, 1),
		DoesFlash = true,
		HasOutline = true,
		ClearLast = true,
	})

	self.Connections = {}
	return self
end

function TutorialManager:Start()
	if self.Active then
		warn("Tutorial already active:", self.Name)
		return
	end

	self.Active = true
	self.CurrentStep = 0
	activeTutorials[self.Id] = self

	UI.Notify("Tutorial Started: " .. self.Name, "Info", 3)

	self:NextStep()
end

function TutorialManager:NextStep()
	if not self.Active then
		return
	end
	self:CleanupCurrentStep()

	self.CurrentStep = self.CurrentStep + 1

	if self.CurrentStep > #self.Steps then
		self:Complete()
		return
	end

	local step = self.Steps[self.CurrentStep]
	self.StepChanged:Fire(self.CurrentStep, step)

	self:ExecuteStep(step)
end

function TutorialManager:ExecuteStep(step)
	if not step then
		return
	end

	if step.OnStart then
		task.spawn(step.OnStart, self)
	end

	if step.Message then
		local duration = step.Duration or 5
		UI.Notify(step.Message, step.NotificationType or "Info", duration)
	end

	local target = step.Target
	if type(target) == "function" then
		target = target()
	end

	if step.Type == "highlight" and target then
		self:ShowHighlight(target, step.HighlightColor)
	end

	if step.Type == "marker" and target then
		self:ShowMarker(target, step.MarkerIcon, step.MarkerColor)
	end

	if step.Type == "both" and target then
		self:ShowHighlight(target, step.HighlightColor)
		self:ShowMarker(target, step.MarkerIcon, step.MarkerColor)
	end

	local handled = false

	if step.Condition then
		self:WaitForCondition(step.Condition, step)
		handled = true
	else
		local waitForSignal = step.WaitFor
		if typeof(waitForSignal) == "function" then
			waitForSignal = waitForSignal()
		end
		if waitForSignal then
			self:WaitForSignal(waitForSignal, step)
			handled = true
		end
	end

	if not handled and step.Type == "notification" then
		task.delay(step.Duration or 5, function()
			if self.Active and self.CurrentStep == table.find(self.Steps, step) then
				self:NextStep()
			end
		end)
	end
end

function TutorialManager:ShowHighlight(target, color)
	if not target then
		return
	end

	if color then
		self.HighlightSet.Color = color
		self.HighlightSet:Refresh()
	end

	self.HighlightSet:Set(target)
	self.CurrentHighlight = target
end

function TutorialManager:ShowMarker(target, icon, color)
	if not target then
		return
	end

	self.CurrentMarker = LocationMarker.new({
		Target = target,
		TutorialId = self.Id,
		Icon = icon or "rbxassetid://16911678024",
		Color = color or Color3.new(1, 0.8, 0),
		Enabled = true,
		ShowDistance = false,
		MinDistance = 10,
		MaxDistance = 200,
	})
end

function TutorialManager:WaitForCondition(condition, step)
	local checkInterval = 0.5
	local connection

	connection = task.spawn(function()
		while self.Active and self.CurrentStep == table.find(self.Steps, step) do
			if condition() then
				if step.OnComplete then
					step.OnComplete(self)
				end
				self:NextStep()
				break
			end
			task.wait(checkInterval)
		end
	end)
	table.insert(self.Connections, connection)
end

function TutorialManager:WaitForSignal(signal, step)
	local connection = signal:Connect(function(...)
		if self.Active and self.CurrentStep == table.find(self.Steps, step) then
			if step.OnComplete then
				step.OnComplete(self, ...)
			end
			self:NextStep()
		end
	end)
	table.insert(self.Connections, connection)
end

function TutorialManager:CleanupCurrentStep()
	if self.CurrentHighlight then
		self.HighlightSet:Clear()
		self.CurrentHighlight = nil
	end

	if self.CurrentMarker and self.CurrentMarker.Destroy then
		local ok, err = pcall(function()
			self.CurrentMarker:Destroy()
		end)
		if not ok then
			warn("Tutorial marker cleanup failed:", err)
		end
		self.CurrentMarker = nil
	end

	-- The marker renderer is driven by tagged attachments. Remove any orphaned
	-- attachment belonging to this tutorial even if its wrapper reference was lost.
	for _, marker in ipairs(CollectionService:GetTagged("Marker")) do
		if marker.Name == "TutorialMarker" then
			local tutorialId = marker:GetAttribute("TutorialId")
			if tutorialId == nil or tutorialId == self.Id then
				marker:Destroy()
			end
		end
	end

	for _, connection in ipairs(self.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		elseif typeof(connection) == "thread" then
			pcall(task.cancel, connection)
		elseif typeof(connection) == "function" then
			local ok, err = pcall(connection)
			if not ok then
				warn("Tutorial cleanup callback failed:", err)
			end
		elseif typeof(connection) == "table" then
			if connection.Destroy then
				local ok, err = pcall(function()
					connection:Destroy()
				end)
				if not ok then
					warn("Tutorial cleanup object failed:", err)
				end
			end
		end
	end
	self.Connections = {}
end

function TutorialManager:Complete()
	if self.Completed then
		return
	end

	self.Active = false
	self.Completed = true

	self:CleanupCurrentStep()

	UI.Notify("Tutorial Complete: " .. self.Name .. " ✨", "Success", 5)

	self.TutorialCompleted:Fire()
	activeTutorials[self.Id] = nil
end

function TutorialManager:Cancel()
	if not self.Active then
		return
	end
	self.Active = false
	self:CleanupCurrentStep()

	UI.Notify("Tutorial Cancelled", "Warning", 3)

	self.TutorialCancelled:Fire()
	activeTutorials[self.Id] = nil
end

function TutorialManager:SkipToStep(stepNumber)
	if stepNumber < 1 or stepNumber > #self.Steps then
		warn("Invalid step number:", stepNumber)
		return
	end
	self:CleanupCurrentStep()
	self.CurrentStep = stepNumber - 1
	self:NextStep()
end

function TutorialManager.GetActiveTutorials()
	return activeTutorials
end

function TutorialManager.CancelAll()
	for _, tutorial in pairs(activeTutorials) do
		tutorial:Cancel()
	end
end

return TutorialManager
