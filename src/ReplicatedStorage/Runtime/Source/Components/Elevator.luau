local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Player = game.Players.LocalPlayer

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Component = Mince.Component
local UI = require(Modules.UI)

local Elevator = Mince.Component {
	Tag = "Elevator",
}

local Camera = workspace.CurrentCamera

local CameraPart = Component {Tag = "CameraPart"}

local InteractIndicator = Mince:Get("InteractIndicator")

local Locations = {
	["Main Observatory"] = {Vector3.new(-81.553, 12.788, 306.133)},
	["Lower Observatory"] = {Vector3.new(-78.666, 9.79, 132.57)},
	["Dive"] = {Vector3.new(-106.502, 27.476, 306.246), Action = "Swim"},
}

local DEEP_SEA_LIGHTING_OVERRIDES = {
	Ambient = Color3.fromRGB(22, 46, 78),
	OutdoorAmbient = Color3.fromRGB(10, 27, 64),
	Brightness = 1.2,
	EnvironmentDiffuseScale = 0.35,
	EnvironmentSpecularScale = 0.2,
	ExposureCompensation = -0.05,
	FogColor = Color3.fromRGB(5, 12, 24),
	FogStart = 35,
	FogEnd = 320,
	ColorShift_Top = Color3.fromRGB(12, 26, 52),
	ColorShift_Bottom = Color3.fromRGB(4, 12, 28),
}

local DEEP_SEA_COLOR_CORRECTION = {
	Brightness = -0.1,
	Contrast = 0.12,
	Saturation = -0.2,
	TintColor = Color3.fromRGB(90, 140, 195),
}

local DEEP_SEA_ATMOSPHERE = {
	Density = 0.5,
	Offset = 0.05,
	Color = Color3.fromRGB(6, 16, 35),
	Decay = Color3.fromRGB(0, 32, 80),
	Glare = 0.05,
	Haze = 3,
}

local DEEP_SEA_PREVIEW_LIGHT = {
	Brightness = 2.2,
	Range = 90,
	Color = Color3.fromRGB(130, 195, 255),
	Shadows = true,
}

local DEEP_SEA_PREVIEW_TEXT = {
	Title = "Deep Sea",
	Subtitle = "Coming Soon...",
}

function CameraPart:Construct()
	self.Part = self.Instance
	if Locations[self.Part.Name] and Locations[self.Part.Name][1] == false then
		Locations[self.Part.Name][2] = self.Part
	end
end

function Elevator:GameStart()
	self.SwimEvent = Mince:GetEvent("Swim")
end

