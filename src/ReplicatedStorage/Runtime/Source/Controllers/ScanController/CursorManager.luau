local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local CurrentCamera = workspace.CurrentCamera
local Config = require(script.Parent.Config)

local function toVector2(position)
	if not position then
		return nil
	end

	local positionType = typeof(position)
	if positionType == "Vector2" then
		return position
	elseif positionType == "Vector3" then
		return Vector2.new(position.X, position.Y)
	end

	return nil
end

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

local function getCursorHitRadius(frame)
	local size = frame.AbsoluteSize
	local radius = math.max(size.X, size.Y) * 0.5
	return math.max(radius, Config.MIN_CURSOR_HIT_RADIUS)
end

local function findDotByFrame(scanController, targetFrame)
	if not scanController or not targetFrame then
		return nil
	end

	for _, node in scanController.SkeletalTracker do
		if node.Type == "Dot" and node.Frame == targetFrame then
			return node
		end
	end

	return nil
end

local CursorManager = {}
CursorManager.__index = CursorManager

function CursorManager.new(scanController)
	local self = setmetatable({}, CursorManager)
	self.scanController = scanController
	return self
end

function CursorManager:ResetCursorTargets()
	self.scanController.SmartCursorAllowList = {}
	self.scanController.CurrentConnectableFrames = {}
	self.scanController.AutoCursorTarget = nil
	self.scanController.SmartCursorLocked = false
	self.scanController.SmartCursorLockedTo = nil
	self.scanController.SmartCursorStickyNode = nil
	self.scanController.LastSelection = nil
end

function CursorManager:RegisterInteractable(button, callback)
	if not (button and callback) then
		return
	end

	if not button:IsA("GuiButton") then
		if button.Activated then
			button.Activated:Connect(callback)
		end
		return
	end

	self.scanController.SmartCursorInteractables[button] = callback

	button.MouseButton1Click:Connect(callback)

	button.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			self:RemoveInteractable(button)
		end
	end)
end

function CursorManager:RemoveInteractable(button)
	if not button then
		return
	end

	self.scanController.SmartCursorInteractables[button] = nil

	if self.scanController.LastSelection == button then
		self.scanController.LastSelection = nil
	end

	if self.scanController.SmartCursorLockedTo == button then
		self.scanController.SmartCursorLocked = false
		self.scanController.SmartCursorLockedTo = nil
	end
end

function CursorManager:ShowScannerCursor()
	local cursor = self.scanController.ScannerCursor
	if cursor then
		cursor.Visible = true
	end
	UserInputService.MouseIconEnabled = false
end

function CursorManager:HideScannerCursor(showSystemCursor)
	local cursor = self.scanController.ScannerCursor
	if cursor then
		cursor.Visible = false
	end
	if showSystemCursor then
		UserInputService.MouseIconEnabled = true
	end
end

function CursorManager:SetSmartCursorVisible(isVisible)
	local smartCursor = self.scanController.SmartCursor
	if smartCursor then
		smartCursor.Visible = isVisible
	end
end

function CursorManager:SetSmartCursorPosition(position)
	local smartCursor = self.scanController.SmartCursor
	if smartCursor and position then
		smartCursor.Position = position
	end
end

function CursorManager:SetScannerCursorPosition(position)
	local cursor = self.scanController.ScannerCursor
	if not (cursor and position) then
		return
	end

	local position2d = toVector2(position)
	if not position2d then
		return
	end

	cursor.Position = UDim2.fromOffset(position2d.X, position2d.Y)
end

function CursorManager:CenterSmartCursor()
	local camera = workspace.CurrentCamera or CurrentCamera
	if not camera then
		return
	end

	self:SetSmartCursorPosition(UDim2.fromOffset(
		camera.ViewportSize.X * 0.5,
		camera.ViewportSize.Y * 0.5
		))
end

function CursorManager:CenterScannerCursor()
	local camera = workspace.CurrentCamera or CurrentCamera
	if not camera then
		return
	end

	self:SetScannerCursorPosition(Vector2.new(
		camera.ViewportSize.X * 0.5,
		camera.ViewportSize.Y * 0.5
		))
end

function CursorManager:GetScannerCursor()
	return self.scanController.ScannerCursor
end

function CursorManager:GetSmartCursor()
	return self.scanController.SmartCursor
end

