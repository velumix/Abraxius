local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)

local AnimatedBackground = {}
AnimatedBackground.__index = AnimatedBackground

local DEFAULT_BACKGROUND_SCROLL_SPEED = 0.03

local PerformanceProfile = {
	DeviceType = "Desktop",
	CurrentFPS = 60,
	UpdateInterval = 1/60,
	FrameSkip = 1,
	LastFPSUpdate = 0,
	FPSHistory = {},
}

local function detectDevicePerformance()
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	if isMobile then
		PerformanceProfile.DeviceType = "Mobile"
		PerformanceProfile.UpdateInterval = 1/30
		PerformanceProfile.FrameSkip = 2
	else
		PerformanceProfile.DeviceType = "Desktop"
		PerformanceProfile.UpdateInterval = 1/60
		PerformanceProfile.FrameSkip = 1
	end
end

local function updatePerformanceMetrics(dt)
	local currentFPS = math.floor(1 / dt)
	PerformanceProfile.CurrentFPS = currentFPS

	table.insert(PerformanceProfile.FPSHistory, currentFPS)
	if #PerformanceProfile.FPSHistory > 30 then
		table.remove(PerformanceProfile.FPSHistory, 1)
	end

	local avgFPS = 0
	for _, fps in ipairs(PerformanceProfile.FPSHistory) do
		avgFPS += fps
	end
	avgFPS = avgFPS / #PerformanceProfile.FPSHistory

	if avgFPS < 25 then
		PerformanceProfile.FrameSkip = 4
		PerformanceProfile.UpdateInterval = 1/15
	elseif avgFPS < 40 then
		PerformanceProfile.FrameSkip = 2
		PerformanceProfile.UpdateInterval = 1/30
	elseif avgFPS > 55 then
		PerformanceProfile.FrameSkip = 1
		PerformanceProfile.UpdateInterval = 1/60
	end
end

detectDevicePerformance()

function AnimatedBackground.new(isVisibleCallback, defaultReferenceHeightCallback)
	local self = setmetatable({}, AnimatedBackground)

	self.animatedBackgrounds = {}
	self.animatedBackgroundLookup = {}
	self.backgroundConnection = nil
	self.isVisibleCallback = isVisibleCallback or function() return true end
	self.defaultReferenceHeightCallback = defaultReferenceHeightCallback or function() return 1000 end
	self.frameCounter = 0
	self.accumulatedDelta = 0
	self.lastUpdateTime = tick()

	return self
end

function AnimatedBackground:Stop(index)
	local data = self.animatedBackgrounds[index]
	if not data then
		return
	end

	for _, segment in ipairs(data.segments) do
		local instance = segment.instance
		if instance and instance ~= data.original then
			instance:Destroy()
		end
	end

	self.animatedBackgroundLookup[data.original] = nil
	table.remove(self.animatedBackgrounds, index)

	if #self.animatedBackgrounds == 0 and self.backgroundConnection then
		self.backgroundConnection:Disconnect()
		self.backgroundConnection = nil
	end
end

function AnimatedBackground:Refresh(data)
	for _, segment in ipairs(data.segments) do
		local instance = segment.instance
		if instance and instance.Parent then
			instance.Position = UDim2.new(data.xScale, data.xOffset, segment.startScale, segment.startOffset)
		end
	end
end

function AnimatedBackground:Start()
	if self.backgroundConnection then
		return
	end

	self.backgroundConnection = RunService.RenderStepped:Connect(function(dt)
		if #self.animatedBackgrounds == 0 then
			self.backgroundConnection:Disconnect()
			self.backgroundConnection = nil
			return
		end

		if not self.isVisibleCallback() then
			return
		end

		local currentTime = tick()
		if currentTime - PerformanceProfile.LastFPSUpdate > 1 then
			updatePerformanceMetrics(dt)
			PerformanceProfile.LastFPSUpdate = currentTime
		end

		self.frameCounter += 1
		if self.frameCounter % PerformanceProfile.FrameSkip ~= 0 then
			return
		end

		self.accumulatedDelta += dt

		for index = #self.animatedBackgrounds, 1, -1 do
			local data = self.animatedBackgrounds[index]
			local speed = data.speed
			if not data.original or not data.original.Parent then
				self:Stop(index)
				continue
			end

			if speed == 0 then
				continue
			end

			local referenceHeight = data.referenceHeight or 0
			if data.root then
				local rootHeight = data.root.AbsoluteSize.Y
				if rootHeight > 0 then
					referenceHeight = rootHeight
					data.referenceHeight = rootHeight
				end
			end

			if referenceHeight <= 0 then
				referenceHeight = self.defaultReferenceHeightCallback()
			end

			local parentHeight = (data.original.Parent and data.original.Parent.AbsoluteSize.Y) or 0
			if parentHeight <= 0 or referenceHeight <= 0 then
				continue
			end

			local delta = (speed * self.accumulatedDelta * referenceHeight) / parentHeight
			local currentSize = data.original.Size
			local spanScale = currentSize.Y.Scale
			local spanOffset = currentSize.Y.Offset
			if spanScale == 0 and spanOffset == 0 then
				spanScale = data.spanScale or 1
				spanOffset = data.spanOffset or 0
			else
				data.spanScale = spanScale
				data.spanOffset = spanOffset
			end
			local spanUnit = spanScale + (spanOffset / parentHeight)
			if spanUnit == 0 then
				spanUnit = 1
			end
			local segmentCount = #data.segments
			local wrapRange = spanUnit * math.max(segmentCount - 1, 1)
			for _, segment in ipairs(data.segments) do
				local instance = segment.instance
				if not instance or not instance.Parent then
					self:Stop(index)
					break
				end

				local newScale = instance.Position.Y.Scale + delta
				if newScale >= segment.startScale + spanUnit then
					newScale = newScale - wrapRange
				elseif newScale <= segment.startScale - spanUnit then
					newScale = newScale + wrapRange
				end
				instance.Position = UDim2.new(data.xScale, data.xOffset, newScale, segment.startOffset)
			end
		end
		self.accumulatedDelta = 0
	end)
