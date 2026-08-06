local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local Mince = require(ReplicatedStorage.Modules.Mince)
local UIColors = require(ReplicatedStorage.Modules.UI.UIColors)
local UIFactory = require(ReplicatedStorage.Modules.UI.UIFactory)
local Mince = require(ReplicatedStorage.Modules.Mince)

local Config = require(script.Parent.Config)

local Encyclopedia = ReplicatedStorage.Assets.Encyclopedia
local Vertebrates = require(Encyclopedia.Vertebrates)
local Invertebrates = require(Encyclopedia.Invertebrates)
local CoralsAndPlants = require(Encyclopedia["Corals and Plants"])

local function tableFind(tbl, target)
	if not tbl then
		return false
	end
	for indx, val in tbl do
		if tostring(val) == tostring(target) then
			return true, indx
		end
	end
	return false
end

local function tableSize(tbl)
	local int = 0
	for _, val in tbl do
		int += 1
	end
	return int
end

local function findNodeById(tracker, targetId)
	if not tracker or not targetId then
		return nil
	end

	for _, node in tracker do
		if node.Type == "Dot" and tostring(node.Id) == tostring(targetId) then
			return node
		end
	end

	return nil
end

local function hasOpenConnections(node, tracker)
	if not node or not node.Links then
		return false
	end

	for _, linkId in node.Links do
		if not tableFind(node.Connections, linkId) then
			local linkedNode = findNodeById(tracker, linkId)
			if linkedNode then
				local alreadyConnectedBack = tableFind(linkedNode.Connections, node.Id)

				if not alreadyConnectedBack then
					-- pending link still open
					return true
				end
			else
				-- node is missing, no available connection.
			end
		end
	end
	return false
end

local function getConnectinStatus(node, tracker)
	if not node then
		return false
	end

	if not node.Links or tableSize(node.Links) == 0 then
		return true
	end

	return not hasOpenConnections(node, tracker)
end

local function getCursorHitRadius(frame)
	local size = frame.AbsoluteSize
	local radius = math.max(size.X, size.Y) * 0.5
	return math.max(radius, Config.MIN_CURSOR_HIT_RADIUS)
end

local function isPointWithinFrame(position, frame, padding)
	if not frame or not frame.Parent or not position then
		return false
	end

	padding = padding or 0

	local absolutePosition = frame.AbsolutePosition
	local absoluteSize = frame.AbsoluteSize

	local minX = absolutePosition.X - padding
	local maxX = absolutePosition.X + absoluteSize.X + padding
	local minY = absolutePosition.Y - padding
	local maxY = absolutePosition.Y + absoluteSize.Y + padding

	local x = position.X
	local y = position.Y

	return x >= minX and x <= maxX and y >= minY and y <= maxY
end

local function getFrameCenter(frame)
	if not frame then
		return nil
	end

	local position = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	return Vector2.new(position.X + size.X * 0.5, position.Y + size.Y * 0.5)
end

local function getSmartCursorCenter(cursor)
	if not cursor then
		return nil
	end

	local position = cursor.AbsolutePosition
	local size = cursor.AbsoluteSize
	return Vector2.new(position.X + size.X * 0.5, position.Y + size.Y * 0.5)
end

local function containsNode(list, target)
	if not target or not list then
		return false
	end

	for _, node in list do
		if node == target then
			return true
		end
	end

	return false
end

local function createPoof(parentFrame)
	local poof = UIFactory.createFrame(parentFrame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = parentFrame.ZIndex + 2
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)},
		Stroke = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 8,
			Color = UIColors.ScanNodeConnectableStroke,
			Transparency = 0
		}
	})

	local stroke = poof:FindFirstChildOfClass("UIStroke")
	local background = UIFactory.createFrame(poof, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIColors.ScanNodeConnectable,
		BackgroundTransparency = 0,
		BorderSizePixel = 0
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)},
		Gradient = {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0.2)
			})
		}
	})

	return poof, stroke, background
end

local function createBadge(button, text, color, strokeColor)
	local badge = UIFactory.createFrame(button, {
		Name = "NextBadge",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -20),
		Size = UDim2.fromOffset(72, 24),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		ZIndex = button.ZIndex + 3
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)},
		Stroke = {
			Color = strokeColor,
			Thickness = 2,
			Transparency = 0
		}
	})

	local label = UIFactory.createTextLabel(badge, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = UIColors.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center
	})

	local pointer = UIFactory.createFrame(badge, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		Rotation = 45,
		ZIndex = badge.ZIndex
	}, {
		Corner = {CornerRadius = UDim.new(0, 2)},
		Stroke = {
			Color = strokeColor,
			Thickness = 2,
			LineJoinMode = Enum.LineJoinMode.Miter,
			Transparency = 0
		}
	})

	return badge, label, pointer
end

local function getPopperModules()
	local cameraModule = LocalPlayer
		and LocalPlayer:FindFirstChild("PlayerScripts")
		and LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
		and LocalPlayer.PlayerScripts.PlayerModule:FindFirstChild("CameraModule")

	local popperModule = cameraModule and cameraModule:FindFirstChild("Poppercam")
	local zoomModule = cameraModule and cameraModule:FindFirstChild("ZoomController")
	if not popperModule or not zoomModule then
		return nil, nil
	end

	local popperOk, popper = pcall(require, popperModule)
	local zoomOk, zoom = pcall(require, zoomModule)
	if not (popperOk and zoomOk) then
		return nil, nil
	end

	return popper, zoom
end

local function getStickyReleaseThreshold()
	local base = Config.SKELETON_STICK_RELEASE_DISTANCE or (Config.SKELETON_STICK_DISTANCE or 48)
	local stick = Config.SKELETON_STICK_DISTANCE or base
	local scaled = math.min(base, stick * 0.4)
	return math.max(scaled, 8)
end

local function createNextIndicator(self, targetDot, labelText)
	if not self or not targetDot or targetDot.Type ~= "Dot" then
		return
	end

	local controller = self.scanController

	local button = targetDot.Frame
	if not button or not button.Parent then
		return
	end

	local badge, _, pointer = createBadge(button, labelText or "NEXT", UIColors.ScanNodeRecommendation, UIColors.ScanNodeRecommendationStroke)
	if not badge then
		return
	end

	if controller and controller.SkeletalGuide then
		controller.SkeletalGuide:Add(badge)
		if pointer then
			controller.SkeletalGuide:Add(pointer)
		end
		controller.SkeletalGuide:Add(function()
			if badge and badge.Parent then
				badge:Destroy()
			end
		end)
	end
end

local function resetCursorTargets(scanController)
	local cursorManager = scanController.CursorManager
	if cursorManager and cursorManager.ResetCursorTargets then
		cursorManager:ResetCursorTargets()
	elseif scanController.ResetCursorTargets then
		scanController:ResetCursorTargets()
	else
		scanController.SmartCursorAllowList = {}
		scanController.CurrentConnectableFrames = {}
		scanController.AutoCursorTarget = nil
	end
end

local SkeletonManager = {}
SkeletonManager.__index = SkeletonManager

function SkeletonManager.new(scanController)
	local self = setmetatable({}, SkeletonManager)
	self.scanController = scanController
	self.resetConnection = nil
	self.popperCam = nil
	self.popperZoom = nil

	local popperModule, zoomModule = getPopperModules()
	if popperModule and zoomModule then
		self.popperCam = popperModule.new and popperModule.new() or popperModule
		self.popperZoom = zoomModule
	end

	if scanController and scanController.SessionReset then
		self.resetConnection = scanController.SessionReset:Connect(function()
			self:OnSessionReset()
		end)
	end
	return self
end

function SkeletonManager:OnSessionReset()
	local controller = self.scanController
	if not controller then
		return
	end

	resetCursorTargets(controller)

	controller.SkeletalTracker = {}
	controller.SkeletonConnectionLine = nil
	controller.SelectedSkeletalNode = nil
	controller.SelectedDotObject = nil
	controller.SkeletonMode = false
	controller.LockedIntoTarget = false
	controller.TargetLockProgress = 0

	if controller.NavigatorTooltip then
		controller.NavigatorTooltip.Text = Config.DEFAULT_GUIDE_MESSAGE
		controller.NavigatorTooltip.TextTransparency = 1
		controller.NavigatorTooltip.Visible = false
	end

	self:RefreshNodeCompletionStates()
end

function SkeletonManager:ApplyNodeStyle(nodeObject, styleName)
	if not nodeObject or nodeObject.Type ~= "Dot" then
		return
	end

	local frame = nodeObject.Frame
	if not frame then
		return
	end

	local style = Config.NODE_STYLES[styleName] or Config.NODE_STYLES.Default
	frame.BackgroundColor3 = style.Background or frame.BackgroundColor3
	frame.BackgroundTransparency = style.BackgroundTransparency or 0.1
	frame.AutoButtonColor = false
	if nodeObject.Stroke then
		nodeObject.Stroke.Color = style.Stroke or nodeObject.Stroke.Color
		nodeObject.Stroke.Thickness = style.StrokeThickness or nodeObject.Stroke.Thickness
		nodeObject.Stroke.Transparency = 0
	end

	nodeObject.CurrentStyle = styleName or "Default"
end

