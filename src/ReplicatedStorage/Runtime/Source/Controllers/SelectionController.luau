--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local Mouse = Player:GetMouse()
local SelectionController = {}
local Selectables = {}
local Connections = {}

local Selected = Instance.new("ObjectValue")
local Highlight = Instance.new("Highlight")
local LastTarget = nil

local MAX_RANGE = 150
local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist
RAYCAST_PARAMS.FilterDescendantsInstances = {Camera}

local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)

Highlight.FillTransparency = 0.7
Highlight.OutlineTransparency = 0.5
Highlight.FillColor = NORMAL_COLOR
Highlight.OutlineColor = NORMAL_COLOR

local ActiveHighlights = {}

local function HighlightAvailable(selectable)
	if not selectable or not selectable.Model then return end
	local hl = Instance.new("Highlight")
	hl.Name = "AvailableHighlight"
	hl.Adornee = selectable.Model
	hl.FillColor = Color3.fromRGB(0, 255, 127)
	hl.OutlineColor = Color3.fromRGB(0, 255, 127)
	hl.FillTransparency = 0.85
	hl.OutlineTransparency = 0.4
	hl.Parent = selectable.Model
	table.insert(ActiveHighlights, hl)
end

local function findSelectable(origin, direction, maxDistance)
	local currentPosition = origin
	local directionUnit = direction.Unit
	local distanceTraveled = 0
	while distanceTraveled < maxDistance do
		local raycastResult = workspace:Raycast(currentPosition, directionUnit * (maxDistance - distanceTraveled), RAYCAST_PARAMS)
		if not raycastResult then
			break
		end
		local hitInstance = raycastResult.Instance
		if Selectables[hitInstance] then
			return hitInstance, raycastResult.Position
		end
		currentPosition = raycastResult.Position + directionUnit * 0.1
		distanceTraveled = (currentPosition - origin).Magnitude
	end
	return nil
end

function SelectionController:Track()
	Selectables[self.Instance] = self
	if SelectionController.IsRunning then
		HighlightAvailable(self)
	end
end

function SelectionController:Setup()
	self.DetectionManager = Mince:Get("DetectionManager")
	self.DiscoveryManager = Mince:Get("DiscoveryManager")
	self.InterfaceHandler = Mince:Get("InterfaceHandler")
	self.Encyclopedia = Mince:Get("Encyclopedia")
	self.EncyclopediaInterface = self.InterfaceHandler:Get("Encyclopedia")
	self.Interface = self.InterfaceHandler:Get("Discovery")
	self.ToolbarInterface = self.InterfaceHandler:Get("MainPriority", nil, true)
	self.Tooltip = Mince:Get("TooltipController")
	self.DiscoveryUI = self.Interface.ScreenGui
	self.ToolbarUI = self.ToolbarInterface.ScreenGui
	self.Inspect = self.DiscoveryUI:FindFirstChild("Inspect", true) :: TextButton
	self.Return = self.DiscoveryUI:FindFirstChild("Return", true) :: TextButton
	self.UIFishImage = self.DiscoveryUI:FindFirstChild("FishImage", true) :: ImageLabel
	self.UIFishName = self.DiscoveryUI:FindFirstChild("FishName", true) :: TextLabel
	self.Hints = self.DiscoveryUI:FindFirstChild("Hints", true) :: TextLabel
	self.FocusCamera = function(Model)
		local function setCameraSubject(subject)
			if subject and subject:IsA("Instance") then
				Camera.CameraSubject = subject
				Camera.CameraType = Enum.CameraType.Custom
			end
		end
		if Model and Model:IsA("Model") and Model.PrimaryPart then
			local selectable = Model:FindFirstChild("Selectable")
			if selectable then
				setCameraSubject(selectable)
			else
				setCameraSubject(Model)
			end
		else
			if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
				setCameraSubject(Player.Character:FindFirstChildOfClass("Humanoid"))
			end
		end
	end
	self.ShowDiscoveryUI = function(CurrentSelectable)
		if CurrentSelectable and CurrentSelectable.Model then
			local HasSelectable = CurrentSelectable.Model:FindFirstChild("Selectable")
			local Attributes = HasSelectable and HasSelectable:GetAttributes() or CurrentSelectable.Model.PrimaryPart:GetAttributes()
			local modelType = Attributes["Type"]
			if not modelType then
				warn("No model type found for " .. CurrentSelectable.Model.Name)
				return
			end
			self.ToolbarUI.Enabled = false
			local modelName = CurrentSelectable.Model.Name
			local discovered = self.DiscoveryManager:HasDiscovered(modelType, modelName)
			if not CurrentSelectable.Module then
				warn("No module found for " .. CurrentSelectable.Model.Name)
				return
			end
			local icon = CurrentSelectable.Module.Icon
			if discovered then
				self.UIFishName.Text = modelName
				self.UIFishImage.Image = icon and icon or nil
				self.UIFishImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
			else
				self.ToolbarUI.Enabled = true
				self.UIFishName.Text = "????"
				self.UIFishImage.Image = icon and icon or nil
				self.UIFishImage.ImageColor3 = Color3.fromRGB(0, 0, 0)
			end
		else
			self.UIFishName.Text = ""
		end
		if not self.Interface:IsOpen() then
			self.Interface:Trigger()
		end
	end
	self.HideDiscoveryUI = function()
		if self.Interface:IsOpen() then
			self.Interface:Trigger()
		end
		self.ToolbarUI.Enabled = true
	end
	self.Return.MouseButton1Click:Connect(function()
		Selected.Value = nil
		self.FocusCamera(Player.Character and Player.Character.Humanoid)
		self.HideDiscoveryUI()
	end)
	return SelectionController
