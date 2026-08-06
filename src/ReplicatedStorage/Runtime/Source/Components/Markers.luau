local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Mince = require(Modules:WaitForChild("Mince"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local DEFAULT_SIZE = UDim2.new(0.038, 0, 0.038, 0)
local MIDDLE_ANCHOR_POINT = Vector2.new(0.5, 0.5)
local MIDDLE_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local PULSE_INFO = TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
local FADE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PULSE_SCALE = 1.1

local MarkersController = {
	Name = "MarkersController",

	_screenGui = nil,
	_indicatorTable = {},
	_updateConnection = nil,
}

local MarkerComponent = Mince.Component({
	Tag = "Marker",
})

local function createNewIndicator()
	local newMainFrame = Instance.new("Frame")
	newMainFrame.AnchorPoint = MIDDLE_ANCHOR_POINT
	newMainFrame.Size = DEFAULT_SIZE
	newMainFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	newMainFrame.Name = "MainFrame"

	local newUICorner = Instance.new("UICorner")
	newUICorner.CornerRadius = UDim.new(0.5, 0)
	newUICorner.Parent = newMainFrame

	local newUIStroke = Instance.new("UIStroke")
	newUIStroke.Thickness = 3
	newUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	newUIStroke.Transparency = 0
	newUIStroke.Parent = newMainFrame

	local newUIGradient = Instance.new("UIGradient")
	newUIGradient.Rotation = 0
	newUIGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0)
	})

	newUIGradient.Parent = newUIStroke

	local newArrowFrame = Instance.new("Frame")
	newArrowFrame.AnchorPoint = MIDDLE_ANCHOR_POINT
	newArrowFrame.Size = UDim2.fromScale(1, 1)
	newArrowFrame.Position = MIDDLE_POSITION
	newArrowFrame.BackgroundTransparency = 1
	newArrowFrame.Parent = newMainFrame
	newArrowFrame.Name = "ArrowFrame"

	local newArrowImage = Instance.new("ImageLabel")
	newArrowImage.BackgroundTransparency = 1
	newArrowImage.Image = "http://www.roblox.com/asset/?id=8213161276"
	newArrowImage.AnchorPoint = MIDDLE_ANCHOR_POINT
	newArrowImage.Position = UDim2.fromScale(0.5, -0.15)
	newArrowImage.Size = UDim2.fromScale(1, 0.85)
	newArrowImage.Parent = newArrowFrame
	newArrowImage.Name = "ArrowImage"

	local newIconImage = Instance.new("ImageLabel")
	newIconImage.AnchorPoint = MIDDLE_ANCHOR_POINT
	newIconImage.Position = MIDDLE_POSITION
	newIconImage.BackgroundTransparency = 1
	newIconImage.Size = UDim2.fromScale(0.75, 0.75)
	newIconImage.ZIndex = 2
	newIconImage.Parent = newMainFrame
	newIconImage.Name = "IconImage"
	

	local newIconCorner = newUICorner:Clone()
	newIconCorner.Parent = newIconImage

	return newMainFrame, newIconImage, newUIGradient
end

local function updateIndicatorUI(attachment, indicatorUI)
	local image = attachment:GetAttribute("Image") or ""
	local enabled = attachment:GetAttribute("Enabled") or false
	local color = attachment:GetAttribute("Color")

	if (not enabled) or (not color) or (image == "") then
		indicatorUI.Visible = false
		return
	end

	indicatorUI.BackgroundColor3 = color
	indicatorUI.UIStroke.Color = color
	indicatorUI.ArrowFrame.ArrowImage.ImageColor3 = color
	indicatorUI.IconImage.Image = image
end

function MarkersController:Setup()
	self._screenGui = Instance.new("ScreenGui")
	self._screenGui.Name = "IndicatorGui"
	self._screenGui.IgnoreGuiInset = true
	self._screenGui.ResetOnSpawn = false
	self._screenGui.DisplayOrder = 100
	self._screenGui.Parent = player:WaitForChild("PlayerGui")
end

function MarkerComponent:Construct()
	local newIndicator, iconImage, uiGradient = createNewIndicator()

	self._indicator = newIndicator
	self._connections = {}
	self._isVisible = false
	self._fadeTween = nil

	self._pulseTween = TweenService:Create(uiGradient, PULSE_INFO, {
		Rotation = 360
	})
	self._pulseTween:Play()

	local attributeChanged = self.Instance.AttributeChanged:Connect(function(name)
		if (name == "Image") or (name == "Color") or (name == "Enabled") or (name == "Range") then
			updateIndicatorUI(self.Instance, self._indicator)
		end
	end)
	table.insert(self._connections, attributeChanged)

	updateIndicatorUI(self.Instance, newIndicator)
	newIndicator.BackgroundTransparency = 1
	newIndicator.Visible = false
	newIndicator.Parent = MarkersController._screenGui

	table.insert(MarkersController._indicatorTable, {self.Instance, newIndicator, self._connections, self})