function SkeletonManager:ApplyNodeStyleSmooth(nodeObject, styleName)
	if not nodeObject or nodeObject.Type ~= "Dot" then
		return
	end

	if self.scanController and self.scanController.EffectsManager then
		self.scanController.EffectsManager:PlayNodeStateTransition(nodeObject, styleName)
	else
		self:ApplyNodeStyle(nodeObject, styleName)
	end
end

function SkeletonManager:GetNextRecommendedNode(currentNode)
	local preferred
	local preferredScore = math.huge
	local preferredConnections = math.huge

	local fallback
	local fallbackScore = math.huge
	local fallbackConnections = math.huge

	for _, nodeObject in self.scanController.SkeletalTracker do
		if nodeObject.Type ~= "Dot" then
			continue
		end

		if nodeObject.AllConnected or nodeObject == currentNode or not nodeObject.Position then
			continue
		end

		local connectionCount = tableSize(nodeObject.Connections)
		local distance
		if currentNode and currentNode.Position then
			distance = (nodeObject.Position - currentNode.Position).Magnitude
		else
			distance = nodeObject.Position.Magnitude
		end

		local score = distance + connectionCount * Config.CONNECTION_SCORE_WEIGHT
		local isLinkedToCurrent = currentNode and tableFind(nodeObject.Links, currentNode.Id)

		if isLinkedToCurrent then
			if score < preferredScore or (math.abs(score - preferredScore) < 1e-3 and connectionCount < preferredConnections) then
				preferred = nodeObject
				preferredScore = score
				preferredConnections = connectionCount
			end
		else
			if score < fallbackScore or (math.abs(score - fallbackScore) < 1e-3 and connectionCount < fallbackConnections) then
				fallback = nodeObject
				fallbackScore = score
				fallbackConnections = connectionCount
			end
		end
	end

	return preferred or fallback
end

function SkeletonManager:PlayConnectionTrail(startFrame, endFrame, SkeletalMap)
	if not startFrame or not endFrame then
		return
	end

	local container = startFrame.Parent
	if not container or not endFrame.Parent then
		return
	end

	if container ~= endFrame.Parent then
		container = SkeletalMap.On
	end

	if not container then
		return
	end

	local startPos = Vector2.new(
		startFrame.AbsolutePosition.X + startFrame.AbsoluteSize.X / 2,
		startFrame.AbsolutePosition.Y + startFrame.AbsoluteSize.Y / 2
	)

	local endPos = Vector2.new(
		endFrame.AbsolutePosition.X + endFrame.AbsoluteSize.X / 2,
		endFrame.AbsolutePosition.Y + endFrame.AbsoluteSize.Y / 2
	)

	local delta = endPos - startPos
	local length = delta.Magnitude
	if length < 1 then
		return
	end

	local midpoint = startPos + delta * 0.5
	local angle = math.deg(math.atan2(delta.Y, delta.X))
	local containerOffset = container.AbsolutePosition

	local trail = Instance.new("Frame")
	trail.AnchorPoint = Vector2.new(0.5, 0.5)
	trail.BackgroundColor3 = UIColors.ScanNodeConnectableStroke
	trail.BackgroundTransparency = Config.CONNECTION_TRAIL_TRANSPARENCY
	trail.BorderSizePixel = 0
	trail.Size = UDim2.fromOffset(length, Config.CONNECTION_TRAIL_HEIGHT)
	trail.Position = UDim2.fromOffset(midpoint.X - containerOffset.X, midpoint.Y - containerOffset.Y)
	trail.Rotation = angle
	trail.ZIndex = math.max(startFrame.ZIndex, endFrame.ZIndex) + 1
	trail.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = trail

	local pulse = Instance.new("Frame")
	pulse.AnchorPoint = Vector2.new(0.5, 0.5)
	pulse.BackgroundColor3 = UIColors.ScanNodeConnectable
	pulse.BorderSizePixel = 0
	pulse.Size = UDim2.fromOffset(10, 10)
	pulse.Position = UDim2.new(0, 0, 0.5, 0)
	pulse.Parent = trail
	pulse.ZIndex = trail.ZIndex + 1

	local pulseCorner = Instance.new("UICorner")
	pulseCorner.CornerRadius = UDim.new(1, 0)
	pulseCorner.Parent = pulse

	local travelTween = TweenService:Create(
		pulse,
		TweenInfo.new(Config.CONNECTION_TRAIL_PULSE_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(4, 4), BackgroundTransparency = 1}
	)

	local fadeTween = TweenService:Create(
		trail,
		TweenInfo.new(Config.CONNECTION_TRAIL_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	)

	travelTween:Play()
	fadeTween:Play()

	travelTween.Completed:Connect(function()
		if pulse and pulse.Parent then
			pulse:Destroy()
		end
	end)

	fadeTween.Completed:Connect(function()
		if trail and trail.Parent then
			trail:Destroy()
		end
	end)
end

function SkeletonManager:CreatePulseRing(frame, delay)
	if not frame or not frame.Parent then
		return
	end

	local effectScale = Config.SKELETON_EFFECT_SCALE or 1

	local ring = UIFactory.createFrame(frame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(1.2 * effectScale, 1.2 * effectScale),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = frame.ZIndex + 1
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)},
		Stroke = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 4 * effectScale,
			Color = UIColors.ScanNodeConnectableStroke,
			Transparency = 0.3
		}
	})

	local ringStroke = ring:FindFirstChildOfClass("UIStroke")

	local expandTween = TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(2.5 * effectScale, 2.5 * effectScale)})
	local fadeTween = TweenService:Create(ringStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Thickness = 1, Transparency = 1})

	expandTween.Completed:Connect(function()
		if ring and ring.Parent then
			ring:Destroy()
		end
	end)

	task.delay(delay, function()
		if ring and ring.Parent then
			expandTween:Play()
			fadeTween:Play()
		end
	end)
end

function SkeletonManager:PlayNodeCompletionEffect(nodeObject)
	if not nodeObject or nodeObject.Type ~= "Dot" then
		return
	end

	local frame = nodeObject.Frame
	if not frame or not frame.Parent then
		return
	end

	local effectScale = Config.SKELETON_EFFECT_SCALE or 1

	local burst = UIFactory.createFrame(frame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(1 * effectScale, 1 * effectScale),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = UIColors.ScanNodeCompleted,
		BackgroundTransparency = 0.3,
		ZIndex = frame.ZIndex + 1
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)},
		Stroke = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 6 * effectScale,
			Color = UIColors.ScanNodeCompletedStroke,
			Transparency = 0
		},
		Gradient = {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.8),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 0.8)
			})
		}
	})

	local stroke = burst:FindFirstChildOfClass("UIStroke")

	local expandTween = TweenService:Create(burst, Config.COMPLETION_BURST_TWEEN, {Size = UDim2.fromScale(2.2 * effectScale, 2.2 * effectScale)})
	local fadeTween = TweenService:Create(stroke, Config.COMPLETION_FADE_TWEEN, {Thickness = 0, Transparency = 1})
	local bgFade = TweenService:Create(burst, Config.COMPLETION_FADE_TWEEN, {BackgroundTransparency = 1})

	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		task.delay(i * Config.COMPLETION_EFFECT_DELAY, function()
			self:CreateSparkle(frame, angle)
		end)
	end

	self.scanController.SkeletalGuide:Add(burst)
	self.scanController.SkeletalGuide:Add(stroke)

	local completionConn
	completionConn = expandTween.Completed:Connect(function()
		if completionConn then
			completionConn:Disconnect()
			completionConn = nil
		end
		if burst and burst.Parent then
			burst:Destroy()
		end
	end)

	self.scanController.SkeletalGuide:Add(completionConn)

	self.scanController.SkeletalGuide:Add(function()
		expandTween:Cancel()
		fadeTween:Cancel()
		bgFade:Cancel()
		if completionConn then
			completionConn:Disconnect()
			completionConn = nil
		end
		if burst and burst.Parent then
			burst:Destroy()
		end
	end)

	expandTween:Play()
	fadeTween:Play()
	bgFade:Play()

end

function SkeletonManager:CreateSparkle(frame, angle)
	if not frame or not frame.Parent then
		return
	end

	local effectScale = Config.SKELETON_EFFECT_SCALE or 1

	local sparkle = UIFactory.createFrame(frame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6 * effectScale, 6 * effectScale),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = UIColors.ScanNodeCompletedStroke,
		BackgroundTransparency = 0,
		ZIndex = frame.ZIndex + 2
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)}
	})

	local distance = Config.SPARKLE_DISTANCE * effectScale
	local targetX = 0.5 + (math.cos(angle) * distance) / frame.AbsoluteSize.X
	local targetY = 0.5 + (math.sin(angle) * distance) / frame.AbsoluteSize.Y

	local moveTween = TweenService:Create(sparkle, Config.SPARKLE_TWEEN, {Position = UDim2.fromScale(targetX, targetY)})
	local fadeTween = TweenService:Create(sparkle, Config.SPARKLE_TWEEN, {BackgroundTransparency = 1, Size = UDim2.fromOffset(2 * effectScale, 2 * effectScale)})

	moveTween.Completed:Connect(function()
		if sparkle and sparkle.Parent then
			sparkle:Destroy()
		end
	end)

	moveTween:Play()
	fadeTween:Play()
end