function CursorManager:ResetScannerCursorSize()
	local cursor = self.scanController.ScannerCursor
	if not cursor then
		return
	end

	local defaultSize = self.scanController.CursorSize or cursor.Size.Y.Offset
	cursor.Size = UDim2.fromOffset(defaultSize, defaultSize)

	local stroke = cursor:FindFirstChildOfClass("UIStroke")
	if stroke then
		local defaultBgTransparency = cursor:GetAttribute("DefaultBackgroundTransparency") or 1
		local defaultStrokeThickness = stroke:GetAttribute("DefaultThickness") or 3
		local defaultStrokeTransparency = stroke:GetAttribute("DefaultTransparency") or 0

		cursor.BackgroundTransparency = defaultBgTransparency
		stroke.Thickness = defaultStrokeThickness
		stroke.Transparency = defaultStrokeTransparency
	end
end

function CursorManager:ResetSmartCursorAppearance()
	local smartCursor = self.scanController.SmartCursor
	if not smartCursor then
		return
	end

	local defaultBgTransparency = smartCursor:GetAttribute("DefaultBackgroundTransparency")
	if defaultBgTransparency == nil then
		smartCursor:SetAttribute("DefaultBackgroundTransparency", smartCursor.BackgroundTransparency)
		defaultBgTransparency = smartCursor.BackgroundTransparency
	end
	smartCursor.BackgroundTransparency = defaultBgTransparency

	local gradient = smartCursor:FindFirstChildOfClass("UIGradient")
	if gradient then
		local defaultGradientTransparency = gradient:GetAttribute("DefaultTransparency")
		if defaultGradientTransparency == nil then
			gradient:SetAttribute("DefaultTransparency", gradient.Transparency)
			defaultGradientTransparency = gradient.Transparency
		end
		gradient.Transparency = defaultGradientTransparency
	end
end

function CursorManager:ToggleScannerCircle(isActive)
	local cursor = self.scanController.ScannerCursor
	if not cursor then
		return
	end

	local stroke = cursor:FindFirstChild("UIStroke")
	if not stroke or not stroke:IsA("UIStroke") then
		stroke = cursor:FindFirstChildOfClass("UIStroke")
	end

	if not stroke then
		return
	end

	local defaultBgTransparency = cursor:GetAttribute("DefaultBackgroundTransparency")
	if defaultBgTransparency == nil then
		defaultBgTransparency = cursor.BackgroundTransparency
		cursor:SetAttribute("DefaultBackgroundTransparency", defaultBgTransparency)
	end

	local defaultStrokeThickness = stroke:GetAttribute("DefaultThickness")
	if defaultStrokeThickness == nil then
		defaultStrokeThickness = stroke.Thickness
		stroke:SetAttribute("DefaultThickness", defaultStrokeThickness)
	end

	local defaultStrokeTransparency = stroke:GetAttribute("DefaultTransparency")
	if defaultStrokeTransparency == nil then
		defaultStrokeTransparency = stroke.Transparency
		stroke:SetAttribute("DefaultTransparency", defaultStrokeTransparency)
	end

	if isActive then
		cursor.BackgroundTransparency = 0
		stroke.Transparency = 1
		stroke.Thickness = 4
	else
		cursor.BackgroundTransparency = defaultBgTransparency
		stroke.Transparency = defaultStrokeTransparency
		stroke.Thickness = defaultStrokeThickness
	end
end