end

function SelectionController:Start()
	if self.IsRunning then return end
	self.IsRunning = true
	self:GameStart()

	for _, selectable in pairs(Selectables) do
		HighlightAvailable(selectable)
	end
end

function SelectionController:GameStart()
	if not self.IsRunning then return end
	self:CacheCurrentSelection(nil)
	self.ActiveSelectable = nil

	Connections.RunService = RunService.Heartbeat:Connect(function()
		local MousePosition = Mouse.Hit.Position
		local CameraPosition = Camera.CFrame.Position
		local Direction = (MousePosition - CameraPosition)
		local CurrentTarget = findSelectable(CameraPosition, Direction, MAX_RANGE)
		if CurrentTarget ~= LastTarget then
			LastTarget = CurrentTarget
			if not CurrentTarget then
				Selected.Value = nil
				Highlight.Parent = nil
				self:CacheCurrentSelection(nil)
				return
			end
			local CurrentSelectable = Selectables[CurrentTarget]
			if CurrentSelectable then
				Selected.Value = CurrentTarget
				Highlight.Parent = CurrentTarget
				self:CacheCurrentSelection(CurrentTarget)
			else
				Selected.Value = nil
				Highlight.Parent = nil
				self:CacheCurrentSelection(nil)
			end
		end
		SelectionController.Tooltip.UpdatePosition(Mouse.X, Mouse.Y)
	end);

	Connections.Selected = Selected.Changed:Connect(function()
		self:CacheCurrentSelection(Selected.Value)
		if Selected.Value then
			SelectionController.Tooltip.Start()
			local CurrentSelectable = Selectables[Selected.Value]
			local Model = CurrentSelectable.Model

			local HasSelectable = Model:FindFirstChild("Selectable")

			local Attributes = HasSelectable and HasSelectable:GetAttributes() or Model.PrimaryPart:GetAttributes()
			local Type = Attributes["Type"]
			local Name = Model.Name
			local Discovered = self.DiscoveryManager:HasDiscovered(Type, Name)
			if not Discovered then
				SelectionController.Tooltip.SetText("????")
			else
				SelectionController.Tooltip.SetText(Name)
			end
		else
			SelectionController.Tooltip.Stop()
		end
	end);

	Connections.MouseButton1Down = Mouse.Button1Down:Connect(function()
		if self.EncyclopediaInterface:IsOpen() then
			return
		end
		if self.CurrentSelectable and self.CurrentSelectable.Model then
			self.ActiveSelectable = self.CurrentSelectable
			local Model = self.CurrentSelectable.Model
			local HasSelectable = Model:FindFirstChild("Selectable")
			local Attributes = HasSelectable and HasSelectable:GetAttributes() or Model.PrimaryPart:GetAttributes()
			local Name = Model.Parent.Name
			local Type = Attributes["Type"]
			if self.DiscoveryManager:HasDiscovered(Type, Name) then
				print("This fish has already been discovered!")
			else
				print("This fish has NOT been discovered yet!")
			end
			self.FocusCamera(Model)
			self.ShowDiscoveryUI(self.CurrentSelectable)
		else
			self.FocusCamera(Player.Character and Player.Character.Humanoid)
			self.HideDiscoveryUI()
			self.ActiveSelectable = nil
		end
	end);
	self.CharacterAdded = Player.CharacterAdded:Connect(function(char)
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Camera.CameraSubject = humanoid
			Camera.CameraType = Enum.CameraType.Custom
		end
	end);
end

function SelectionController:Stop()
	self.IsRunning = false

	for name, connection in pairs(Connections) do
		if connection then
			connection:Disconnect()
		end
	end
	Connections = {}

	for _, hl in ipairs(ActiveHighlights) do
		if hl then hl:Destroy() end
	end
	table.clear(ActiveHighlights)

	Selected.Value = nil
	Highlight.Parent = nil
	self:CacheCurrentSelection(nil)
	self.ActiveSelectable = nil

	if self.Interface:IsOpen() then
		self.HideDiscoveryUI()
	end
end

function SelectionController:CacheCurrentSelection(target)
	if target then
		local CurrentSelectable = Selectables[target]
		self.CurrentSelectable = CurrentSelectable
		if CurrentSelectable and CurrentSelectable.Model and CurrentSelectable.Model.PrimaryPart then
			self.CurrentModelType = CurrentSelectable.Model.PrimaryPart:GetAttribute("Type")
			self.CurrentModelName = CurrentSelectable.Model.Name
			if self.CurrentModelType and self.CurrentModelName then
				self.CurrentDiscovered = self.DiscoveryManager:HasDiscovered(self.CurrentModelType, self.CurrentModelName)
			else
				self.CurrentDiscovered = nil
			end
		else
			self.CurrentModelType = nil
			self.CurrentModelName = nil
			self.CurrentDiscovered = nil
		end
	else
		self.CurrentSelectable = nil
		self.CurrentModelType = nil
		self.CurrentModelName = nil
		self.CurrentDiscovered = nil
	end
end

return SelectionController













