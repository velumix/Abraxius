local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIColors = require(Modules.UI.UIColors)
local UIFactory = require(Modules.UI.UIFactory)

local DirectionalMarker = {}

local activeMarkers = {}
local markerGui = nil
local initialized = false

local CONFIG = {
	ARROW_SIZE = UDim2.fromOffset(60, 60),
	ARROW_OFFSET = 100,
	UPDATE_RATE = 1/30,
	FADE_DISTANCE = 10,
	MIN_DISTANCE = 50, 
	PULSE_DURATION = 1,
	PULSE_SCALE = 1.2,
	DEFAULT_COLOR = Color3.fromRGB(255, 200, 0),
	DEFAULT_ICON = "➤",
}

local function scaleUDim2(size, factor)
	return UDim2.new(
		size.X.Scale * factor,
		size.X.Offset * factor,
		size.Y.Scale * factor,
		size.Y.Offset * factor
	)
end

local function initializeGui()
	if initialized then return end
	markerGui = Instance.new("ScreenGui")
	markerGui.Name = "DirectionalMarkers"
	markerGui.ResetOnSpawn = false
	markerGui.DisplayOrder = 100
	markerGui.Parent = PlayerGui
	initialized = true
end

local MarkerMethods = {}
MarkerMethods.__index = MarkerMethods

function MarkerMethods:Destroy()
	DirectionalMarker.Destroy(self.Id)
end

function MarkerMethods:SetTarget(newTarget)
	self.Target = newTarget
end

function MarkerMethods:SetColor(newColor)
	self.Color = newColor
	if self.Stroke then
		self.Stroke.Color = newColor
	end
	if self.ArrowImage then
		self.ArrowImage.ImageColor3 = newColor
	end
	if self.IconLabel then
		self.IconLabel.TextColor3 = Color3.new(1, 1, 1)
	end
	if self.IconImage then
		self.IconImage.ImageColor3 = Color3.new(1, 1, 1)
	end
end

function MarkerMethods:SetIcon(newIcon)
	self.IconText = newIcon
	if self.IconLabel then
		self.IconLabel.Text = newIcon
	elseif self.IconImage and typeof(newIcon) == "string" then
		self.IconImage.Image = newIcon
	end
end