function CursorManager:UpdateScannerCursor(mouseLocation, deltaTime)
	if not self.scanController.Enabled then
		return
	end

	local scannerCursor = self.scanController.ScannerCursor
	if not scannerCursor then
		return
	end

	if not self.scanController.TargetManager then
		return
	end

	CurrentCamera = workspace.CurrentCamera or CurrentCamera

	local locked = self.scanController.Locked
	local lockedTo = self.scanController.LockedTo
	local lastScan = self.scanController.LastScan
	local mouseHeld = self.scanController.MouseHeld
	local skeletonMode = self.scanController.SkeletonMode
	local finalPosition = toVector2(mouseLocation)
	if not finalPosition and scannerCursor then
		finalPosition = Vector2.new(scannerCursor.Position.X.Offset, scannerCursor.Position.Y.Offset)
	end
	if not finalPosition then
		return
	end
	local shouldUnlock = false
	local lockTarget
	local mouseDeltaMagnitude = UserInputService:GetMouseDelta().Magnitude
	local cursorSize = self.scanController.CursorSize or scannerCursor.Size.Y.Offset
	local cursorRadius = Config.MIN_CURSOR_HIT_RADIUS
	local mouseBehavior = UserInputService.MouseBehavior
	if mouseBehavior == Enum.MouseBehavior.LockCurrentPosition or mouseBehavior == Enum.MouseBehavior.LockCenter then
		local currentPos = scannerCursor.Position
		if self.scanController.RightClickHeld or (not mouseHeld and not skeletonMode) then
			finalPosition = Vector2.new(currentPos.X.Offset, currentPos.Y.Offset)
		else
			local viewport = CurrentCamera.ViewportSize
			local delta = UserInputService:GetMouseDelta()
			local newX = math.clamp(currentPos.X.Offset + delta.X, 0, viewport.X)
			local newY = math.clamp(currentPos.Y.Offset + delta.Y, 0, viewport.Y)
			finalPosition = Vector2.new(newX, newY)
		end
	end

	local absoluteSize = scannerCursor.AbsoluteSize
	if absoluteSize then
		cursorRadius = math.max(absoluteSize.X, absoluteSize.Y) * 0.35 + Config.SCAN_HITBOX_MODIFIER * 0.8
	elseif scannerCursor.Size then
		cursorRadius = math.max(scannerCursor.Size.X.Offset or 0, scannerCursor.Size.Y.Offset or 0) * 0.35 + Config.SCAN_HITBOX_MODIFIER * 0.8
	end

	cursorRadius = math.max(cursorRadius or Config.MIN_CURSOR_HIT_RADIUS, Config.MIN_CURSOR_HIT_RADIUS * 0.9)

	if locked and not skeletonMode and lockedTo then
		if self.scanController.SetHighlight then
			self.scanController:SetHighlight(nil)
		end
		self.scanController.CheckNoTargetOnRelease = false
		local target = lockedTo:IsA("BasePart") and lockedTo or lockedTo.PrimaryPart
		if target then
			local vector = CurrentCamera:WorldToViewportPoint(target.CFrame.Position)
			finalPosition = Vector2.new(vector.X, vector.Y)
		end

		local lastScanDelta = os.clock() - lastScan
		self.scanController.MouseUnlockScore = math.max(self.scanController.MouseUnlockScore - deltaTime * Config.MOUSE_UNLOCK_DECREASE_RATE, 0)
		self.scanController.MouseUnlockScore = math.min(self.scanController.MouseUnlockScore + mouseDeltaMagnitude * deltaTime, Config.MOUSE_UNLOCK_INCREASE_LIMIT)

		if (mouseDeltaMagnitude >= Config.MOUSE_SPEED_THRESHOLD or self.scanController.MouseUnlockScore >= Config.MOUSE_UNLOCK_THRESHOLD)
			and lastScanDelta > Config.SCAN_INTERVAL_THRESHOLD then
			shouldUnlock = true
		end
	else
		self.scanController.MouseUnlockScore = 0
		local availableTarget
		if not skeletonMode and not self.scanController.RightClickHeld then
			availableTarget = self.scanController.TargetManager:FindNearestScannable(finalPosition, scannerCursor)
			if availableTarget and self.scanController.SetHighlight then
				self.scanController:SetHighlight(availableTarget.Instance)
			elseif self.scanController.SetHighlight then
				self.scanController:SetHighlight(nil)
			end
		end

		local lockRequested = self.scanController.LockRequested
		if not locked and not skeletonMode and (mouseHeld or lockRequested) and not self.scanController.RightClickHeld then
			if availableTarget then
				local lastScanDelta = os.clock() - lastScan
				if lastScanDelta > Config.LAST_SCAN_LOCK_THRESHOLD then
					lockTarget = availableTarget
				end
			end

			if lockTarget then
				local withinCursorRadius = false

				if lockTarget == availableTarget then
					withinCursorRadius = true
				else
					local position2d = lockTarget.Position
					if position2d then
						withinCursorRadius = (position2d - finalPosition).Magnitude <= cursorRadius
					end

					if lockTarget.Distance and lockTarget.Distance <= Config.ACTIVATION_DISTANCE + (lockTarget.Radius or 0) then
						withinCursorRadius = true
					end
				end

				if not withinCursorRadius then
					lockTarget = nil
					self.scanController.CheckNoTargetOnRelease = true
				else
					self.scanController.CheckNoTargetOnRelease = false
				end
			elseif mouseHeld or lockRequested then
				self.scanController.CheckNoTargetOnRelease = true
			else
				self.scanController.CheckNoTargetOnRelease = false
			end
		else
			if not mouseHeld and not lockRequested then
				self.scanController.CheckNoTargetOnRelease = false
			end
		end
	end

	local sizeOffset = cursorSize * (locked and mouseDeltaMagnitude or 0)
	local newSize = math.max(cursorSize - sizeOffset, 0) * (mouseHeld and 0.5 or 1)
	self.scanController.CursorSpeed = math.clamp(
		self.scanController.CursorSpeed + (mouseHeld and 1 or -1) * deltaTime,
		0,
		1
	)

	local lerpAlpha = math.min(deltaTime * Config.CURSOR_LERP_SPEED, 1)
	if UserInputService.TouchEnabled then lerpAlpha = 1	end

	scannerCursor.Position = scannerCursor.Position:Lerp(
		UDim2.fromOffset(finalPosition.X, finalPosition.Y),
		lerpAlpha
	)

	local uiStroke = scannerCursor:FindFirstChild("UIStroke")
	if not uiStroke or not uiStroke:IsA("UIStroke") then
		uiStroke = scannerCursor:FindFirstChildOfClass("UIStroke")
	end

	if uiStroke then
		local uiGradient = uiStroke:FindFirstChildOfClass("UIGradient") or uiStroke:FindFirstChild("UIGradient")
		if uiGradient then
			uiGradient.Rotation = math.lerp(uiGradient.Rotation, uiGradient.Rotation + (self.scanController.CursorSpeed * 60), deltaTime * Config.UIGRADIENT_LERP_SPEED)
		end
	end

	scannerCursor.Size = scannerCursor.Size:Lerp(UDim2.fromOffset(newSize, newSize), deltaTime * Config.CURSOR_SIZE_LERP)
	if self.scanController.LockRequested then
		self.scanController.LockRequested = false
	end
	if shouldUnlock then return "Unlock" elseif lockTarget then	return "Lock", lockTarget end
