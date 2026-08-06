local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Mince = require(ReplicatedStorage.Modules.Mince)

export type ExhibitConfig = {
	Fovs: {
		Default: number,
		Exhibit: number,
		Min: number,
		Max: number
	},
	DampeningFactor: number,
	TransitionInfo: TweenInfo,
	BlinkInfo: {
		In: TweenInfo,
		Out: TweenInfo
	}
}

local DEFAULT_CONFIG: ExhibitConfig = {
	Fovs = {
		Default = 70,
		Exhibit = 40,
		Min = 10,
		Max = 50
	},
	DampeningFactor = 7,
	TransitionInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	BlinkInfo = {
		In = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		Out = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	}
}

local MOVEMENT_THRESHOLD = 0.1
local ZOOM_SENSITIVITY = 3
local DAMPENING_SMOOTHNESS = 10

local InteractIndicator = Mince:Get("InteractIndicator")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = Player.PlayerGui
local Mouse = Player:GetMouse()

local ExhibitController = {
	Name = "ExhibitController",
	Config = DEFAULT_CONFIG,
	_exhibits = {},
}

function ExhibitController:Setup()
	self.ExhibitEntered = Instance.new("BindableEvent")
	self.ExhibitExited = Instance.new("BindableEvent")
	self.ExhibitDiscovered = Instance.new("BindableEvent")

	self.DiscoveryEvent = Mince:GetEvent("DiscoverySystem")
	self.RecordDiscoveryEvent = self.DiscoveryEvent:Extend("RecordDiscovery")
	self.GetDiscoveriesEvent = self.DiscoveryEvent:Extend("GetDiscoveries")
end

function ExhibitController:GameStart()
	self._discoveryManager = Mince:Get("DiscoveryManager")

	self.Connections = {
		ExhibitEntered = self.ExhibitEntered.Event:Connect(function(exhibitName)
			print("Entered exhibit:", exhibitName)
		end),

		ExhibitExited = self.ExhibitExited.Event:Connect(function(exhibitName)
			print("Exited exhibit:", exhibitName)
		end),

		ExhibitDiscovered = self.ExhibitDiscovered.Event:Connect(function(exhibitName, isFirstTime)
			if isFirstTime then
				print("New exhibit discovered:", exhibitName)
			end
		end),

		ViewingCameraAngles = Player:GetAttributeChangedSignal("ViewingCameraAngles"):Connect(function()
			if Player:GetAttribute("ViewingCameraAngles") then
				local isInExhibit, activeExhibit = self:IsPlayerInExhibit(Player)
				if isInExhibit and activeExhibit then
					activeExhibit:_pauseExhibitCamera()
				end
			end
		end),
	}

end

function ExhibitController:GetAllExhibits()
	return self._exhibits
end

function ExhibitController:GetExhibitByInstance(instance)
	return self._exhibits[instance]
end

function ExhibitController:IsPlayerInExhibit(player)
	for _, exhibit in pairs(self._exhibits) do
		if game.Workspace.CurrentCamera.CameraSubject == exhibit.Instance then
			return true, exhibit
		end
	end
	return false, nil
end

local Exhibit = Mince.Component {
	Tag = "Exhibit",

	_connections = {},
	_exhibits = ExhibitController._exhibits,
	_previousCFrame = nil,
	_targetFov = DEFAULT_CONFIG.Fovs.Exhibit,
	_glassParts = {},
	_lastCameraUpdate = 0,
	_CCM = nil,
	_cameraControlConnection = nil,
	_isViewingExhibit = false,
	_suspendedForExternal = nil,

	Config = ExhibitController.Config
}


local function validateExhibitParts(instance: Instance): (boolean, string?)
	if not instance:FindFirstChild("Proximity") then
		return false, "Exhibit is missing Proximity part"
	end
	if not instance:FindFirstChild("FocusPoint") then
		return false, "Exhibit is missing FocusPoint"
	end
	return true
end

local playerOriginalTransparencies = {}

local function resolveRenderablePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("SpecialMesh") then
		local parent = instance.Parent
		if parent and parent:IsA("BasePart") then
			return parent
		end
	end

	return nil
end