function SkeletonManager:StartSkeletalConnection(node)
	if not node or not node.Frame then
		return
	end

	local SkeletalMap = self.scanController.SkeletalMap
	if not SkeletalMap or not SkeletalMap.On then
		return
	end

	local newLine = Instance.new("Frame")
	newLine.AnchorPoint = Vector2.new(0.5, 0.5)
	newLine.Size = UDim2.fromOffset(0, 10)
	newLine.BorderSizePixel = 0
	newLine.BackgroundColor3 = UIColors.Stroke
	newLine.Parent = SkeletalMap.On

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(1, 0)
	uiCorner.Parent = newLine

	local metadata = {
		Type = "Line",
		Frame = newLine,
		Points = {
			node.Frame
		},
		AllowedLinks = node.Links
	}

	self.scanController.SkeletalTrove:Add(newLine)
	self.scanController.SkeletonConnectionLine = metadata
	table.insert(self.scanController.SkeletalTracker, metadata)
end

function SkeletonManager:UnhighlightSkeletalNodes(ignoreList, doNotTween)
	ignoreList = ignoreList or {}
	local SkeletalMap = self.scanController.SkeletalMap
	if not SkeletalMap then
		return
	end

	self.scanController.AutoCursorTarget = nil

	local lineData = self.scanController.SkeletonConnectionLine

	for index, linkObject in self.scanController.SkeletalTracker do
		if linkObject.Type == "Dot" and not tableFind(ignoreList, linkObject.Id) then
			self:ApplyNodeStyle(linkObject, linkObject.AllConnected and "Completed" or "Default")

			local frame = linkObject.Frame
			if frame and frame.Parent then
				local function moveOff()
					if frame and frame.Parent then
						frame.Parent = SkeletalMap.Off
						frame.Transparency = 0
					end
				end

				if doNotTween then
					moveOff()
				else
					local tweenOut = TweenService:Create(frame, TweenInfo.new(0.3), {Transparency = 0.6})
					tweenOut.Completed:Connect(moveOff)
					tweenOut:Play()
				end
			end
		elseif lineData and linkObject.Frame == lineData.Frame then
			if linkObject.Frame then
				linkObject.Frame:Destroy()
			end
			self.scanController.SkeletonConnectionLine = nil
			table.remove(self.scanController.SkeletalTracker, index)
			break
		end
	end

	resetCursorTargets(self.scanController)
	self:UpdateSkeletalGuidance({}, nil, nil, nil)
end

function SkeletonManager:DefaultHighlightStatus(doNotTween)
	local SkeletalMap = self.scanController.SkeletalMap
	if not SkeletalMap then
		return
	end

	self.scanController.AutoCursorTarget = nil

	for _, linkObject in self.scanController.SkeletalTracker do
		if linkObject.Type == "Dot" or linkObject.Type == "Line" then
			local frame = linkObject.Frame
			if frame and frame.Parent then
				frame.Parent = SkeletalMap.On

				if not doNotTween then
					frame.Transparency = 0.6
					local tweenIn = TweenService:Create(frame, TweenInfo.new(0.3), {Transparency = 0})
					tweenIn:Play()
				else
					frame.Transparency = 0
				end

				if linkObject.Type == "Dot" then
					local styleName = linkObject.AllConnected and "Completed" or "Default"
					self:ApplyNodeStyle(linkObject, styleName)
				end
			end
		end
	end

	resetCursorTargets(self.scanController)

	local selected = self.scanController.SelectedSkeletalNode
	if selected then
		self:ApplyNodeStyle(selected, selected.AllConnected and "Completed" or "Selected")
	end

	self:UpdateSkeletalGuidance({}, self.scanController.SelectedSkeletalNode, nil, nil)
end

function SkeletonManager:HighlightSkeletalNodes(targetList, options)
	local SkeletalMap = self.scanController.SkeletalMap
	if not SkeletalMap then
		return
	end

	targetList = targetList or {}
	options = options or {}

	local skipAutoSnap = options.skipAutoSnap or false
	local previousStickyNode = self.scanController.SmartCursorStickyNode

	resetCursorTargets(self.scanController)
	self.scanController.SmartCursorStickyNode = previousStickyNode

	local connectableDots = {}
	local connectableById = {}
	local allowFrames = {}
	local selected = self.scanController.SelectedSkeletalNode
	local cursorManager = self.scanController.CursorManager

	for _, nodeObject in self.scanController.SkeletalTracker do
		if nodeObject.Type ~= "Dot" then
			continue
		end

		if nodeObject ~= selected then
			local baseStyle = nodeObject.AllConnected and "Completed" or "Default"
			self:ApplyNodeStyle(nodeObject, baseStyle)
		end
	end

	for _, linkObject in self.scanController.SkeletalTracker do
		if linkObject.Type == "Dot" and tableFind(targetList, linkObject.Id) then
			local frame = linkObject.Frame
			if not frame or not frame.Parent then
				continue
			end

			if linkObject == selected or linkObject.AllConnected then
				frame.Parent = SkeletalMap.On
				frame.Transparency = 0
				continue
			end

			frame.Parent = SkeletalMap.On
			frame.Transparency = 0.6

			local tweenIn = TweenService:Create(frame, TweenInfo.new(0.3), {Transparency = 0})
			tweenIn:Play()

			self:ApplyNodeStyle(linkObject, "Connectable")
			table.insert(connectableDots, linkObject)
			connectableById[linkObject.Id] = linkObject
			table.insert(allowFrames, frame)
		end
	end

	local recommendedDot

	if selected and #connectableDots == 0 then
		recommendedDot = self:GetNextRecommendedNode(selected)
		if recommendedDot and recommendedDot ~= selected then
			self:ApplyNodeStyle(recommendedDot, "Recommendation")
		end
	end

	if selected then
		local selectedStyle = selected.AllConnected and "Completed" or "Selected"
		self:ApplyNodeStyle(selected, selectedStyle)
	end

	self.scanController.SmartCursorAllowList = allowFrames
	self.scanController.CurrentConnectableFrames = allowFrames

	local smartCursor = cursorManager and cursorManager:GetSmartCursor()
	local cursorCenter = smartCursor and getSmartCursorCenter(smartCursor)
	local stickyNode = nil

	if cursorCenter then
		local stickyCandidates = {}

		for _, dotObject in connectableDots do
			table.insert(stickyCandidates, dotObject)
		end

		if recommendedDot and recommendedDot.Frame and recommendedDot ~= selected then
			table.insert(stickyCandidates, recommendedDot)
		end

		if #stickyCandidates == 0 and selected and selected.Frame then
			table.insert(stickyCandidates, selected)
		end

		if previousStickyNode and previousStickyNode ~= selected and containsNode(stickyCandidates, previousStickyNode) then
			local frame = previousStickyNode.Frame
			if frame and frame.Parent then
				local distance = (cursorCenter - getFrameCenter(frame)).Magnitude
				if distance <= getStickyReleaseThreshold() then
					stickyNode = previousStickyNode
				end
			end
		end

		if not stickyNode then
			local stickThreshold = Config.SKELETON_STICK_DISTANCE
			local closestDistance = math.huge

			for _, candidate in stickyCandidates do
				local frame = candidate and candidate.Frame
				if frame and frame.Parent then
					local distance = (cursorCenter - getFrameCenter(frame)).Magnitude
					if distance <= stickThreshold and distance < closestDistance then
						closestDistance = distance
						stickyNode = candidate
					end
				end
			end
		end

		local allowSticky = not self:IsConsoleInput()
		if allowSticky and stickyNode and stickyNode ~= selected then
			self.scanController.SmartCursorStickyNode = stickyNode
			if cursorManager and cursorManager.SnapCursorToNode then
				cursorManager:SnapCursorToNode(stickyNode, smartCursor)
			end
			skipAutoSnap = true
		else
			self.scanController.SmartCursorStickyNode = nil
		end
	else
		self.scanController.SmartCursorStickyNode = nil
	end

	local nextAutoTarget

	if #connectableDots > 0 then

		if selected and selected.Links then
			for _, linkId in selected.Links do
				local candidate = connectableById[tostring(linkId)]
				if candidate and not candidate.AllConnected then
					nextAutoTarget = candidate
					break
				end
			end
		end

		if not nextAutoTarget then
			nextAutoTarget = connectableDots[1]
		end
	end

	if not nextAutoTarget and recommendedDot and not recommendedDot.AllConnected then
		nextAutoTarget = recommendedDot
	end

	self.scanController.AutoCursorTarget = nextAutoTarget

	if nextAutoTarget and nextAutoTarget ~= selected and not skipAutoSnap then
		if cursorManager and cursorManager.SnapCursorToNode and not self:IsConsoleInput() then
			cursorManager:SnapCursorToNode(nextAutoTarget)
		end
	end

	self:UpdateSkeletalGuidance(connectableDots, selected, targetList, recommendedDot)
end

function SkeletonManager:GetNodeFromScreenPosition(position2d, includesGuiInset)
	local tracker = self.scanController and self.scanController.SkeletalTracker
	if not tracker or not position2d then
		return nil
	end

	local adjustedPosition = position2d
	if includesGuiInset then
		local guiInset = GuiService:GetGuiInset()
		adjustedPosition = Vector2.new(position2d.X, position2d.Y - guiInset.Y)
	end

	local allowList = self.scanController.SmartCursorAllowList
	local hasAllowList = allowList and #allowList > 0
	local padding = Config.SKELETON_CLICK_PADDING or 0
	local closestNode, closestDistance

	for _, node in tracker do
		if node.Type ~= "Dot" then
			continue
		end

		local frame = node.Frame
		if not frame or not frame.Parent then
			continue
		end

		if node.AllConnected and hasAllowList and not tableFind(allowList, frame) then
			continue
		end

		local center = getFrameCenter(frame)
		if not center then
			continue
		end

		local radius = getCursorHitRadius(frame) + padding
		local distance = (adjustedPosition - center).Magnitude
		if distance <= radius and (not closestDistance or distance < closestDistance) then
			closestNode = node
			closestDistance = distance
		end
	end

	return closestNode