end

function AnimatedBackground:Add(imageLabel, root)
	if self.animatedBackgroundLookup[imageLabel] then
		return
	end

	local position = imageLabel.Position
	local speedAttribute = tonumber(imageLabel:GetAttribute("AnimationSpeed"))
	local speed = speedAttribute or DEFAULT_BACKGROUND_SCROLL_SPEED
	if math.abs(speed) < 1e-5 then
		speed = 0
	end

	local size = imageLabel.Size
	local sizeScale = size.Y.Scale
	local sizeOffset = size.Y.Offset
	if sizeScale == 0 and sizeOffset == 0 then
		sizeScale = 1
	end

	local cloneAbove = imageLabel:Clone()
	cloneAbove.Name = imageLabel.Name .. "_LoopAbove"
	cloneAbove:SetAttribute("Animated", nil)
	cloneAbove.Parent = imageLabel.Parent
	cloneAbove.LayoutOrder = imageLabel.LayoutOrder
	cloneAbove.ZIndex = imageLabel.ZIndex
	cloneAbove.Position = UDim2.new(
		position.X.Scale,
		position.X.Offset,
		position.Y.Scale - sizeScale,
		position.Y.Offset - sizeOffset
	)

	local cloneBelow = imageLabel:Clone()
	cloneBelow.Name = imageLabel.Name .. "_LoopBelow"
	cloneBelow:SetAttribute("Animated", nil)
	cloneBelow.Parent = imageLabel.Parent
	cloneBelow.LayoutOrder = imageLabel.LayoutOrder
	cloneBelow.ZIndex = imageLabel.ZIndex
	cloneBelow.Position = UDim2.new(
		position.X.Scale,
		position.X.Offset,
		position.Y.Scale + sizeScale,
		position.Y.Offset + sizeOffset
	)

	local segments = {
		{
			instance = imageLabel,
			startScale = position.Y.Scale,
			startOffset = position.Y.Offset,
		},
		{
			instance = cloneAbove,
			startScale = cloneAbove.Position.Y.Scale,
			startOffset = cloneAbove.Position.Y.Offset,
		},
		{
			instance = cloneBelow,
			startScale = cloneBelow.Position.Y.Scale,
			startOffset = cloneBelow.Position.Y.Offset,
		}
	}

	local data = {
		original = imageLabel,
		segments = segments,
		speed = speed,
		xScale = position.X.Scale,
		xOffset = position.X.Offset,
		root = root,
		referenceHeight = (root and root.AbsoluteSize.Y) or self.defaultReferenceHeightCallback(),
		spanScale = sizeScale,
		spanOffset = sizeOffset,
	}

	self.animatedBackgroundLookup[imageLabel] = data
	self.animatedBackgrounds[#self.animatedBackgrounds + 1] = data
	self:Refresh(data)
	self:Start()
end

function AnimatedBackground:AddAll(root)
	if not root then
		return
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ImageLabel") and descendant:GetAttribute("Animated") then
			self:Add(descendant, root)
		end
	end
end

function AnimatedBackground:RefreshAll()
	for _, data in ipairs(self.animatedBackgrounds) do
		self:Refresh(data)
	end
end

function AnimatedBackground:Clear()
	for index = #self.animatedBackgrounds, 1, -1 do
		self:Stop(index)
	end
end

return AnimatedBackground