local function setPlayerVisibility(isVisible: boolean)
	local character = Player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.Anchored = not isVisible
	end

	local processedParts = {}

	for _, part in ipairs(character:GetDescendants()) do
		local targetPart = resolveRenderablePart(part)
		if not targetPart then
			continue
		end

		if processedParts[targetPart] then
			continue
		end
		processedParts[targetPart] = true

		if targetPart.Name == "HumanoidRootPart" or targetPart.Name == "CollisionPart" then 
			continue
		end

		if not isVisible then
			if playerOriginalTransparencies[targetPart] == nil then
				playerOriginalTransparencies[targetPart] = targetPart.Transparency
			end
			targetPart.Transparency = 1
		else
			local originalTransparency = playerOriginalTransparencies[targetPart]
			if originalTransparency ~= nil then
				targetPart.Transparency = originalTransparency
				playerOriginalTransparencies[targetPart] = nil
			else
				targetPart.Transparency = 0
			end
		end
	end
end

local originalTransparencies = {}

local function setOtherPlayersVisibility(isVisible: boolean)
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= Player and otherPlayer.Character then
			local processedParts = {}
			for _, descendant in ipairs(otherPlayer.Character:GetDescendants()) do
				local targetPart = resolveRenderablePart(descendant)
				if targetPart then
					if processedParts[targetPart] then
						continue
					end
					processedParts[targetPart] = true

					if not originalTransparencies[targetPart] then
						originalTransparencies[targetPart] = targetPart.Transparency
					end
					if targetPart.Name == "HumanoidRootPart" or targetPart.Name == "CollisionPart" then
						targetPart.Transparency = 1
					elseif isVisible then
						targetPart.Transparency = originalTransparencies[targetPart]
					else
						targetPart.Transparency = 1
					end
				elseif descendant:IsA("Decal") then
					if not originalTransparencies[descendant] then
						originalTransparencies[descendant] = descendant.Transparency
					end

					if isVisible then
						descendant.Transparency = originalTransparencies[descendant]
					else
						descendant.Transparency = 1
					end
				end
			end
		end
	end
end

function Exhibit:_disconnectCameraConnections()
	if not self._connections then
		return
	end

	local function disconnect(name)
		local connection = self._connections[name]
		if connection then
			connection:Disconnect()
			self._connections[name] = nil
		end
	end

	disconnect("RenderStepped")
	disconnect("InputChanged")
	disconnect("KeyboardInput")
	disconnect("PlayerAdded")
end

function Exhibit:_suspendForExternalControl(controllerName)
	if not self._isViewingExhibit then
		return
	end

	if self._suspendedForExternal == controllerName then
		return
	end

	self:_disconnectCameraConnections()
	self._suspendedForExternal = controllerName or true
end

function Exhibit:PanCamera(dt: number)
	if not self.FocusPoint then return end

	if not self._CCM:HasControl("Exhibit_" .. self.Instance.Name) then
		return
	end

	local mousePosition = Vector2.new(Mouse.X, Mouse.Y)
	local screenSize = Camera.ViewportSize
	local screenCenter = screenSize / 2

	local offset = (mousePosition - screenCenter)
	if offset.Magnitude < MOVEMENT_THRESHOLD then return end

	local sizeX = self.Instance.Size.X :: number
	local sizeY = self.Instance.Size.Y :: number
	local screenX = screenSize.X :: number
	local screenY = screenSize.Y :: number

	local offsetX = offset.X * (sizeX / screenX)
	local offsetY = offset.Y * (sizeY / screenY)

	local halfSizeX = sizeX / 2
	local halfSizeY = sizeY / 2

	local clampedOffset = Vector2.new(
		math.clamp(offsetX, -halfSizeX, halfSizeX),
		math.clamp(offsetY, -halfSizeY, halfSizeY)
	)

	local newCFrame = self.FocusPoint.CFrame * CFrame.new(clampedOffset.X, -clampedOffset.Y, 0)

	if not self._previousCFrame then
		self._previousCFrame = Camera.CFrame
	end

	local cameraAlpha = 1 - math.exp(-self.Config.DampeningFactor * dt)
	local fovAlpha = 1 - math.exp(-DAMPENING_SMOOTHNESS * dt)

	Camera.CFrame = self._previousCFrame:Lerp(newCFrame, math.clamp(cameraAlpha, 0, 1))
	Camera.FieldOfView += (self._targetFov - Camera.FieldOfView) * math.clamp(fovAlpha, 0, 1)

	self._previousCFrame = Camera.CFrame
