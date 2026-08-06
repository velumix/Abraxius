local UserInputService = game:GetService("UserInputService")

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
local zero_vector2 = Vector2.new(0, 0)
local TOUCH_CONTROL_SHEET = "rbxasset://textures/ui/TouchControlsSheet.png"

local TouchThumbstick = {}

function TouchThumbstick:Create(parentFrame, visible, callback, reset, setMoving)
	if self.thumbstickFrame then
		self.thumbstickFrame:Destroy()
		self.thumbstickFrame = nil
		if self.onTouchMovedConn then
			self.onTouchMovedConn:Disconnect()
			self.onTouchMovedConn = nil
		end

		if self.onTouchEndedConn then
			self.onTouchEndedConn:Disconnect()
			self.onTouchEndedConn = nil
		end
	end

	local minAxis = math.min(parentFrame.AbsoluteSize.X, parentFrame.AbsoluteSize.Y)
	local isSmallScreen = minAxis <= 500
	self.thumbstickSize = isSmallScreen and 70 or 120
	self.screenPos = isSmallScreen and UDim2.new(0, (self.thumbstickSize / 2) - 10, 1, -self.thumbstickSize - 20)
		or UDim2.new(0, self.thumbstickSize / 2, 1, -self.thumbstickSize * 1.75)

	self.thumbstickFrame = Instance.new("Frame")
	self.thumbstickFrame.Name = "ThumbstickFrame"
	self.thumbstickFrame.Active = true
	self.thumbstickFrame.Visible = false
	self.thumbstickFrame.Size = UDim2.new(0, self.thumbstickSize, 0, self.thumbstickSize)
	self.thumbstickFrame.Position = self.screenPos
	self.thumbstickFrame.BackgroundTransparency = 1

	local outerImage = Instance.new("ImageLabel")
	outerImage.Name = "OuterImage"
	outerImage.Image = TOUCH_CONTROL_SHEET
	outerImage.ImageRectOffset = Vector2.new()
	outerImage.ImageRectSize = Vector2.new(220, 220)
	outerImage.BackgroundTransparency = 1
	outerImage.Size = UDim2.new(0, self.thumbstickSize, 0, self.thumbstickSize)
	outerImage.Position = UDim2.new(0, 0, 0, 0)
	outerImage.Parent = self.thumbstickFrame

	self.stickImage = Instance.new("ImageLabel")
	self.stickImage.Name = "StickImage"
	self.stickImage.Image = TOUCH_CONTROL_SHEET
	self.stickImage.ImageRectOffset = Vector2.new(220, 0)
	self.stickImage.ImageRectSize = Vector2.new(111, 111)
	self.stickImage.BackgroundTransparency = 1
	self.stickImage.Size = UDim2.new(0, self.thumbstickSize / 2, 0, self.thumbstickSize / 2)
	self.stickImage.Position = UDim2.new(0, self.thumbstickSize / 2 - self.thumbstickSize / 4, 0, self.thumbstickSize / 2 - self.thumbstickSize / 4)
	self.stickImage.ZIndex = 2
	self.stickImage.Parent = self.thumbstickFrame

	if not visible then
		self.stickImage.ImageTransparency = 1
		outerImage.ImageTransparency = 1
	end

	local centerPosition = nil
	local deadZone = 0.05
	local last = {}

	local push = function(stopped)
		if stopped then
			reset()
		else
			local mv = Vector2.new(self.moveVector.X, self.moveVector.Z)
			local keys = {
				(mv.Y < 0 and Enum.KeyCode.W or Enum.KeyCode.S),
				(mv.X < 0 and Enum.KeyCode.A or Enum.KeyCode.D),
			}

			if last and (#last >= 1) then
				for idx, key in pairs(last) do
					if keys[idx] ~= key then
						callback(key, false)
					end
				end
			end

			for _, key in pairs(keys) do
				callback(key, true)
			end

			last = keys
		end
	end

	local function DoMove(direction)
		local currentMoveVector = direction / (self.thumbstickSize / 2)

		local inputAxisMagnitude = currentMoveVector.magnitude
		if inputAxisMagnitude < deadZone then
			currentMoveVector = Vector3.new()
		else
			currentMoveVector = currentMoveVector.unit * ((inputAxisMagnitude - deadZone) / (1 - deadZone))
			currentMoveVector = Vector3.new(currentMoveVector.X, 0, currentMoveVector.Y)
		end

		self.direction = direction
		self.moveVector = currentMoveVector
		push()
	end

	local function MoveStick(pos)
		local relativePosition = Vector2.new(pos.X - centerPosition.X, pos.Y - centerPosition.Y)
		local length = relativePosition.magnitude
		local maxLength = self.thumbstickFrame.AbsoluteSize.X / 2
		if self.isFollowStick and length > maxLength then
			local offset = relativePosition.unit * maxLength
		else
			length = math.min(length, maxLength)
			relativePosition = relativePosition.unit * length
		end

		self.stickImage.Position = UDim2.new(0, relativePosition.X + self.stickImage.AbsoluteSize.X / 2, 0, relativePosition.Y + self.stickImage.AbsoluteSize.Y / 2)
	end

	self.thumbstickFrame.InputBegan:Connect(function(inputObject)
		setMoving(true)
		if self.moveTouchObject or inputObject.UserInputType ~= Enum.UserInputType.Touch
			or inputObject.UserInputState ~= Enum.UserInputState.Begin then
			return
		end

		self.moveTouchObject = inputObject
		centerPosition = Vector2.new(self.thumbstickFrame.AbsolutePosition.X + self.thumbstickFrame.AbsoluteSize.X / 2, self.thumbstickFrame.AbsolutePosition.Y + self.thumbstickFrame.AbsoluteSize.Y / 2)
	end)

	self.onTouchMovedConn = UserInputService.TouchMoved:Connect(function(inputObject)
		if inputObject == self.moveTouchObject then
			centerPosition = Vector2.new(self.thumbstickFrame.AbsolutePosition.X + self.thumbstickFrame.AbsoluteSize.X / 2, self.thumbstickFrame.AbsolutePosition.Y + self.thumbstickFrame.AbsoluteSize.Y / 2)
			local direction = Vector2.new(inputObject.Position.X - centerPosition.X, inputObject.Position.Y - centerPosition.Y)
			DoMove(direction)
			MoveStick(inputObject.Position)
		end
	end)

	self.onTouchEndedConn = UserInputService.TouchEnded:Connect(function(inputObject)
		if inputObject == self.moveTouchObject then
			self.stickImage.Position = UDim2.new(0, self.thumbstickFrame.Size.X.Offset / 2 - self.thumbstickSize / 4, 0, self.thumbstickFrame.Size.Y.Offset / 2 - self.thumbstickSize / 4)
			setMoving(false)

			self.moveVector = ZERO_VECTOR3
			self.isJumping = false
			self.moveTouchObject = nil
			self.direction = zero_vector2

			last = {}
			push(true)
		end
	end)

	self.thumbstickFrame.Parent = parentFrame
	return self.thumbstickFrame
end

return TouchThumbstick