end

function MarkerComponent:Destroy()
	if self._pulseTween then
		self._pulseTween:Cancel()
		self._pulseTween = nil
	end

	if self._fadeTween then
		self._fadeTween:Cancel()
		self._fadeTween = nil
	end

	if self._indicator then
		self._indicator:Destroy()
	end

	for _, connection in ipairs(self._connections) do
		if connection then
			connection:Disconnect()
		end
	end

	for index, data in ipairs(MarkersController._indicatorTable) do
		if data[1] == self.Instance then
			table.remove(MarkersController._indicatorTable, index)
			break
		end
	end
end

function MarkersController:GameStart()
	self._updateConnection = RunService.RenderStepped:Connect(function()
		self:_UpdateIndicatorPositions()
	end)
end

function MarkersController:_UpdateIndicatorPositions()
	local viewportX = camera.ViewportSize.X
	local viewportY = camera.ViewportSize.Y

	if not self._indicatorTable[1] then return end
	local bufferSize = self._indicatorTable[1][2].AbsoluteSize.X

	local maxBoundsX = viewportX - (bufferSize * 2)
	local maxBoundsY = viewportY - (bufferSize * 2)

	local camCFrame = camera.CFrame
	local screenHypotenuse = math.sqrt((maxBoundsX/2)^2 + (maxBoundsY/2)^2)

	for _, data in ipairs(self._indicatorTable) do
		local attachment = data[1]
		local indicatorUI = data[2]
		local component = data[4]

		local range = attachment:GetAttribute("Range") or math.huge
		local position = attachment.WorldPosition
		local distance = (position - camCFrame.Position).Magnitude

		local shouldBeVisible = distance <= range

		if shouldBeVisible and not component._isVisible then
			component._isVisible = true
			indicatorUI.Visible = true
			indicatorUI.Size = UDim2.new(0, 0, 0, 0)
			indicatorUI.BackgroundTransparency = 1

			if component._fadeTween then
				component._fadeTween:Cancel()
			end

			component._fadeTween = TweenService:Create(indicatorUI, FADE_INFO, {
				BackgroundTransparency = 0,
				Size = DEFAULT_SIZE
			})
			component._fadeTween:Play()

		elseif not shouldBeVisible and component._isVisible then
			component._isVisible = false

			if component._fadeTween then
				component._fadeTween:Cancel()
			end

			component._fadeTween = TweenService:Create(indicatorUI, FADE_INFO, {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 0, 0)
			})
			component._fadeTween:Play()
			component._fadeTween.Completed:Connect(function()
				if not component._isVisible then
					indicatorUI.Visible = false
				end
			end)
		end

		if not component._isVisible then
			continue
		end

		local screenPosition3d, onScreen = camera:WorldToViewportPoint(position)

		local xPosition = math.clamp(screenPosition3d.X, bufferSize, viewportX - bufferSize)
		local yPosition = math.clamp(screenPosition3d.Y, bufferSize, viewportY - bufferSize)

		if (xPosition == screenPosition3d.X) and (yPosition == screenPosition3d.Y) and onScreen then
			indicatorUI.ArrowFrame.Visible = false
		else
			indicatorUI.ArrowFrame.Visible = true

			local worldDirection = position - camCFrame.Position
			local relativeDirection = camCFrame:VectorToObjectSpace(worldDirection)
			local relativeDirection2D = Vector2.new(relativeDirection.X, relativeDirection.Y).Unit

			local testScreenPoint = relativeDirection2D * screenHypotenuse

			local angle = math.atan2(relativeDirection2D.X, relativeDirection2D.Y)

			local screenPoint
			if math.abs(testScreenPoint.Y) > maxBoundsY/2 then
				screenPoint = relativeDirection2D * math.abs(maxBoundsY/2/relativeDirection2D.Y)
			else
				screenPoint = relativeDirection2D * math.abs(maxBoundsX/2/relativeDirection2D.X)
			end

			xPosition = viewportX / 2 + screenPoint.X
			yPosition = viewportY / 2 - screenPoint.Y

			indicatorUI.ArrowFrame.Rotation = math.deg(angle)
		end

		indicatorUI.Position = UDim2.fromOffset(xPosition, yPosition)
	end
end

function MarkersController:GetActiveIndicators()
	return self._indicatorTable
end

function MarkersController:ClearAll()
	for i = #self._indicatorTable, 1, -1 do
		local data = self._indicatorTable[i]
		if data[2] then
			data[2]:Destroy()
		end
		for _, connection in ipairs(data[3]) do
			if connection then
				connection:Disconnect()
			end
		end
	end
	self._indicatorTable = {}
end

function MarkersController:Destroy()
	if self._updateConnection then
		self._updateConnection:Disconnect()
	end
	self:ClearAll()
	if self._screenGui then
		self._screenGui:Destroy()
	end
end

return MarkersController