end

function Exhibit:ChangeGlassCollisionGroup(Group)
	for _, Glass in self._glassParts do
		Glass.CollisionGroup = Group
	end
end

function Exhibit:FocusExhibit()
	if Player:GetAttribute("ViewingCameraAngles") then
		warn("Cannot view exhibit while CameraAngles is open")
		return
	end

	self._isTransitioning = true
	self._targetFov = self.Config.Fovs.Exhibit
	self._isViewingExhibit = true

	self._CCM:RequestControl("Exhibit_" .. self.Instance.Name, self._CCM.Priority.EXHIBIT)

	if self._cameraControlConnection then
		self._cameraControlConnection:Disconnect()
	end

	self._cameraControlConnection = self._CCM.ControlChanged:Connect(function(prevOwner, newOwner, prevPriority, newPriority)
		if newOwner == "ScanController" then
			if self._isViewingExhibit then
				self:FocusCharacter()
			end
		elseif newOwner ~= "Exhibit_" .. self.Instance.Name then
			if self._isViewingExhibit then
				self:_pauseExhibitCamera()
			end
		elseif prevOwner ~= "Exhibit_" .. self.Instance.Name and self._isViewingExhibit then
			self:_resumeExhibitCamera()
		end
	end)

	self:ChangeGlassCollisionGroup("Glass")

	for _, tween in self.Tweens do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
	end

	_G.UI.FadeExhibitIn(self.Config.BlinkInfo.In.Time)

	_G.UI.ShowExhibitExitButton(function()
		self:FocusCharacter()
	end)

	Player:SetAttribute("ViewingExhibit", true)

	local wasNewDiscovery = self:RecordExhibitDiscovery()

	ExhibitController.ExhibitEntered:Fire(self.Instance.Name)

	if wasNewDiscovery ~= nil then
		ExhibitController.ExhibitDiscovered:Fire(self.Instance.Name, wasNewDiscovery)
	end

	if self.FocusPoint then
		self._previousCFrame = self.FocusPoint.CFrame
		Camera.CFrame = self.FocusPoint.CFrame
		Camera.FieldOfView = self.Config.Fovs.Exhibit
		Camera.CameraSubject = self.Instance
		Camera.CameraType = Enum.CameraType.Scriptable
	end

	self.Prompt:SetAttribute("Type", "None")

	local BillboardGui = Player.Character:FindFirstChild("PlayerInfo")
	if BillboardGui then
		BillboardGui.Enabled = false
	end

	setPlayerVisibility(false)
	setOtherPlayersVisibility(false)
	self.Tweens["Focus"]:Play()

	_G.UI.FadeExhibitOut(self.Config.BlinkInfo.Out.Time, function()
		self._isTransitioning = false
	end)

	if self._connections["RenderStepped"] then
		self._connections["RenderStepped"]:Disconnect()
	end
	if self._connections["InputChanged"] then
		self._connections["InputChanged"]:Disconnect()
	end
	if self._connections["KeyboardInput"] then
		self._connections["KeyboardInput"]:Disconnect()
	end
	if self._connections["PlayerAdded"] then
		self._connections["PlayerAdded"]:Disconnect()
	end

	self._connections["RenderStepped"] = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not self._CCM:HasControl("Exhibit_" .. self.Instance.Name) then
			return
		end
		self:PanCamera(dt)
	end)

	self._connections["InputChanged"] = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:ZoomCamera(input.Position.Z)
		end
	end)


	self._connections["KeyboardInput"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Escape then

			self:FocusCharacter()
		elseif input.KeyCode == Enum.KeyCode.R then

			self:ResetCameraPosition()
		elseif input.KeyCode == Enum.KeyCode.I then


		end
	end)



	self._connections["PlayerAdded"] = Players.PlayerAdded:Connect(function(newPlayer)
		newPlayer.CharacterAdded:Connect(function(character)
			if Camera.CameraSubject == self.Instance then
				task.wait(0.1)
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") or part:IsA("MeshPart") then
						part.Transparency = 1
					elseif part:IsA("Decal") then
						part.Transparency = 1
					end
				end
			end
		end)
	end)