end

function CursorManager:SnapCursorToNode(nodeObject, smartCursor, guiInset)
	if UserInputService.TouchEnabled then return end

	if not nodeObject or nodeObject.Type ~= "Dot" then
		return
	end

	local frame = nodeObject.Frame
	if not frame or not frame.Parent then
		return
	end

	if self.scanController.AutoCursorTarget == nodeObject then
		return
	end

	if #self.scanController.SmartCursorAllowList > 0 and not tableFind(self.scanController.SmartCursorAllowList, frame) then
		table.insert(self.scanController.SmartCursorAllowList, frame)
	end

	self.scanController.SmartCursorLocked = false
	self.scanController.SmartCursorLockedTo = nil
	self.scanController.SelectedDotObject = nodeObject
	self.scanController.AutoCursorTarget = nodeObject

	self.scanController.LastSelection = nil
	self.scanController.SmartCursorLastLock = os.clock()

	smartCursor = smartCursor or self:GetSmartCursor()
	if not smartCursor then	return end

	guiInset = guiInset or GuiService:GetGuiInset()

	smartCursor.Position = UDim2.fromOffset(
		frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2,
		frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2 + guiInset.Y
	)
end

function CursorManager:Update(deltaTime, SmartCursor)
	if not self.scanController.Enabled then
		return
	end

	SmartCursor = SmartCursor or self.scanController.SmartCursor
	if not SmartCursor then
		return
	end

	CurrentCamera = workspace.CurrentCamera or CurrentCamera

	local delta = self.scanController.RightClickHeld and Vector3.zero or self.scanController.MouseDelta
	local viewportBounds = Vector2.new(
		CurrentCamera.ViewportSize.X,
		CurrentCamera.ViewportSize.Y
	)

	local LockedTo = self.scanController.SmartCursorLockedTo
	local newSize = math.max(LockedTo and LockedTo.AbsoluteSize and LockedTo.AbsoluteSize.X or 20, 0) * (self.scanController.MouseHeld and 0.5 or 1)
	local cursorPosition = SmartCursor.Position
	local newX = cursorPosition.X.Offset + delta.X
	local newY = cursorPosition.Y.Offset + delta.Y
	local newPosition
	local guiInset = GuiService:GetGuiInset()
	local stickyNode = self.scanController.SmartCursorStickyNode
	local releaseThreshold = math.max((Config.SKELETON_STICK_DISTANCE or 48) * 0.35, 8)

	SmartCursor.Size = SmartCursor.Size:Lerp(UDim2.fromOffset(newSize, newSize), math.min(deltaTime * Config.CURSOR_UPDATE_SPEED, 1))
	local clampedPosition = Vector2.new(math.clamp(newX, 0, viewportBounds.X),math.clamp(newY, 0, viewportBounds.Y))

	if stickyNode then
		local frame = stickyNode.Frame
		if frame and frame.Parent then
			local center = Vector2.new(
				frame.AbsolutePosition.X + frame.AbsoluteSize.X * 0.5,
				frame.AbsolutePosition.Y + frame.AbsoluteSize.Y * 0.5 + guiInset.Y
			)

			if (clampedPosition - center).Magnitude > releaseThreshold then
				self.scanController.SmartCursorStickyNode = nil
				stickyNode = nil
			else
				newPosition = UDim2.fromOffset(center.X, center.Y)
			end
		else
			self.scanController.SmartCursorStickyNode = nil
			stickyNode = nil
		end
	end

	if not newPosition then
		newPosition = UDim2.new(0, clampedPosition.X, 0, clampedPosition.Y)
	end

	if not stickyNode then
		local closestFrame
		local closestDistance = Config.SKELETON_STICK_DISTANCE or 48
		for _, frame in self.scanController.CurrentConnectableFrames do
			if frame and frame.Parent then
				local center = Vector2.new(
					frame.AbsolutePosition.X + frame.AbsoluteSize.X * 0.5,
					frame.AbsolutePosition.Y + frame.AbsoluteSize.Y * 0.5 + guiInset.Y
				)
				local distance = (clampedPosition - center).Magnitude
				if distance <= closestDistance then
					closestDistance = distance
					closestFrame = frame
				end
			end
		end

		if closestFrame then
			local dotObject = findDotByFrame(self.scanController, closestFrame)
			if dotObject then
				self.scanController.SmartCursorStickyNode = dotObject
				self:SnapCursorToNode(dotObject, SmartCursor)
				stickyNode = dotObject
				local frame = dotObject.Frame
				if frame and frame.Parent then
					local center = Vector2.new(
						frame.AbsolutePosition.X + frame.AbsoluteSize.X * 0.5,
						frame.AbsolutePosition.Y + frame.AbsoluteSize.Y * 0.5 + guiInset.Y
					)
					newPosition = UDim2.fromOffset(center.X, center.Y)
				end
			end
		end
	end

	SmartCursor.Position = SmartCursor.Position:Lerp(
		newPosition,
		math.min(deltaTime * Config.CURSOR_LERP_SPEED, 1)
	)

	if not self.scanController.SmartCursorLocked and os.clock() - self.scanController.SmartCursorLastLock > Config.CURSOR_LOCK_THRESHOLD then
		local closestDistance = math.huge
		local closestTarget = nil
		local combinedTable = table.clone(self.scanController.SkeletalTracker)

		for button, callback in self.scanController.SmartCursorInteractables do
			table.insert(combinedTable, {
				Frame = button,
				Callback = callback,
				Type = "Button"
			})
		end

		for _, dot in combinedTable do
			if dot.Type == "Line" then
				continue
			end

			local frame = dot.Frame
			if not frame or not frame.Parent then
				continue
			end

			if dot.Type == "Dot" and dot.AllConnected then
				if #self.scanController.SmartCursorAllowList == 0 or not tableFind(self.scanController.SmartCursorAllowList, dot.Frame) then
					continue
				end
			end

			local hitRadius = getCursorHitRadius(frame)
			local rawDistance = (SmartCursor.AbsolutePosition - frame.AbsolutePosition).Magnitude
			local distance = rawDistance - hitRadius

			if distance < Config.ACTIVATION_DISTANCE and self.scanController.LastSelection ~= frame and distance < closestDistance then
				closestDistance = distance
				closestTarget = dot
			elseif self.scanController.LastSelection == frame and rawDistance > hitRadius + Config.ACTIVATION_DISTANCE * 2 then
				self.scanController.LastSelection = nil
			elseif distance > Config.ACTIVATION_DISTANCE and closestTarget and closestTarget.Frame == frame then
				closestTarget = nil
				closestDistance = math.huge
			end
		end

		if closestTarget then
			if #self.scanController.SmartCursorAllowList > 0 then
				if not tableFind(self.scanController.SmartCursorAllowList, closestTarget.Frame) then
					return
				end
			end

			self.scanController.LastSelection = closestTarget.Frame
			self.scanController.SelectedDotObject = closestTarget
			self.scanController.SmartCursorLastLock = os.clock()
		end
	end
end

return CursorManager