end

function SkeletonManager:ResolveTouchSelection(position2d)
	if not position2d then
		return nil
	end

	local tappedNode = self:GetNodeFromScreenPosition(position2d, true)
	if not tappedNode then
		tappedNode = self:GetNodeFromScreenPosition(position2d, false)
	end

	if not tappedNode then
		tappedNode = self.scanController.AutoCursorTarget
	end

	if not tappedNode then
		tappedNode = self.scanController.SelectedDotObject
	end

	return tappedNode
end

function SkeletonManager:IsConsoleInput()
	local controller = self.scanController
	if not controller then
		return GuiService:IsTenFootInterface()
	end

	local inputHandler = controller.InputHandler
	if inputHandler and inputHandler.GetDevice then
		local device = inputHandler:GetDevice()
		if device == "xbox" then
			return true
		end
	end

	if GuiService:IsTenFootInterface() then
		return true
	end

	return UserInputService.GamepadEnabled and not UserInputService.TouchEnabled
end

function SkeletonManager:MouseMove(actionName, inputState, inputObject)
	if not self.scanController.Enabled then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Change then
		local stickyNode = self.scanController.SmartCursorStickyNode
		if stickyNode then
			local cursorManager = self.scanController.CursorManager
			local smartCursor = cursorManager and cursorManager:GetSmartCursor()
			local nodeFrame = stickyNode.Frame
			if smartCursor and nodeFrame and nodeFrame.Parent then
				local cursorCenter = getSmartCursorCenter(smartCursor)
				local nodeCenter = getFrameCenter(nodeFrame)
				if cursorCenter and nodeCenter then
					local distance = (cursorCenter - nodeCenter).Magnitude
					if distance > getStickyReleaseThreshold() then
						self.scanController.SmartCursorStickyNode = nil
					end
				end
			else
				self.scanController.SmartCursorStickyNode = nil
			end
		end

		local userInputType = inputObject.UserInputType
		local keyCode = inputObject.KeyCode
		local mouseDelta = inputObject.Delta or Vector3.zero

		if userInputType == Enum.UserInputType.Touch then
			local touchDelta = self.scanController and self.scanController.TouchDelta
			if typeof(touchDelta) == "Vector2" then
				mouseDelta = Vector3.new(touchDelta.X, touchDelta.Y, 0)
			end
		end

		if userInputType == Enum.UserInputType.Gamepad1 and keyCode == Enum.KeyCode.Thumbstick1 then
			local thumbstick = inputObject.Position or Vector3.zero
			local magnitude = thumbstick.Magnitude
			local deadzone = Config.GAMEPAD_CURSOR_DEADZONE or 0.18
			if magnitude < deadzone then
				mouseDelta = Vector3.zero
			else
				local speed = Config.GAMEPAD_CURSOR_SPEED or 28
				mouseDelta = Vector3.new(thumbstick.X * speed, -thumbstick.Y * speed, 0)
			end
		end

		local mouseSpeed = mouseDelta.Magnitude

		self.scanController.MouseDelta = mouseDelta
		self.scanController.AutoCursorTarget = nil

		if os.clock() - self.scanController.SmartCursorLastLock > Config.SMART_CURSOR_LOCK_THRESHOLD and self.scanController.SmartCursorLocked  then
			self.scanController.LastSelection = self.scanController.SmartCursorLockedTo
			self.scanController.SelectedDotObject = nil
			self.scanController.SmartCursorLocked = false
			self.scanController.SmartCursorLockedTo = nil
		end

		self.scanController.LastCursorMove = os.clock()
	end

	return Enum.ContextActionResult.Pass
end

function SkeletonManager:Trigger(actionName, inputState, inputObject)
	if not self.scanController.Enabled then
		return Enum.ContextActionResult.Pass
	end

	self.scanController.MouseHeld = inputState == Enum.UserInputState.Begin

	local isRelease = inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel
	if isRelease then
		if not self.scanController.Locked and self.scanController.CheckNoTargetOnRelease then
			self.scanController.CheckNoTargetOnRelease = false
			self.scanController:NotifyNoTargetsInRange()
		else
			self.scanController.CheckNoTargetOnRelease = false
		end
		return Enum.ContextActionResult.Pass
	end

	if not self.scanController.Locked and self.scanController.MouseHeld and inputState == Enum.UserInputState.Begin then
		if self.scanController.Sounds and self.scanController.Sounds.Scanning then
			self.scanController.Sounds.Scanning:Play()
		else
			warn("Scanning sound not found or Sounds table is nil")
		end
		self.scanController.ScanStarted:Fire()
	end

	if self.scanController.Locked and not self.scanController.SkeletonMode then
		local informationFrame = self.scanController.ScanViewFrame.Information
		local navigatorFrame = self.scanController.ScanViewFrame.Navigator
		local tooltip = navigatorFrame.Tooltip

		if not self.scanController.LockedTo then
			self.scanController.MouseHeld = false
			return Enum.ContextActionResult.Pass
		end

		local id = self.scanController.LockedTo:GetAttribute("_fishId")

		if not id then
			id = self.scanController.LockedTo.Parent:GetAttribute("_fishId")
		end

		local isTouch = inputObject.UserInputType == Enum.UserInputType.Touch
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		if not id then
			warn("no id detected")
			self.scanController.MouseHeld = false
			return Enum.ContextActionResult.Pass
		end

		local Encyclopedia = ReplicatedStorage.Assets.Encyclopedia
		local DiscoveryTypes = {"Vertebrates", "Invertebrates", "Corals and Plants"}
		local config = nil
		local discoveryType = nil

		for _, dtype in ipairs(DiscoveryTypes) do
			local path = dtype == "Corals and Plants" and Encyclopedia["Corals and Plants"] or Encyclopedia[dtype]
			if path then
				local encyclopedia = require(path)
				if encyclopedia and encyclopedia[id] then
					config = encyclopedia[id]
					discoveryType = dtype
					break
				end
			end
		end

		if not config then
			warn("the configuration is not properly setup, please cross-reference the ids")
			self.scanController.MouseHeld = false
			return Enum.ContextActionResult.Pass
		end

		local skeleton = config.Skeleton

		if not skeleton then
			warn("no skeleton found for the selected creature")
			self.scanController.MouseHeld = false
			return Enum.ContextActionResult.Pass
		end

		local size = self.scanController.LockedTo:IsA("Model") and self.scanController.LockedTo:GetExtentsSize()
			or self.scanController.LockedTo.Size
		local longestAxis = math.max(size.X, size.Y, size.Z)

		local baseCameraMultiplier = 2.5
		local sizeScalingFactor = math.clamp(longestAxis / 10, 1, 2)
		local cameraDistance = longestAxis * baseCameraMultiplier * sizeScalingFactor

		local sideRotation = 0
		if size.X == longestAxis then
			sideRotation = 90
		elseif size.Z == longestAxis then
			sideRotation = 0
		else
			sideRotation = 0
		end

		self.scanController.CameraAngle.Z = cameraDistance
		self.scanController.CameraAngle.Zt = cameraDistance
		self.scanController.CameraAngle.X = sideRotation - 90
		self.scanController.CameraAngle.Y = 8
		self.scanController.LockedFishSize = longestAxis
		self.scanController.CameraAngle.Side = -longestAxis * Config.FISH_SIDE_OFFSET_MULTIPLIER
		self.scanController.MinimumDistance = longestAxis * 2
		self.scanController.OriginalCameraCF = CurrentCamera.CFrame
		self.scanController.TargetLockProgress = 0
		self.scanController.LockedIntoTarget = false


		if self.scanController and self.scanController._updateCreatureLabels then
			self.scanController:_updateCreatureLabels(config, discoveryType, id)
		else
			local DiscoveryManager = Mince:Get("DiscoveryManager")
			local isDiscovered = discoveryType and DiscoveryManager:HasDiscovered(discoveryType, id) or false
			if self.scanController.CreatureName then
				self.scanController.CreatureName.Text = isDiscovered and (config.Name or "?????") or "?????"
			end
			if self.scanController.ScientificName and config.Aliases then
				self.scanController.ScientificName.Text = isDiscovered and (config.Aliases[1] or "") or ""
			end
		end

		self.scanController.SkeletonMode = true
		self.scanController.MouseHeld = false

		if self.popperCam and self.popperCam.Enable then
			self.popperCam:Enable(true)
		end

		local isRightDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		self.scanController.RightClickHeld = isRightDown
		if isRightDown then
			self.scanController.CameraAngle.Side = 0
			self.scanController.AutoCursorTarget = nil
		end

		self.scanController.MouseDelta = Vector3.zero
		self.scanController.Humanoid.WalkSpeed = 0

		if self.scanController.CCM then
			self.scanController:_acquireCameraControl({
				mode = "Skeleton",
				target = self.scanController.LockedTo,
			})
		end

		CurrentCamera.CameraType = Enum.CameraType.Scriptable
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		UserInputService.MouseDeltaSensitivity = Config.MOUSE_DELTA_SENSITIVITY
		UserInputService.MouseIconEnabled = false

		local cursorManager = self.scanController.CursorManager
		if cursorManager then
			cursorManager:CenterSmartCursor()
			cursorManager:HideScannerCursor()
			cursorManager:SetSmartCursorVisible(not UserInputService.TouchEnabled)
		else
			local smartCursor = self.scanController.SmartCursor
			if smartCursor then
				smartCursor.Position = UDim2.fromOffset(
					CurrentCamera.ViewportSize.X * 0.5,
					CurrentCamera.ViewportSize.Y * 0.5
				)
				smartCursor.Visible = not UserInputService.TouchEnabled
			end

			local scannerCursor = self.scanController.ScannerCursor
			if scannerCursor then
				scannerCursor.Visible = false
			end
		end
		GuiService.TouchControlsEnabled = false

		RunService:UnbindFromRenderStep("ScannerMouseLock")

		self:CreateSkeletalMap(self.scanController.LockedTo, skeleton)

		self.scanController.CreatureLocked:Fire(self.scanController.LockedTo)
	elseif self.scanController.SkeletonMode then
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		local selected = self.scanController.SelectedDotObject
		local inputType = inputObject.UserInputType
		local isTouch = inputType == Enum.UserInputType.Touch
		local isGamepad = inputType == Enum.UserInputType.Gamepad1

		if isTouch then
			local clickPosition = inputObject.Position
			local tapPosition = clickPosition and Vector2.new(clickPosition.X, clickPosition.Y)
			local tappedNode = self:ResolveTouchSelection(tapPosition)
			if tappedNode then
				selected = tappedNode
				self.scanController.SelectedDotObject = tappedNode
			end
		elseif isGamepad and not selected then
			selected = self.scanController.AutoCursorTarget or selected

			if not selected then
				local cursorManager = self.scanController.CursorManager
				local smartCursor = cursorManager and cursorManager:GetSmartCursor()
				local cursorCenter = getSmartCursorCenter(smartCursor)
				if cursorCenter then
					selected = self:GetNodeFromScreenPosition(cursorCenter, false)
					if selected then
						self.scanController.SelectedDotObject = selected
					end
				end
			end
		end

		local frame = selected and selected.Frame
		if not selected or not frame or not frame.Parent then
			return Enum.ContextActionResult.Pass
		end

		if selected.Callback then
			selected.Callback()
		else
			self:OnSkeletalNodeClick(selected, true)
			self.scanController:TryDiscover()
		end
	end

	return Enum.ContextActionResult.Pass