end

function Exhibit:FocusCharacter()
	self._isTransitioning = true
	self._isInExhibitMode = false
	self._isViewingExhibit = false

	self._CCM:ReleaseControl("Exhibit_" .. self.Instance.Name)

	if self._cameraControlConnection then
		self._cameraControlConnection:Disconnect()
		self._cameraControlConnection = nil
	end

	Player:SetAttribute("ViewingExhibit", nil)

	for _, tween in self.Tweens do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
	end

	_G.UI.FadeExhibitIn(self.Config.BlinkInfo.In.Time)
	self.Tweens["Unfocus"]:Play()

	self:ChangeGlassCollisionGroup("Default")

	_G.UI.HideExhibitExitButton()

	ExhibitController.ExhibitExited:Fire(self.Instance.Name)

	Camera.CameraType = Enum.CameraType.Custom
	Camera.FieldOfView = self.Config.Fovs.Default
	Camera.CameraSubject = Player.Character.Humanoid

	setPlayerVisibility(true)
	setOtherPlayersVisibility(true)

	_G.UI.FadeExhibitOut(self.Config.BlinkInfo.Out.Time, function()
		self._isTransitioning = false
	end)

	self.Prompt:SetAttribute("Type", self.PromptStyle)

	local BillboardGui = Player.Character:FindFirstChild("PlayerInfo")
	if BillboardGui then
		BillboardGui.Enabled = true
	end

	if self._connections["RenderStepped"] then
		self._connections["RenderStepped"]:Disconnect()
		self._connections["RenderStepped"] = nil
	end
	if self._connections["InputChanged"] then
		self._connections["InputChanged"]:Disconnect()
		self._connections["InputChanged"] = nil
	end
	if self._connections["KeyboardInput"] then
		self._connections["KeyboardInput"]:Disconnect()
		self._connections["KeyboardInput"] = nil
	end
	if self._connections["PlayerAdded"] then
		self._connections["PlayerAdded"]:Disconnect()
		self._connections["PlayerAdded"] = nil
	end
end

function Exhibit:ZoomCamera(scrollDelta)
	if type(scrollDelta) == "number" and type(self._targetFov) == "number" then
		local currentFov = self._targetFov :: number
		local zoomSensitivity = ZOOM_SENSITIVITY :: number
		local delta = scrollDelta :: number
		self._targetFov = math.clamp(currentFov - delta * zoomSensitivity, self.Config.Fovs.Min, self.Config.Fovs.Max)
	end
end

function Exhibit:GetExhibitInfo()
	local exhibitName = self.Instance:GetAttribute("ExhibitName") or self.Instance.Name
	local creatureType = self.Instance:GetAttribute("CreatureType") or "Unknown"
	local description = self.Instance:GetAttribute("Description") or "A fascinating aquatic exhibit."

	local isDiscovered = false
	if ExhibitController._discoveryManager then
		isDiscovered = ExhibitController._discoveryManager:HasDiscovered("Locations", exhibitName)
	end

	return {
		Name = exhibitName,
		Type = creatureType,
		Description = description,
		Discovered = isDiscovered
	}
end

function Exhibit:RecordExhibitDiscovery()
	local exhibitInfo = self:GetExhibitInfo()
	if not exhibitInfo.Discovered then
		ExhibitController.RecordDiscoveryEvent:Fire("Locations", exhibitInfo.Name)
		print("Discovered new exhibit:", exhibitInfo.Name)
		return true
	end
	return false
end

function Exhibit:ResetCameraPosition()
	if self.FocusPoint then
		self._previousCFrame = self.FocusPoint.CFrame
		self._targetFov = self.Config.Fovs.Exhibit
		Camera.CFrame = self.FocusPoint.CFrame
		Camera.FieldOfView = self.Config.Fovs.Exhibit
		Camera.CameraSubject = self.Instance
		Camera.CameraType = Enum.CameraType.Scriptable
	end