function DirectionalMarker.Create(config)
	if not initialized then
		initializeGui()
	end

	local marker = {}
	marker.Id = tostring(os.clock()) .. math.random(1000, 9999)
	marker.Target = config.Target
	marker.Icon = config.Icon or CONFIG.DEFAULT_ICON
	marker.Color = config.Color or CONFIG.DEFAULT_COLOR
	marker.Persistent = config.Persistent or false
	marker.Active = true
	marker.OnReached = config.OnReached
	marker.ReachDistance = config.ReachDistance or CONFIG.FADE_DISTANCE

	local frame = Instance.new("Frame")
	frame.Name = "Marker_" .. marker.Id
	frame.Size = CONFIG.ARROW_SIZE
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Parent = markerGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 0
	stroke.Color = marker.Color
	stroke.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 0
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0)
	})
	gradient.Parent = stroke

	local arrowFrame = Instance.new("Frame")
	arrowFrame.Name = "ArrowFrame"
	arrowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowFrame.Size = UDim2.fromScale(1, 1)
	arrowFrame.Position = UDim2.fromScale(0.5, 0.5)
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.Parent = frame

	local arrowImage = Instance.new("ImageLabel")
	arrowImage.Name = "ArrowImage"
	arrowImage.BackgroundTransparency = 1
	arrowImage.Image = "http://www.roblox.com/asset/?id=8213161276"
	arrowImage.ImageColor3 = marker.Color
	arrowImage.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowImage.Position = UDim2.fromScale(0.5, -0.15)
	arrowImage.Size = UDim2.fromScale(1, 0.85)
	arrowImage.Parent = arrowFrame

	local iconLabel
	local iconImage
	if typeof(marker.Icon) == "string" and (marker.Icon:find("rbxassetid://") or marker.Icon:find("http")) then
		iconImage = Instance.new("ImageLabel")
		iconImage.Name = "IconImage"
		iconImage.BackgroundTransparency = 1
		iconImage.Image = marker.Icon
		iconImage.ImageColor3 = Color3.new(1, 1, 1)
		iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
		iconImage.Position = UDim2.fromScale(0.5, 0.5)
		iconImage.Size = UDim2.fromScale(0.75, 0.75)
		iconImage.ZIndex = 2
		iconImage.Parent = frame
		local iconCorner = corner:Clone()
		iconCorner.Parent = iconImage
	else
		iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "IconLabel"
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = marker.Icon
		iconLabel.TextColor3 = Color3.new(1, 1, 1)
		iconLabel.TextSize = 28
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		iconLabel.Position = UDim2.fromScale(0.5, 0.5)
		iconLabel.Size = UDim2.fromScale(0.8, 0.8)
		iconLabel.ZIndex = 2
		iconLabel.Parent = frame
	end

	local distanceLabel = UIFactory.createTextLabel(frame, {
		Name = "Distance",
		Size = UDim2.fromOffset(100, 20),
		Position = UDim2.new(0.5, 0, 1, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	})

	marker.Frame = frame
	marker.Background = frame
	marker.Stroke = stroke
	marker.Gradient = gradient
	marker.IconLabel = iconLabel
	marker.IconImage = iconImage
	marker.ArrowImage = arrowImage
	marker.DistanceLabel = distanceLabel

	local pulseTween = TweenService:Create(
		gradient,
		TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{Rotation = 360}
	)
	pulseTween:Play()
	marker.PulseTween = pulseTween

	activeMarkers[marker.Id] = marker
	setmetatable(marker, MarkerMethods)

	return marker
end

local function updateMarker(marker, deltaTime)
	if not marker.Active then return end

	local targetPos
	if typeof(marker.Target) == "Instance" then
		if marker.Target:IsA("Model") then
			targetPos = marker.Target:GetPivot().Position
		elseif marker.Target:IsA("BasePart") then
			targetPos = marker.Target.Position
		elseif marker.Target:IsA("Attachment") then
			targetPos = marker.Target.WorldPosition
		else
			return
		end
	elseif typeof(marker.Target) == "Vector3" then
		targetPos = marker.Target
	elseif type(marker.Target) == "function" then
		targetPos = marker.Target()
		if typeof(targetPos) ~= "Vector3" then
			return
		end
	else
		return
	end

	local cameraCF = Camera.CFrame
	local cameraPos = cameraCF.Position
	local viewportSize = Camera.ViewportSize

	local direction = (targetPos - cameraPos)
	local distance = direction.Magnitude

	if distance < marker.ReachDistance then
		if marker.OnReached and not marker.Reached then
			marker.Reached = true
			marker.OnReached()
		end
		if not marker.Persistent then
			marker:Destroy()
			return
		end
	end

	if distance > CONFIG.MIN_DISTANCE then
		marker.DistanceLabel.Text = string.format("%.0fm", distance)
	else
		marker.DistanceLabel.Text = ""
	end

	local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)

	if onScreen and screenPos.Z > 0 then
		marker.Frame.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
		marker.Frame.Rotation = 0
		local fadeFactor = math.clamp((distance - marker.ReachDistance) / CONFIG.FADE_DISTANCE, 0, 1)
		marker.Frame.BackgroundTransparency = 1
		if marker.Stroke then
			marker.Stroke.Transparency = fadeFactor * 0.2
		end
		if marker.ArrowImage then
			marker.ArrowImage.ImageTransparency = fadeFactor
		end
		if marker.IconLabel then
			marker.IconLabel.TextTransparency = fadeFactor
		end
		if marker.IconImage then
			marker.IconImage.ImageTransparency = fadeFactor
		end
		if marker.DistanceLabel then
			marker.DistanceLabel.TextTransparency = fadeFactor
		end
	else
		local centerX = viewportSize.X / 2
		local centerY = viewportSize.Y / 2

		local toTarget = direction * Vector3.new(1, 0, 1)
		local forward = cameraCF.LookVector * Vector3.new(1, 0, 1)
		local right = cameraCF.RightVector

		local dotForward = toTarget.Unit:Dot(forward.Unit)
		local dotRight = toTarget.Unit:Dot(right.Unit)

		local angle = math.atan2(dotRight, dotForward)
		local edgeX = centerX + math.cos(angle) * (viewportSize.X / 2 - CONFIG.ARROW_OFFSET)
		local edgeY = centerY + math.sin(angle) * (viewportSize.Y / 2 - CONFIG.ARROW_OFFSET)

		edgeX = math.clamp(edgeX, CONFIG.ARROW_OFFSET, viewportSize.X - CONFIG.ARROW_OFFSET)
		edgeY = math.clamp(edgeY, CONFIG.ARROW_OFFSET, viewportSize.Y - CONFIG.ARROW_OFFSET)

		marker.Frame.Position = UDim2.fromOffset(edgeX, edgeY)
		marker.Frame.Rotation = math.deg(angle)
		marker.Frame.BackgroundTransparency = 1
		if marker.Stroke then
			marker.Stroke.Transparency = 0
		end
		if marker.ArrowImage then
			marker.ArrowImage.ImageTransparency = 0
		end
		if marker.IconLabel then
			marker.IconLabel.TextTransparency = 0
		end
		if marker.IconImage then
			marker.IconImage.ImageTransparency = 0
		end
		if marker.DistanceLabel then
			marker.DistanceLabel.TextTransparency = 0
		end
	end
end

local function updateAllMarkers(deltaTime)
	for id, marker in pairs(activeMarkers) do
		updateMarker(marker, deltaTime)
	end
end

if not DirectionalMarker.UpdateConnection then
	DirectionalMarker.UpdateConnection = RunService.RenderStepped:Connect(updateAllMarkers)
end

function DirectionalMarker.Destroy(markerId)
	local marker = activeMarkers[markerId]
	if not marker then return end

	marker.Active = false
	if marker.PulseTween then
		marker.PulseTween:Cancel()
	end
	if marker.Frame then
		marker.Frame:Destroy()
	end
	activeMarkers[markerId] = nil
end

function DirectionalMarker.DestroyAll()
	for id, _ in pairs(activeMarkers) do
		DirectionalMarker.Destroy(id)
	end
end

function DirectionalMarker.GetActiveMarkers()
	return activeMarkers
end

return DirectionalMarker