end

function SkeletonManager:Hold(actionName, inputState, inputObject)
	if not self.scanController.Enabled then
		return Enum.ContextActionResult.Pass
	end

	self.scanController.RightClickHeld = inputState == Enum.UserInputState.Begin
	if self.scanController.RightClickHeld then
		self.scanController.AutoCursorTarget = nil
		self.scanController.CameraAngle.Side = 0
	elseif inputState == Enum.UserInputState.End then
		self.scanController.CameraAngle.Side = -self.scanController.LockedFishSize * Config.FISH_SIDE_OFFSET_MULTIPLIER
	end
	return Enum.ContextActionResult.Pass
end

function SkeletonManager:OnScroll(action, inputState, inputObject)
	if not self.scanController.Enabled then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Change then		
		if self.scanController.SkeletonMode then
			self.scanController.CameraAngle.Z = math.clamp(
				self.scanController.CameraAngle.Z - (inputObject.Position.Z * Config.SCROLL_MULTIPLIER), 
				self.scanController.MinimumDistance, 
				self.scanController.MinimumDistance * Config.ZOOM_MAX_MULTIPLIER
			)
		end
	end
	return Enum.ContextActionResult.Pass
end

function SkeletonManager:ToggleCircle(isActive)
	local cursorManager = self.scanController.CursorManager
	if cursorManager and cursorManager.ToggleScannerCircle then
		cursorManager:ToggleScannerCircle(isActive)
	end
end

function SkeletonManager:ToggleScanView(bool)
	local ScanViewFrame = self.scanController.ScanViewFrame
	if not ScanViewFrame then
		return
	end

	self._scanViewToggleToken = (self._scanViewToggleToken or 0) + 1
	local toggleToken = self._scanViewToggleToken
	local function isCurrent()
		return self._scanViewToggleToken == toggleToken
	end

	local informationFrame = ScanViewFrame.Information
	local navigatorFrame = ScanViewFrame.Navigator
	local mobileControls = navigatorFrame.MobileControls
	local tooltip = navigatorFrame.Tooltip
	self.scanController.NavigatorTooltip = tooltip
	self.scanController.SkeletalGuide:Clean()
	navigatorFrame.Visible = bool
	tooltip.Visible = bool

	if self.scanController.CCM then
		if bool then
			self.scanController:_acquireCameraControl({
				mode = "ScanView",
			})
		else
			self.scanController:_releaseCameraControl()
		end
	end

	local GuiInset = GuiService:GetGuiInset()
	local infoClosedPosition = UDim2.new(0.5, 0, -0.3, GuiInset.Y + 5)
	local infoOpenedPosition = UDim2.new(0.5, 0, 0, GuiInset.Y + 5)

	local navigatorClosedPosition = UDim2.new(0.5, 0, 1.2, 0)
	local navigatorOpenedPosition = UDim2.new(0.5, 0, 0.9, 0)

	local TOOL_TIP_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local toolTipTweenOpen = TweenService:Create(
		tooltip,
		TOOL_TIP_TWEEN,
		{Size = UDim2.fromScale(2, 0.12)}
	)

	local toolTipTweenClose = TweenService:Create(
		tooltip,
		TOOL_TIP_TWEEN,
		{Size = UDim2.fromScale(0.12, 0.12)}
	)

	local FADE_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTooltipIn = TweenService:Create(tooltip, FADE_TWEEN, {TextTransparency = 0})
	local fadeTooltipOut = TweenService:Create(tooltip, FADE_TWEEN, {TextTransparency = 1})
	local fadeMobileIn = TweenService:Create(mobileControls, FADE_TWEEN, {GroupTransparency = 0})
	local fadeMobileOut = TweenService:Create(mobileControls, FADE_TWEEN, {GroupTransparency = 1})

	if bool then
		ScanViewFrame.Visible = true
	end

	if bool then
		mobileControls.Visible = UserInputService.TouchEnabled
		tooltip.Text = Config.DEFAULT_GUIDE_MESSAGE
		navigatorFrame.Visible = true
		tooltip.Visible = true
		tooltip.TextTransparency = 1
		mobileControls.GroupTransparency = 1
		informationFrame.Position = infoClosedPosition
		informationFrame:TweenPosition(infoOpenedPosition, "Out", "Quad", 0.5, true)

		navigatorFrame.Position = navigatorClosedPosition
		navigatorFrame:TweenPosition(navigatorOpenedPosition, "Out", "Quad", 0.3, true)

		toolTipTweenOpen:Play()
		fadeTooltipIn:Play()
		fadeMobileIn:Play()
	else
		tooltip.Text = Config.DEFAULT_GUIDE_MESSAGE
		informationFrame:TweenPosition(infoClosedPosition, "Out", "Quad", 0.5, true)
		fadeTooltipOut:Play()
		fadeMobileOut:Play()
		toolTipTweenClose:Play()
		navigatorFrame:TweenPosition(navigatorClosedPosition, "Out", "Quad", 0.5, true)
		mobileControls.Visible = false
		task.delay(0.5, function()
			if not isCurrent() or bool then
				return
			end
			navigatorFrame.Visible = false
			tooltip.Visible = false
		end)
		task.delay(1, function()
			if not isCurrent() or bool then
				return
			end
			ScanViewFrame.Visible = false
		end)
	end
end

function SkeletonManager:Close(fully)
	if self.scanController.Locked then
		self.scanController:Unlock()
	end

	UserInputService.MouseDeltaSensitivity = 1
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	local cursorManager = self.scanController.CursorManager
	if cursorManager then
		if fully then
			cursorManager:HideScannerCursor(true)
		else
			cursorManager:ShowScannerCursor()
		end
	else
		local scannerCursor = self.scanController.ScannerCursor
		if scannerCursor then
			scannerCursor.Visible = not fully
		end
		UserInputService.MouseIconEnabled = fully
	end

	if self.scanController.SkeletonMode then
		self.scanController.SkeletonMode = false
		self.scanController.TargetLockProgress = 0
		self.scanController.LockedIntoTarget = false
		self.scanController.DiscoveryTriggered = false
		self.scanController.RightClickHeld = false
		self.scanController.MouseDelta = Vector3.zero

		if cursorManager then
			cursorManager:SetSmartCursorVisible(false)
		else
			local smartCursor = self.scanController.SmartCursor
			if smartCursor then
				smartCursor.Visible = false
			end
		end

		self.scanController.SmartCursorLocked = false
		self.scanController.SmartCursorLockedTo = nil
		self.scanController.SmartCursorStickyNode = nil
		self.scanController.AutoCursorTarget = nil

		self.scanController.SkeletalTracker = {}
		self.scanController.SkeletonConnectionLine = nil
		self.scanController.SelectedSkeletalNode = nil
		self.scanController.SkeletalTrove:Clean()
		self.scanController.SkeletalGuide:Clean()

		if self.scanController.NavigatorTooltip then
			self.scanController.NavigatorTooltip.Text = Config.DEFAULT_GUIDE_MESSAGE
		end

		if not self.CameraReturnInProgress then
			self.CameraReturnInProgress = true
			task.spawn(function()
				local CurrentCamera = workspace.CurrentCamera
				CurrentCamera.CameraSubject = self.scanController.Humanoid
				CurrentCamera.CameraType = Enum.CameraType.Custom

				self.scanController.Humanoid.WalkSpeed = self.scanController.OriginalSpeed
				if self.scanController.CCM then
					self.scanController:_releaseCameraControl()
				end
				self.CameraReturnInProgress = false
			end)
		end
	end

	GuiService.TouchControlsEnabled = true
