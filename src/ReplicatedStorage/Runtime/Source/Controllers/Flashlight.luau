local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local Flashlight = {}
Flashlight.__index = Flashlight

local Config = {
	LIGHT_BRIGHTNESS = 2,
	LIGHT_RANGE = 90,
	LIGHT_ANGLE = 110,
	LIGHT_COLOR = Color3.fromRGB(208, 244, 250),
	ANCHOR_OFFSET = Vector3.new(0, -0.25, 0),
	ANCHOR_FORWARD_OFFSET = 1.35,
	BEAM_FORWARD_OFFSET = 1.2,
	LIGHT_TARGET_DISTANCE = 120,
	MOUSE_DIRECTION_WEIGHT = 1,
	MOUSE_MAX_YAW = math.rad(60),
	MOUSE_MAX_PITCH = math.rad(45),
	ROTATION_SPEED = 15,
	TOGGLE_KEY = Enum.KeyCode.F,
}

function Flashlight.new(character)
	local self = setmetatable({}, Flashlight)

	self.Character = character
	self.Humanoid = character:WaitForChild("Humanoid")
	self.HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
	self.Head = character:FindFirstChild("Head")
	self.UpperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	self.Player = Players.LocalPlayer

	self.Enabled = false
	self.LightPart = nil
	self.SpotLight = nil
	self.TargetCFrame = nil

	self.Connections = {}

	self:CreateFlashlight()
	self:SetupConnections()

	return self
end

function Flashlight:SetCharacterShadows(enabled)
	if not self.Character then return end

	local function updateShadows(obj)
		if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("SpecialMesh") then
			obj.CastShadow = enabled
		end
	end

	for _, child in ipairs(self.Character:GetDescendants()) do
		updateShadows(child)
	end

	if self.Connections.Shadows then
		self.Connections.Shadows:Disconnect()
		self.Connections.Shadows = nil
	end

	self.Connections.Shadows = self.Character.DescendantAdded:Connect(updateShadows)
end

function Flashlight:CreateFlashlight()
	local lightPart = Instance.new("Part")
	lightPart.Name = "FlashlightMount"
	lightPart.Size = Vector3.new(0.2, 0.2, 0.2)
	lightPart.Transparency = 1
	lightPart.CanCollide = false
	lightPart.Anchored = true
	lightPart.Massless = true
	lightPart.CastShadow = false

	local spotlight = Instance.new("SpotLight")
	spotlight.Brightness = Config.LIGHT_BRIGHTNESS
	spotlight.Range = Config.LIGHT_RANGE
	spotlight.Angle = Config.LIGHT_ANGLE
	spotlight.Color = Config.LIGHT_COLOR
	spotlight.Face = Enum.NormalId.Front
	spotlight.Shadows = false
	spotlight.Enabled = self.Enabled
	spotlight.Parent = lightPart

	local surfaceLight = Instance.new("SurfaceLight")
	surfaceLight.Brightness = 0.5
	surfaceLight.Range = 5
	surfaceLight.Color = Config.LIGHT_COLOR
	surfaceLight.Face = Enum.NormalId.Front
	surfaceLight.Shadows = false
	surfaceLight.Enabled = self.Enabled
	surfaceLight.Parent = lightPart

	lightPart.Parent = workspace

	self.LightPart = lightPart
	self.SpotLight = spotlight
	self.SurfaceLight = surfaceLight
end

function Flashlight:SetupConnections()
	self.Connections.RenderStepped = RunService.RenderStepped:Connect(function(deltaTime)
		self:UpdateFlashlightDirection(deltaTime)
	end)

	self.Connections.SwimmingChanged = self.Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		local isSwimming = self.Player:GetAttribute("Swimming")
		self:UpdateLightState(isSwimming)
	end)

	self.Connections.Died = self.Humanoid.Died:Connect(function()
		self:Destroy()
	end)

	local isSwimming = self.Player:GetAttribute("Swimming")
	self:UpdateLightState(isSwimming)
end