function Elevator:GetCurrentFloor()
	local character = Player.Character
	if not character then return nil end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return nil end

	local playerPosition = humanoidRootPart.Position
	local closestFloor = nil
	local closestDistance = math.huge

	for locationName, locationData in pairs(Locations) do
		local locationPosition = locationData[1]
		if typeof(locationPosition) == "Vector3" then
			local distance = (playerPosition - locationPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestFloor = locationName
			end
		end
	end

	if closestDistance <= 25 then
		return closestFloor
	end

	return nil
end

function Elevator:ShowElevatorScreen()
	self:_restorePreviewEnvironment()

	local currentFloor = self:GetCurrentFloor()
	UI.ShowElevatorScreen(Locations, currentFloor, function(locationName)
		local locationData = Locations[locationName]
		if locationData and locationData.Action == "Swim" then
			self:TriggerDive(locationName)
		elseif locationData and locationData[1] == false then
			self:PreviewArea(locationName)
		else
			self:TeleportToLocation(locationName)
		end
	end)
end

function Elevator:Construct()
	self.Part = self.Instance
	self._activePreviewEnvironment = nil


	self.Prompt = InteractIndicator.new(self.Part).ProximityPrompt
	self.Prompt.ObjectText = "Use Elevator"
	self.Prompt.RequiresLineOfSight = true

	self.Connections = {}

	function self:OnPromptTriggered()
		if UI.ElevatorScreen.IsVisible() then
			UI.HideElevatorScreen()
		else
			self:ShowElevatorScreen()
		end
	end

	self.Connections.PromptTriggered = self.Prompt.Triggered:Connect(function(player)
		if player == Player then
			self:OnPromptTriggered()
		end
	end)
end

function Elevator:TeleportToLocation(locationName)
	self:_restorePreviewEnvironment()

	local locationData = Locations[locationName]
	if not locationData or locationData[1] == false then return end
	local targetPosition = locationData[1]
	if typeof(targetPosition) ~= "Vector3" then
		return
	end
	local character = Player.Character
	if not character then return end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	UI.HideElevatorScreen()

	UI.FadeExhibitIn(0.3, function()
		humanoidRootPart.CFrame = CFrame.new(targetPosition)

		task.spawn(function()
			task.wait(0.1)
			UI.FadeExhibitOut(0.3)
		end)
	end)
end

function Elevator:TriggerDive(locationName)
	if not self.SwimEvent then
		self.SwimEvent = Mince:GetEvent("Swim")
	end

	local locationData = Locations[locationName or "Dive"]
	local targetPosition = locationData and locationData[1]
	if typeof(targetPosition) ~= "Vector3" then
		return
	end

	local character = Player.Character
	if not character then return end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	UI.HideElevatorScreen()

	UI.FadeExhibitIn(0.3, function()
		humanoidRootPart.CFrame = CFrame.new(targetPosition)
		self.SwimEvent:Fire(true)

		task.spawn(function()
			task.wait(0.1)
			UI.FadeExhibitOut(0.3)
		end)
	end)
end

function Elevator:PreviewArea(locationName)
	local locationData = Locations[locationName]
	if not locationData or not locationData[2] then 
		return 
	end

	local cameraPart = locationData[2]

	UI.HideElevatorScreen()

	UI.FadeExhibitIn(0.3, function()
		if not Camera then
			self:_restorePreviewEnvironment()
			return
		end

		self:_applyPreviewEnvironment(locationName, cameraPart)

		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = cameraPart.CFrame

		UI.FadeExhibitOut(0.3, function()
			UI.ShowExhibitExitButton(function()
				UI.FadeExhibitIn(0.3, function()
					Camera.CameraType = Enum.CameraType.Custom
					self:_restorePreviewEnvironment()
					UI.HideExhibitExitButton()
					UI.FadeExhibitOut(0.3)
				end)
			end)
		end)
	end)
end

function Elevator:_applyPreviewEnvironment(locationName, cameraPart)
	if locationName ~= "Deep Sea" then
		self:_restorePreviewEnvironment()
		return
	end

	if self._activePreviewEnvironment then
		return
	end

	local lightingBackup = {}
	for property in pairs(DEEP_SEA_LIGHTING_OVERRIDES) do
		lightingBackup[property] = Lighting[property]
	end

	for property, value in pairs(DEEP_SEA_LIGHTING_OVERRIDES) do
		Lighting[property] = value
	end

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "DeepSeaPreviewColorCorrection"
	for property, value in pairs(DEEP_SEA_COLOR_CORRECTION) do
		colorCorrection[property] = value
	end
	colorCorrection.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosphereState
	if atmosphere then
		local original = {}
		for property in pairs(DEEP_SEA_ATMOSPHERE) do
			original[property] = atmosphere[property]
		end
		for property, value in pairs(DEEP_SEA_ATMOSPHERE) do
			atmosphere[property] = value
		end
		atmosphereState = {
			instance = atmosphere,
			original = original,
			created = false,
		}
	else
		local newAtmosphere = Instance.new("Atmosphere")
		newAtmosphere.Name = "DeepSeaPreviewAtmosphere"
		for property, value in pairs(DEEP_SEA_ATMOSPHERE) do
			newAtmosphere[property] = value
		end
		newAtmosphere.Parent = Lighting
		atmosphereState = {
			instance = newAtmosphere,
			created = true,
		}
	end

	local previewLight
	local messageGui
	if cameraPart and cameraPart:IsA("BasePart") then
		previewLight = Instance.new("PointLight")
		previewLight.Name = "DeepSeaPreviewLight"
		for property, value in pairs(DEEP_SEA_PREVIEW_LIGHT) do
			previewLight[property] = value
		end
		previewLight.Parent = cameraPart
	end

	local playerGui = Player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		messageGui = Instance.new("ScreenGui")
		messageGui.Name = "DeepSeaPreviewMessage"
		messageGui.IgnoreGuiInset = true
		messageGui.ResetOnSpawn = false
		messageGui.DisplayOrder = 200
		messageGui.Parent = playerGui

		local container = Instance.new("Frame")
		container.Name = "MessageContainer"
		container.Parent = messageGui
		container.Size = UDim2.new(0, 320, 0, 110)
		container.Position = UDim2.new(0.5, -160, 0, 140)
		container.BackgroundTransparency = 1

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Parent = container
		title.Size = UDim2.new(1, 0, 0, 50)
		title.Position = UDim2.new(0, 0, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = DEEP_SEA_PREVIEW_TEXT.Title
		title.TextColor3 = Color3.fromRGB(210, 235, 255)
		title.TextStrokeTransparency = 0.6
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextWrapped = true

		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Subtitle"
		subtitle.Parent = container
		subtitle.Size = UDim2.new(1, 0, 0, 40)
		subtitle.Position = UDim2.new(0, 0, 0, 60)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = DEEP_SEA_PREVIEW_TEXT.Subtitle
		subtitle.TextColor3 = Color3.fromRGB(180, 220, 255)
		subtitle.TextStrokeTransparency = 0.7
		subtitle.Font = Enum.Font.GothamMedium
		subtitle.TextScaled = true
		subtitle.TextWrapped = true
	end

	self._activePreviewEnvironment = {
		lighting = lightingBackup,
		colorCorrection = colorCorrection,
		atmosphere = atmosphereState,
		previewLight = previewLight,
		messageGui = messageGui,
	}
end

function Elevator:_restorePreviewEnvironment()
	local state = self._activePreviewEnvironment
	if not state then
		return
	end

	for property, value in pairs(state.lighting or {}) do
		Lighting[property] = value
	end

	if state.colorCorrection then
		state.colorCorrection:Destroy()
	end

	local atmosphereState = state.atmosphere
	if atmosphereState then
		local atmosphere = atmosphereState.instance
		if atmosphereState.created then
			if atmosphere then
				atmosphere:Destroy()
			end
		elseif atmosphere and atmosphereState.original then
			for property, value in pairs(atmosphereState.original) do
				atmosphere[property] = value
			end
		end
	end

	if state.previewLight and state.previewLight.Parent then
		state.previewLight:Destroy()
	end

	if state.messageGui then
		state.messageGui:Destroy()
	end

	self._activePreviewEnvironment = nil
end

function Elevator:Destroying()
	if self.Connections then
		for _, connection in pairs(self.Connections) do
			if connection then
				connection:Disconnect()
			end
		end
	end

	self:_restorePreviewEnvironment()

	if UI.ElevatorScreen.IsVisible() then
		UI.HideElevatorScreen()
	end
end

return Elevator