end

function SkeletonManager:ExitSkeletonMode()
	if not self.scanController.SkeletonMode then
		return
	end

	self.scanController.RightClickHeld = false
	self.scanController.MouseDelta = Vector3.zero

	if self.scanController.Locked then
		self.scanController:Unlock()
	end

	self.scanController.SkeletonMode = false
	self.scanController.TargetLockProgress = 0
	self.scanController.LockedIntoTarget = false
	self.scanController.DiscoveryTriggered = false

	local cursorManager = self.scanController.CursorManager
	if cursorManager then
		cursorManager:SetSmartCursorVisible(false)
		cursorManager:ShowScannerCursor()
	else
		local smartCursor = self.scanController.SmartCursor
		if smartCursor then
			smartCursor.Visible = false
		end

		local scannerCursor = self.scanController.ScannerCursor
		if scannerCursor then
			scannerCursor.Visible = true
		end
	end

	self.scanController.SmartCursorLocked = false
	self.scanController.SmartCursorLockedTo = nil
	self.scanController.SmartCursorStickyNode = nil
	self.scanController.AutoCursorTarget = nil

	self.scanController.SkeletalTracker = {}
	self.scanController.SkeletonConnectionLine = nil
	self.scanController.SelectedSkeletalNode = nil
	if self.scanController.SkeletalTrove then
		self.scanController.SkeletalTrove:Clean()
	end

	if self.scanController.SkeletalGuide then
		self.scanController.SkeletalGuide:Clean()
	end

	if self.scanController.NavigatorTooltip then
		self.scanController.NavigatorTooltip.Text = Config.DEFAULT_GUIDE_MESSAGE
	end

	GuiService.TouchControlsEnabled = true

	if self.scanController.CCM then
		self.scanController:_releaseCameraControl()
	end

	if not self.CameraReturnInProgress then
		self.CameraReturnInProgress = true
		task.spawn(function()
			local CurrentCamera = workspace.CurrentCamera
			CurrentCamera.CameraSubject = self.scanController.Humanoid
			CurrentCamera.CameraType = Enum.CameraType.Custom

			local scanController = self.scanController

			if scanController.Locked or scanController.SkeletonMode then
				self.CameraReturnInProgress = false
				return
			end

			self.scanController.Humanoid.WalkSpeed = self.scanController.OriginalSpeed
			self.CameraReturnInProgress = false
		end)
	end
end

function SkeletonManager:Update(mouseLocation, deltaTime)
	if not self.scanController.Enabled then
		return
	end

	local isRightDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	if isRightDown ~= self.scanController.RightClickHeld then
		self.scanController.RightClickHeld = isRightDown
		if isRightDown then
			self.scanController.AutoCursorTarget = nil
			self.scanController.CameraAngle.Side = 0
		else
			self.scanController.CameraAngle.Side = -self.scanController.LockedFishSize * Config.FISH_SIDE_OFFSET_MULTIPLIER
		end
	end

	CurrentCamera = workspace.CurrentCamera or CurrentCamera

	local lockedTo = self.scanController.LockedTo
	if not lockedTo then
		self:ExitSkeletonMode()
		return
	end

	if not self.scanController.Locked or not lockedTo:IsDescendantOf(workspace) then
		self:ExitSkeletonMode()
		return
	end

	local primaryPart
	local pivotCFrame

	if lockedTo:IsA("BasePart") then
		primaryPart = lockedTo
		pivotCFrame = lockedTo.CFrame
	else
		primaryPart = lockedTo.PrimaryPart
		if primaryPart then
			pivotCFrame = primaryPart.CFrame
		else
			pivotCFrame = lockedTo:GetPivot()
		end
	end

	local modelCFrame = pivotCFrame
	local defaultSize = 14 
	local smartCursor = self.scanController.SmartCursor

	for index, node in self.scanController.SkeletalTracker do
		if node.Type == "Dot" then
			local styleName = node.CurrentStyle or (node.AllConnected and "Completed" or "Default")
			local style = Config.NODE_STYLES[styleName] or Config.NODE_STYLES.Default
			local colorOfDot = style.Background or node.Frame.BackgroundColor3
			local translatedPosition =  (modelCFrame * CFrame.new(node.Position)).Position
			local screenPoint = CurrentCamera:WorldToViewportPoint(translatedPosition)
			local screenPoint2dVector = Vector2.new(screenPoint.X, screenPoint.Y)
			local distance = (screenPoint2dVector - smartCursor.AbsolutePosition).Magnitude / 20
			local sizeFactor = math.max((defaultSize * 0.4) - (distance * 0.3), 0)

			node.Frame.Position = UDim2.fromOffset(screenPoint.X, screenPoint.Y)

			local pulseSize = 0
			if (styleName == "Connectable" or styleName == "Recommendation") and node ~= self.scanController.SelectedSkeletalNode then
				pulseSize = math.sin(os.clock() * 3) * 1.5
			end

			node.Frame.Size = UDim2.fromOffset(defaultSize + sizeFactor + pulseSize, defaultSize + sizeFactor + pulseSize)
			node.Frame.BackgroundColor3 = node.Frame.BackgroundColor3:Lerp(colorOfDot, math.min(deltaTime * 30, 1))
		elseif node.Type == "Line" then
			local point1, point2 = node.Points[1], node.Points[2]
			local cursorPosition = Vector2.new(smartCursor.Position.X.Offset, smartCursor.Position.Y.Offset)
			local touchPosition = UserInputService:GetMouseLocation()
			local finalPosition = UserInputService.TouchEnabled and touchPosition or cursorPosition

			local startPoint = Vector2.new(point1.Position.X.Offset, point1.Position.Y.Offset)
			local endPoint = point2 and Vector2.new(point2.Position.X.Offset, point2.Position.Y.Offset) or finalPosition

			local line = node.Frame
			local delta = endPoint - startPoint
			local length = delta.Magnitude
			local angle = math.deg(math.atan2(delta.Y, delta.X))

			local midpoint = (startPoint + endPoint) / 2

			line.Position = UDim2.fromOffset(midpoint.X, midpoint.Y)
			line.Size = UDim2.new(0, length, 0, line.Size.Y.Offset)
			line.Rotation = angle
		end
	end

	local targetPrimaryPart = primaryPart

	local isRightPressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

	if self.scanController.RightClickHeld ~= isRightPressed then
		self.scanController.RightClickHeld = isRightPressed

		if isRightPressed then
			self.scanController.AutoCursorTarget = nil
			self.scanController.CameraAngle.Side = 0
		else
			self.scanController.CameraAngle.Side = -self.scanController.LockedFishSize * Config.FISH_SIDE_OFFSET_MULTIPLIER
		end
	end

	local canOrbit = self.scanController.RightClickHeld or UserInputService.TouchEnabled

	if canOrbit then
		self.scanController.CameraAngle.Y = math.clamp(
			self.scanController.CameraAngle.Y - self.scanController.MouseDelta.Y * 0.3,
			-80, 80
		)

		self.scanController.CameraAngle.X -= self.scanController.MouseDelta.X * 0.3
	end

	self.scanController.CameraAngle.Z = math.lerp(
		self.scanController.CameraAngle.Z,
		self.scanController.CameraAngle.Zt,
		deltaTime * 5
	)

	local targetPosition = pivotCFrame.Position

	local rotation = CFrame.new(targetPosition) 
		* CFrame.Angles(0, math.rad(self.scanController.CameraAngle.X), 0)
		* CFrame.Angles(math.rad(self.scanController.CameraAngle.Y), 0, 0)

	local offset = rotation.LookVector * -self.scanController.CameraAngle.Z
	local sideVector = rotation.RightVector
	local sideOffset = sideVector * self.scanController.CameraAngle.Side
	local newCameraPosition = targetPosition + offset + sideOffset
	local targetCF = CFrame.lookAt(newCameraPosition, targetPosition)

	if self.popperCam and self.popperZoom and self.popperZoom.SetZoomParameters then
		local distance = (newCameraPosition - targetPosition).Magnitude
		self.popperZoom.SetZoomParameters(distance, 0)
		local desiredFocus = CFrame.new(targetPosition)
		local poppedCF = self.popperCam:Update(deltaTime, targetCF, desiredFocus)
		if typeof(poppedCF) == "CFrame" then
			targetCF = poppedCF
		elseif type(poppedCF) == "table" and poppedCF[1] and typeof(poppedCF[1]) == "CFrame" then
			targetCF = poppedCF[1]
		end
	end

	if not self.scanController.LockedIntoTarget then
		self.scanController.TargetLockProgress = math.clamp(self.scanController.TargetLockProgress + deltaTime * 2.5, 0, 1)
		local blend = math.clamp(deltaTime * 6, 0, 1)
		CurrentCamera.CFrame = CurrentCamera.CFrame:Lerp(targetCF, math.max(blend, self.scanController.TargetLockProgress * 0.35))

		if self.scanController.TargetLockProgress >= 0.95 then
			self.scanController.LockedIntoTarget = true
			if targetPrimaryPart then
				CurrentCamera.CameraSubject = targetPrimaryPart
			end
		end
	elseif targetPrimaryPart and CurrentCamera.CameraSubject == targetPrimaryPart then
		local blend = math.clamp(deltaTime * 2, 0, 1)
		CurrentCamera.CFrame = CurrentCamera.CFrame:Lerp(targetCF, blend)
	else
		local blend = math.clamp(deltaTime * 2, 0, 1)
		CurrentCamera.CFrame = CurrentCamera.CFrame:Lerp(targetCF, blend)
	end