function Flashlight:UpdateFlashlightDirection(deltaTime)
	if not self.Enabled or not self.LightPart then return end

	local isSwimming = self.Player and self.Player:GetAttribute("Swimming")
	if not isSwimming then return end

	local camera = CurrentCamera
	if not camera then
		return
	end

	local cameraCFrame = camera.CFrame
	local forward = cameraCFrame.LookVector

	if (not self.Head or not self.Head.Parent) and self.Character then
		self.Head = self.Character:FindFirstChild("Head")
	end

	if (not self.UpperTorso or not self.UpperTorso.Parent) and self.Character then
		self.UpperTorso = self.Character:FindFirstChild("UpperTorso") or self.Character:FindFirstChild("Torso")
	end

	local anchorPart = self.Head or self.UpperTorso or self.HumanoidRootPart
	local anchorBase = (anchorPart and anchorPart.Position) or cameraCFrame.Position

	local anchorCFrame = anchorPart and anchorPart.CFrame or cameraCFrame
	local anchorOffset = anchorCFrame:VectorToWorldSpace(Config.ANCHOR_OFFSET)
	local anchorPosition = anchorBase + anchorOffset

	local pointerDirection = forward
	if not UserInputService.TouchEnabled then
		local mouse = LocalPlayer and LocalPlayer:GetMouse()
		if mouse then
			local ray = camera:ScreenPointToRay(mouse.X, mouse.Y, 0)
			if ray then
				local cameraDirection = cameraCFrame:VectorToObjectSpace(ray.Direction).Unit
				local yaw = math.atan2(cameraDirection.X, -cameraDirection.Z)
				local planarLength = math.max(1e-6, math.sqrt(cameraDirection.X * cameraDirection.X + cameraDirection.Z * cameraDirection.Z))
				local pitch = math.atan2(cameraDirection.Y, planarLength)

				yaw = math.clamp(yaw, -Config.MOUSE_MAX_YAW, Config.MOUSE_MAX_YAW)
				pitch = math.clamp(pitch, -Config.MOUSE_MAX_PITCH, Config.MOUSE_MAX_PITCH)

				local cosPitch = math.cos(pitch)
				local limitedDirectionCamera = Vector3.new(
					math.sin(yaw) * cosPitch,
					math.sin(pitch),
					-math.cos(yaw) * cosPitch
				)
				pointerDirection = cameraCFrame:VectorToWorldSpace(limitedDirectionCamera).Unit
			end
		end
	end

	local targetDirection = forward:Lerp(pointerDirection, Config.MOUSE_DIRECTION_WEIGHT).Unit

	if not self.CurrentDirection then
		self.CurrentDirection = targetDirection
	end

	local alpha = 1 - math.exp(-Config.ROTATION_SPEED * deltaTime)
	self.CurrentDirection = self.CurrentDirection:Lerp(targetDirection, alpha).Unit

	local mountRadius = Config.ANCHOR_FORWARD_OFFSET

	local mountPosition = anchorPosition + self.CurrentDirection * mountRadius
	local targetPosition = mountPosition + self.CurrentDirection * Config.LIGHT_TARGET_DISTANCE

	self.LightPart.CFrame = CFrame.lookAt(mountPosition, targetPosition)
end

function Flashlight:UpdateLightState(isSwimming)
	if self.SpotLight then
		self.SpotLight.Enabled = self.Enabled and isSwimming
	end

	if self.SurfaceLight then
		self.SurfaceLight.Enabled = self.Enabled and isSwimming
	end

	self:SetCharacterShadows(not (self.Enabled and isSwimming))
end

function Flashlight:Toggle()
	self.Enabled = not self.Enabled
	local isSwimming = self.Player and self.Player:GetAttribute("Swimming")
	self:UpdateLightState(isSwimming)
	print("Flashlight", self.Enabled and "ON" or "OFF")
end

function Flashlight:SetEnabled(enabled)
	self.Enabled = enabled

	local isSwimming = self.Player and self.Player:GetAttribute("Swimming")
	self:UpdateLightState(isSwimming)
end

function Flashlight:SetBrightness(brightness)
	if self.SpotLight then
		self.SpotLight.Brightness = brightness
	end
end

function Flashlight:SetRange(range)
	if self.SpotLight then
		self.SpotLight.Range = range
	end
end

function Flashlight:SetColor(color)
	if self.SpotLight then
		self.SpotLight.Color = color
	end

	if self.SurfaceLight then
		self.SurfaceLight.Color = color
	end
end

function Flashlight:Destroy()
	for _, connection in pairs(self.Connections) do
		if connection then
			connection:Disconnect()
		end
	end

	if self.LightPart then
		self.LightPart:Destroy()
	end

	self.Connections = {}
	self.LightPart = nil
	self.SpotLight = nil
	self.SurfaceLight = nil
end

return Flashlight