end

function Exhibit:Disconnect(Target)
	if Target._connections then
		for _, Connection in Target._connections do
			Connection:Disconnect()
		end
	end
	warn("Deactivated", Target.Instance)
end

function Exhibit:_pauseExhibitCamera()
	self:_disconnectCameraConnections()

	if self._cameraControlConnection then
		self._cameraControlConnection:Disconnect()
		self._cameraControlConnection = nil
	end

	for _, tween in self.Tweens do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
	end

	_G.UI.FadeExhibitIn(self.Config.BlinkInfo.In.Time)
	self.Tweens["Unfocus"]:Play()

	self:ChangeGlassCollisionGroup("Default")
	_G.UI.HideExhibitExitButton()
	ExhibitController.ExhibitExited:Fire(self.Instance.Name)

	Camera.CameraType = Enum.CameraType.Custom
	Camera.FieldOfView = self.Config.Fovs.Default
	Camera.CameraSubject = Player.Character.Humanoid

	setPlayerVisibility(true)
	setOtherPlayersVisibility(true)

	_G.UI.FadeExhibitOut(self.Config.BlinkInfo.Out.Time, function()
		self._isTransitioning = false
	end)

	self.Prompt:SetAttribute("Type", self.PromptStyle)

	local BillboardGui = Player.Character:FindFirstChild("PlayerInfo")
	if BillboardGui then
		BillboardGui.Enabled = true
	end

	Player:SetAttribute("ViewingExhibit", nil)
	self._isInExhibitMode = false
	self._suspendedForExternal = nil
end

function Exhibit:_resumeExhibitCamera()
	if not self.FocusPoint then return end

	self._connections["RenderStepped"] = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not self._CCM:HasControl("Exhibit_" .. self.Instance.Name) then
			return
		end
		self:PanCamera(dt)
	end)

	self._connections["InputChanged"] = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:ZoomCamera(input.Position.Z)
		end
	end)

	self._connections["KeyboardInput"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Escape then
			self:FocusCharacter()
		elseif input.KeyCode == Enum.KeyCode.R then
			self:ResetCameraPosition()
		end
	end)

	if self._cameraControlConnection then
		self._cameraControlConnection:Disconnect()
	end

	self._cameraControlConnection = self._CCM.ControlChanged:Connect(function(prevOwner, newOwner, prevPriority, newPriority)
		if newOwner ~= "Exhibit_" .. self.Instance.Name then
			self:_pauseExhibitCamera()
		end
	end)
end

function Exhibit:Construct()
	self._connections = {}
	self.Tweens = {}
	self._glassParts = {}
	self._isTransitioning = false
	self._targetFov = self.Config.Fovs.Exhibit
	self._CCM = Mince:Get("CameraControlManager")

	local isValid, errorMessage = validateExhibitParts(self.Instance)
	if not isValid then
		warn(errorMessage, self.Instance)
		return
	end

	for _, part in self.Instance:GetChildren() do
		local name = string.lower(part.Name)
		if part.Name == "Glass" or name:find("glass") then
			table.insert(self._glassParts, part)
		end
	end

	self.Proximity = self.Instance:FindFirstChild("Proximity")
	self.Indicator = InteractIndicator.new(self.Proximity)
	self.Prompt = self.Indicator.ProximityPrompt
	self.Prompt.ObjectText = "Examine"
	self.Prompt.Enabled = true
	self.PromptStyle = self.Prompt:GetAttribute("Type")
	self.FocusPoint = self.Instance:FindFirstChild("FocusPoint")

	self.Tweens.Focus = TweenService:Create(Camera, self.Config.TransitionInfo, {FieldOfView = self.Config.Fovs.Exhibit})
	self.Tweens.Unfocus = TweenService:Create(Camera, self.Config.TransitionInfo, {FieldOfView = self.Config.Fovs.Default})

	self._connections.Triggered = self.Prompt.Triggered:Connect(function()
		if self._isTransitioning then
			return
		end

		if Camera.CameraSubject ~= Player.Character.Humanoid then
			self:FocusCharacter()
		else
			self:FocusExhibit()
		end
	end)

	self._exhibits[self.Instance] = self
end

return ExhibitController