end

function SkeletonManager:IsScanComplete()
	for _, dot in self.scanController.SkeletalTracker do
		if dot.Type == "Dot" and not dot.AllConnected then
			return false, dot
		end
	end
	return true
end

function SkeletonManager:RefreshNodeCompletionStates()
	local tracker = self.scanController and self.scanController.SkeletalTracker
	if not tracker then
		return
	end

	for _, node in tracker do
		if node.Type == "Dot" then
			local completed = getConnectinStatus(node, tracker)
			node.AllConnected = completed

			if node ~= self.scanController.SelectedSkeletalNode then
				local currentStyle = node.CurrentStyle or "Default"
				if completed and (currentStyle == "Default" or currentStyle == nil) then
					self:ApplyNodeStyle(node, "Completed")
				elseif not completed and currentStyle == "Completed" then
					self:ApplyNodeStyle(node, "Default")
				end
			end
		end
	end
end

function SkeletonManager:CreateSkeletalMap(model, map)
	self.scanController.SkeletalTracker = {}
	self.scanController.SkeletalTrove:Clean()
	self.scanController.SkeletalGuide:Clean()
	self:UpdateSkeletalGuidance({}, nil, nil, nil)

	local SkeletalMap = self.scanController.SkeletalMap

	for index, node in map do
		local nodeFrame = UIFactory.createTextButton(SkeletalMap.On, {
			Text = "",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Name = index,
			BackgroundColor3 = UIColors.Button,
			BackgroundTransparency = 0.1,
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ZIndex = 3,
			AutoButtonColor = false
		}, {
			Corner = {CornerRadius = UDim.new(1, 0)},
			Stroke = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 3,
				Color = UIColors.Stroke
			}
		})

		local nodeStroke = nodeFrame:FindFirstChildOfClass("UIStroke")
		self.scanController.SkeletalTrove:Add(nodeStroke)

		local glow = UIFactory.createFrame(nodeFrame, {
			Name = "Glow",
			BackgroundColor3 = UIColors.Accent,
			BackgroundTransparency = 0.8,
			Size = UDim2.fromScale(1.4, 1.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = nodeFrame.ZIndex - 1
		}, {
			Corner = {CornerRadius = UDim.new(1, 0)},
			Gradient = {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.3),
					NumberSequenceKeypoint.new(1, 1)
				})
			}
		})

		self.scanController.SkeletalTrove:Add(glow)

		local dotObject = {
			Type = "Dot",
			Id = tostring(index),
			Frame = nodeFrame,
			Position = node.Position,
			Connections = {},
			AllConnected = false,
			Stroke = nodeStroke,
			Links = node.Links,
			CurrentStyle = "Default"
		}
		self:ApplyNodeStyle(dotObject, "Default")

		local clickConnection = nodeFrame.MouseButton1Click:Connect(function()
			self:OnSkeletalNodeClick(dotObject, true)
			self.scanController:TryDiscover()
		end)
		self.scanController.SkeletalTrove:Add(clickConnection)

		table.insert(self.scanController.SkeletalTracker, dotObject)
		self.scanController.SkeletalTrove:Add(nodeFrame)
	end

	self.scanController.SkeletalTrove:Add(function()
		self.scanController.SkeletalTracker = {}
	end)

	self:RefreshNodeCompletionStates()

	if self.scanController.NavigatorTooltip then
		self.scanController.NavigatorTooltip.Text = Config.DEFAULT_GUIDE_MESSAGE
		self.scanController.NavigatorTooltip.TextTransparency = 0
		self.scanController.NavigatorTooltip.Visible = true
	end

	local firstNode = self:GetNextRecommendedNode(nil)
	if firstNode then
		task.delay(0.5, function()
			self:ApplyNodeStyle(firstNode, "Recommendation")
			self.scanController.CursorManager:SnapCursorToNode(firstNode)
			self:UpdateSkeletalGuidance({}, nil, nil, firstNode)
		end)
	end
end

function SkeletonManager:UpdateSkeletalGuidance(connectableDots, currentNode, targetIds, recommendedDot)
	connectableDots = connectableDots or {}
	self.scanController.SkeletalGuide:Clean()

	local tooltip = self.scanController.NavigatorTooltip
	local guideMessage = Config.GUIDE_MESSAGES.Default
	local connectableCount = #connectableDots

	if tooltip then
		if currentNode and connectableCount > 0 and targetIds then
			if connectableCount == 1 then
				guideMessage = Config.GUIDE_MESSAGES.SingleNode
			else
				guideMessage = Config.GUIDE_MESSAGES.MultipleNodes
			end
		elseif recommendedDot then
			guideMessage = Config.GUIDE_MESSAGES.Recommended
		elseif currentNode and currentNode.AllConnected then
			guideMessage = Config.GUIDE_MESSAGES.Progress
		elseif currentNode then
			guideMessage = Config.GUIDE_MESSAGES.Recommended
		end
		tooltip.Text = guideMessage
		tooltip.TextTransparency = 0
		tooltip.Visible = true

		local tooltipParent = tooltip.Parent
		if tooltipParent then
			tooltipParent.Visible = true
		end
	end

	local shouldOnlyPulseRecommendation = recommendedDot ~= nil
	local recommendedIsConnectable = false

	if recommendedDot then
		for _, dotObject in connectableDots do
			if dotObject == currentNode then
				continue
			end
			if dotObject == recommendedDot then
				recommendedIsConnectable = true
				break
			end
		end
	end

	if not shouldOnlyPulseRecommendation or recommendedIsConnectable then
		for _, dotObject in connectableDots do
			if dotObject == currentNode then
				continue
			end
			local button = dotObject.Frame
			if not button or not button.Parent then
				continue
			end

			local outerRing = UIFactory.createFrame(button, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = Config.CONNECTABLE_PULSE.OuterRingStartSize,
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = button.ZIndex + 1
			}, {
				Corner = {CornerRadius = UDim.new(1, 0)},
				Stroke = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = Config.CONNECTABLE_PULSE.OuterStrokeThickness,
					Color = UIColors.ScanNodeConnectableStroke,
					Transparency = 0
				}
			})

			local outerStroke = outerRing:FindFirstChildOfClass("UIStroke")

			local innerStroke = Instance.new("UIStroke")
			innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			innerStroke.Thickness = Config.CONNECTABLE_PULSE.InnerStrokeThickness
			innerStroke.Color = UIColors.ScanNodeConnectable
			innerStroke.Transparency = 0
			innerStroke.Parent = button

			local glowFrame = button:FindFirstChild("Glow")
			if glowFrame then
				glowFrame.BackgroundColor3 = UIColors.ScanNodeConnectable
			end

			local innerPulseTween = TweenService:Create(
				innerStroke,
				Config.PULSE_SINE_TWEEN(Config.CONNECTABLE_PULSE.InnerDuration),
				{Thickness = Config.CONNECTABLE_PULSE.InnerStrokeMaxThickness, Transparency = Config.CONNECTABLE_PULSE.InnerStrokeMinTransparency}
			)

			local outerPulseTween = TweenService:Create(
				outerRing,
				Config.PULSE_SINE_TWEEN(Config.CONNECTABLE_PULSE.OuterDuration),
				{Size = Config.CONNECTABLE_PULSE.OuterRingEndSize}
			)

			local outerFadeTween = TweenService:Create(
				outerStroke,
				Config.PULSE_SINE_TWEEN(Config.CONNECTABLE_PULSE.OuterDuration),
				{Thickness = Config.CONNECTABLE_PULSE.OuterStrokeMinThickness, Transparency = 1}
			)

			local glowPulse
			if glowFrame then
				glowPulse = TweenService:Create(
					glowFrame,
					Config.PULSE_SINE_TWEEN(Config.CONNECTABLE_PULSE.GlowDuration),
					{BackgroundTransparency = 0, Size = Config.CONNECTABLE_PULSE.GlowEndSize}
				)
				glowPulse:Play()
			end

			innerPulseTween:Play()
			outerPulseTween:Play()
			outerFadeTween:Play()

			self.scanController.SkeletalGuide:Add(outerRing)
			self.scanController.SkeletalGuide:Add(innerStroke)
			self.scanController.SkeletalGuide:Add(function()
				innerPulseTween:Cancel()
				outerPulseTween:Cancel()
				outerFadeTween:Cancel()
				if glowPulse then
					glowPulse:Cancel()
				end
			end)
		end
	end

	if recommendedDot and not recommendedIsConnectable then
		local button = recommendedDot.Frame
		if button and button.Parent then
			local megaRing = UIFactory.createFrame(button, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = Config.RECOMMENDATION_PULSE.MegaRingStartSize,
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = button.ZIndex + 2
			}, {
				Corner = {CornerRadius = UDim.new(1, 0)},
				Stroke = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = Config.RECOMMENDATION_PULSE.MegaStrokeThickness,
					Color = UIColors.ScanNodeRecommendationStroke,
					Transparency = 0
				}
			})

			local megaStroke = megaRing:FindFirstChildOfClass("UIStroke")

			local innerStroke = Instance.new("UIStroke")
			innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			innerStroke.Thickness = Config.RECOMMENDATION_PULSE.InnerStrokeThickness
			innerStroke.Color = UIColors.ScanNodeRecommendation
			innerStroke.Transparency = 0
			innerStroke.Parent = button

			local outerStroke = Instance.new("UIStroke")
			outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			outerStroke.Thickness = Config.RECOMMENDATION_PULSE.OuterStrokeThickness
			outerStroke.Color = UIColors.ScanNodeRecommendationStroke
			outerStroke.Transparency = 0
			outerStroke.Parent = button

			local megaTween = TweenService:Create(
				megaRing,
				Config.PULSE_SINE_TWEEN(Config.RECOMMENDATION_PULSE.MegaDuration),
				{Size = Config.RECOMMENDATION_PULSE.MegaRingEndSize}
			)

			local megaFadeTween = TweenService:Create(
				megaStroke,
				Config.PULSE_SINE_TWEEN(Config.RECOMMENDATION_PULSE.MegaDuration),
				{Thickness = Config.RECOMMENDATION_PULSE.MegaStrokeMinThickness, Transparency = 1}
			)

			local innerTween = TweenService:Create(
				innerStroke,
				Config.PULSE_SINE_TWEEN(Config.RECOMMENDATION_PULSE.InnerDuration),
				{Thickness = Config.RECOMMENDATION_PULSE.InnerStrokeMaxThickness, Transparency = Config.RECOMMENDATION_PULSE.InnerStrokeMinTransparency}
			)

			local outerTween = TweenService:Create(
				outerStroke,
				Config.PULSE_SINE_TWEEN(Config.RECOMMENDATION_PULSE.OuterDuration),
				{Thickness = Config.RECOMMENDATION_PULSE.OuterStrokeMaxThickness, Transparency = Config.RECOMMENDATION_PULSE.OuterStrokeMaxTransparency}
			)

			megaTween:Play()
			megaFadeTween:Play()
			innerTween:Play()
			outerTween:Play()

			local glowFrame = button:FindFirstChild("Glow")
			if glowFrame then
				glowFrame.BackgroundColor3 = UIColors.ScanNodeRecommendation
				local glowPulse = TweenService:Create(
					glowFrame,
					Config.PULSE_SINE_TWEEN(Config.RECOMMENDATION_PULSE.GlowDuration),
					{BackgroundTransparency = 0, Size = Config.RECOMMENDATION_PULSE.GlowEndSize}
				)
				glowPulse:Play()
				self.scanController.SkeletalGuide:Add(function()
					glowPulse:Cancel()
				end)
			end

			self.scanController.SkeletalGuide:Add(megaRing)
			self.scanController.SkeletalGuide:Add(innerStroke)
			self.scanController.SkeletalGuide:Add(outerStroke)
			self.scanController.SkeletalGuide:Add(function()
				megaTween:Cancel()
				megaFadeTween:Cancel()
				innerTween:Cancel()
				outerTween:Cancel()
			end)
		end
	end

	local primaryTarget = self.scanController.AutoCursorTarget or recommendedDot or connectableDots[1]
	if primaryTarget and primaryTarget.Type == "Dot" then
		local label = "NEXT"
		if primaryTarget == recommendedDot and (not recommendedIsConnectable or connectableCount == 0) then
			label = "START"
		elseif connectableCount == 1 then
			label = "CONNECT"
		elseif connectableCount > 1 and primaryTarget ~= recommendedDot then
			label = "PICK"
		end

		createNextIndicator(self, primaryTarget, label)
	end
end

function SkeletonManager:OnSkeletalNodeClick(node, fromUserInput, skipAutoSnap)
	if not self.scanController.Enabled then
		return
	end

	if not node or not node.Frame or not node.Frame.Parent then
		return
	end

	local shouldSkipAutoSnap = (skipAutoSnap == true) or (fromUserInput == true)

	if fromUserInput then
		local now = os.clock()
		local last = self.scanController.LastSkeletonClick or 0
		if now - last < Config.SKELETON_CLICK_COOLDOWN then
			return
		end
		self.scanController.LastSkeletonClick = now
		local effectsManager = self.scanController.EffectsManager
		if effectsManager and effectsManager.PlaySkeletonNodeClickEffect then
			effectsManager:PlaySkeletonNodeClickEffect(node)
		end
	end

	local SkeletalMap = self.scanController.SkeletalMap
	if not SkeletalMap then
		return
	end

	local isConnectable = tableFind(self.scanController.SmartCursorAllowList, node.Frame)
	if node.AllConnected and not isConnectable then
		local tooltip = self.scanController.NavigatorTooltip
		if tooltip then
			tooltip.Text = "This node is already complete. Try clicking another one."
			tooltip.TextTransparency = 0
			tooltip.Visible = true
		end

		local nextNode = self:GetNextRecommendedNode(node)
		self.scanController.SelectedSkeletalNode = nil
		self:DefaultHighlightStatus(true)
		if nextNode then
			self:ApplyNodeStyle(nextNode, "Recommendation")
			local cursorManager = self.scanController.CursorManager
			if cursorManager and cursorManager.SnapCursorToNode and not shouldSkipAutoSnap then
				cursorManager:SnapCursorToNode(nextNode)
			end
			self:UpdateSkeletalGuidance({}, nil, nil, nextNode)
		end
		return
	end

	local lineData = self.scanController.SkeletonConnectionLine

	if lineData then
		local startNode = self.scanController.SelectedSkeletalNode
		if startNode then
			local allowedConnections = startNode.Links

			if not tableFind(allowedConnections, node.Id) or startNode == node or tableFind(startNode.Connections, node.Id) then
				for index, linkObject in self.scanController.SkeletalTracker do
					if linkObject.Frame == lineData.Frame then
						table.remove(self.scanController.SkeletalTracker, index)
						if lineData.Frame then
							lineData.Frame:Destroy()
						end
						break
					end
				end

				self.scanController.SkeletonConnectionLine = nil
				self:DefaultHighlightStatus()
				return
			else
				if lineData.Frame and lineData.Frame.Parent then
					lineData.Frame.Parent = SkeletalMap.Off
				end
				table.insert(lineData.Points, node.Frame)
				table.insert(node.Connections, startNode.Id)
				table.insert(startNode.Connections, node.Id)

				local effectsManager = self.scanController.EffectsManager
				if effectsManager and effectsManager.PlayConnectionEffect then
					effectsManager:PlayConnectionEffect(startNode, node)
				end

				local nodeWasComplete = node.AllConnected
				local startWasComplete = startNode.AllConnected
				local tracker = self.scanController.SkeletalTracker

				node.AllConnected = getConnectinStatus(node, tracker)
				startNode.AllConnected = getConnectinStatus(startNode, tracker)

				if not nodeWasComplete and node.AllConnected then
					self:PlayNodeCompletionEffect(node)
				end

				if not startWasComplete and startNode.AllConnected then
					self:PlayNodeCompletionEffect(startNode)
				end

				self.scanController.SkeletonConnectionLine = nil

				local followUpNode
				if hasOpenConnections(node, tracker) then
					followUpNode = node
				elseif hasOpenConnections(startNode, tracker) then
					followUpNode = startNode
				end

				self.scanController.SelectedSkeletalNode = nil
				self:UnhighlightSkeletalNodes({}, true)

				if followUpNode then
					self:OnSkeletalNodeClick(followUpNode, false, true)
					return
				end

				self:DefaultHighlightStatus(true)
				local nextNode = self:GetNextRecommendedNode(node)

				if nextNode then
					self:ApplyNodeStyle(nextNode, "Recommendation")
					self:UpdateSkeletalGuidance({}, nil, nil, nextNode)
				else
					self:UpdateSkeletalGuidance({}, nil, nil, nil)
				end

				return
			end
		end
	end

	local highlights = table.clone(node.Links)
	table.insert(highlights, node.Id)

	for _, linkObject in self.scanController.SkeletalTracker do
		if linkObject.Type == "Dot" and (linkObject.AllConnected or tableFind(node.Connections, linkObject.Id)) then
			local inHighlights, index = tableFind(highlights, linkObject.Id)

			if inHighlights then
				table.remove(highlights, index)
			end
		end
	end

	if self.scanController.SelectedSkeletalNode ~= node then
		self:UnhighlightSkeletalNodes(highlights)
	end

	self.scanController.SelectedSkeletalNode = node
	self:HighlightSkeletalNodes(highlights, {skipAutoSnap = shouldSkipAutoSnap})
	self:StartSkeletalConnection(node)
end

return SkeletonManager
